import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/app_logger.dart';
import '../../../../api/models/message.dart';
import '../../../../api/opencode_client.dart';
import '../../../../api/endpoints.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/translations.dart';
import '../../../../controllers/session_controller.dart';

/// Network-free part of questionID resolution: prefers the question part's own
/// `que_`-prefixed id/callID, then the SSE-populated local cache. Returns null
/// when the caller must fall back to `GET /question`.
String? resolveQuestionIDLocal(
  Part part,
  String? Function(String callId, {String? sessionId}) lookup,
) {
  if (part.id.startsWith('que')) return part.id;
  if (part.callID.startsWith('que')) return part.callID;
  final cached = lookup(part.callID, sessionId: part.sessionID);
  if (cached == null || cached.isEmpty) return null;
  return cached;
}

class ParsedQuestion {
  final String questionText;
  final List<ParsedOption> options;
  final bool isMultiSelect;
  final bool custom;

  ParsedQuestion({
    required this.questionText,
    required this.options,
    this.isMultiSelect = false,
    this.custom = true,
  });
}

class ParsedOption {
  final String label;
  final String description;

  ParsedOption({required this.label, this.description = ''});
}

class QuestionCard extends StatefulWidget {
  final Part part;
  final bool isInlinePlaceholder;

  const QuestionCard({
    super.key,
    required this.part,
    this.isInlinePlaceholder = false,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final OpenCodeClient _client = OpenCodeClient();

  late List<ParsedQuestion> _questions;
  final Map<int, List<String>> _selectedAnswers = {};
  final Map<int, TextEditingController> _textControllers = {};

  final Map<int, bool> _customInputsOn = {};
  final Map<int, TextEditingController> _customInputControllers = {};

  int _currentPageIndex = 0;
  int _previousPageIndex = 0;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initQuestions();
  }

  @override
  void didUpdateWidget(covariant QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPart = oldWidget.part;
    final newPart = widget.part;
    if (oldPart.id != newPart.id || oldPart.callID != newPart.callID) {
      _currentPageIndex = 0;
      _previousPageIndex = 0;
      _initQuestions();
    } else if (_questions.isEmpty && newPart.toolInput.isNotEmpty) {
      _initQuestions();
    }
  }

  @override
  void dispose() {
    for (final controller in _customInputControllers.values) {
      controller.dispose();
    }
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initQuestions() {
    _questions = _parseQuestions();
    _selectedAnswers.clear();
    for (final controller in _customInputControllers.values) {
      controller.dispose();
    }
    _customInputControllers.clear();
    _customInputsOn.clear();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.options.isEmpty) {
        _textControllers[i] = TextEditingController();
      } else {
        _selectedAnswers[i] = [];
        _customInputControllers[i] = TextEditingController();
        _customInputsOn[i] = false;
      }
    }

    if (_currentPageIndex >= _questions.length) {
      _currentPageIndex = _questions.length - 1;
    }
    if (_currentPageIndex < 0) {
      _currentPageIndex = 0;
    }
    _previousPageIndex = _currentPageIndex;
  }

  void _handleCustomInputSelection(int questionIndex, ParsedQuestion q) {
    final status = widget.part.toolStatus;
    if (status != ToolStateStatus.running &&
        status != ToolStateStatus.pending) {
      return;
    }

    setState(() {
      _errorMessage = null;
      if (q.isMultiSelect) {
        final currentlyOn = _customInputsOn[questionIndex] ?? false;
        _customInputsOn[questionIndex] = !currentlyOn;
        if (!currentlyOn) {
          _customInputControllers[questionIndex]?.clear();
          if (_selectedAnswers.containsKey(questionIndex)) {
            _selectedAnswers[questionIndex]!.removeWhere(
              (item) => !q.options.any((opt) => opt.label == item),
            );
          }
        }
      } else {
        _customInputsOn[questionIndex] = true;
        _selectedAnswers[questionIndex] = [];
      }
    });
  }

  void _confirmCustomInput(int questionIndex, ParsedQuestion q) {
    final status = widget.part.toolStatus;
    if (status != ToolStateStatus.running &&
        status != ToolStateStatus.pending) {
      return;
    }

    final val = _customInputControllers[questionIndex]?.text.trim() ?? '';
    if (val.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your custom answer.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _customInputsOn[questionIndex] = true;
      if (!q.isMultiSelect) {
        _selectedAnswers[questionIndex] = [val];
      } else {
        if (!_selectedAnswers.containsKey(questionIndex)) {
          _selectedAnswers[questionIndex] = [];
        }
        final list = _selectedAnswers[questionIndex]!;
        // Remove any previous custom answers (anything not in q.options)
        list.removeWhere((item) => !q.options.any((opt) => opt.label == item));
        list.add(val);
      }
    });

    if (!q.isMultiSelect) {
      final bool allAnswered = _areAllQuestionsAnswered();

      if (allAnswered) {
        _submitAnswers();
      } else if (questionIndex == _currentPageIndex &&
          _currentPageIndex < _questions.length - 1) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _currentPageIndex == questionIndex) {
            _navigateToPage(_currentPageIndex + 1);
          }
        });
      }
    }
  }

  List<ParsedQuestion> _parseQuestions() {
    final List<ParsedQuestion> parsedList = [];
    final input = widget.part.toolInput;

    if (input.isEmpty) {
      return parsedList;
    }

    // 1. Check if 'questions' list exists in toolInput
    if (input['questions'] is List) {
      final list = input['questions'] as List;
      for (final item in list) {
        if (item is Map) {
          final qText = item['question'] as String? ?? '';
          final isMulti =
              item['is_multi_select'] as bool? ??
              item['multiple'] as bool? ??
              false;
          final custom = item['custom'] as bool? ?? true;
          final rawOptions = item['options'] as List? ?? [];

          final List<ParsedOption> opts = [];
          for (final opt in rawOptions) {
            if (opt is String) {
              opts.add(ParsedOption(label: opt));
            } else if (opt is Map) {
              opts.add(
                ParsedOption(
                  label:
                      opt['label'] as String? ?? opt['text'] as String? ?? '',
                  description: opt['description'] as String? ?? '',
                ),
              );
            }
          }
          parsedList.add(
            ParsedQuestion(
              questionText: qText,
              options: opts,
              isMultiSelect: isMulti,
              custom: custom,
            ),
          );
        }
      }
    }

    // 2. If 'questions' was empty but root 'question' exists, fallback
    if (parsedList.isEmpty) {
      final qText = input['question'] as String? ?? '';
      if (qText.isNotEmpty) {
        final rawOptions = input['options'] as List? ?? [];
        final List<ParsedOption> opts = [];
        for (final opt in rawOptions) {
          if (opt is String) {
            opts.add(ParsedOption(label: opt));
          } else if (opt is Map) {
            opts.add(
              ParsedOption(
                label: opt['label'] as String? ?? opt['text'] as String? ?? '',
                description: opt['description'] as String? ?? '',
              ),
            );
          }
        }
        final isMulti =
            input['is_multi_select'] as bool? ??
            input['multiple'] as bool? ??
            false;
        final custom = input['custom'] as bool? ?? true;
        parsedList.add(
          ParsedQuestion(
            questionText: qText,
            options: opts,
            isMultiSelect: isMulti,
            custom: custom,
          ),
        );
      }
    }

    return parsedList;
  }

  /// E2：解析结果按 output 字符串实例 memo（part 更新即整体换实例、新 raw
  /// 新字符串），避免每次 build 重复 jsonDecode 整个输出。
  Map<int, List<String>>? _completedAnswersCache;
  String? _completedAnswersSource;

  Map<int, List<String>> _getCompletedAnswers() {
    final rawOutput = widget.part.toolOutput;
    final cached = _completedAnswersCache;
    if (cached != null && identical(_completedAnswersSource, rawOutput)) {
      return cached;
    }
    final Map<int, List<String>> completed = {};
    final outputStr = rawOutput.trim();
    if (outputStr.isEmpty) {
      _completedAnswersSource = rawOutput;
      return _completedAnswersCache = completed;
    }

    // Try to parse as JSON
    try {
      final decoded = jsonDecode(outputStr);
      if (decoded is Map) {
        // Look for detailed_answers first
        if (decoded['detailed_answers'] is List) {
          final list = decoded['detailed_answers'] as List;
          for (int i = 0; i < list.length; i++) {
            final item = list[i];
            if (item is Map) {
              final ans = item['answer'];
              if (ans is List) {
                completed[i] = ans.map((e) => e.toString()).toList();
              } else if (ans != null) {
                final str = ans.toString();
                if (str.contains(', ')) {
                  completed[i] = str.split(', ');
                } else {
                  completed[i] = [str];
                }
              }
            }
          }
        }
        // Fallback to answers list
        if (completed.isEmpty && decoded['answers'] is List) {
          final list = decoded['answers'] as List;
          for (int i = 0; i < list.length; i++) {
            final ans = list[i];
            if (ans is List) {
              completed[i] = ans.map((e) => e.toString()).toList();
            } else if (ans != null) {
              final str = ans.toString();
              if (str.contains(', ')) {
                completed[i] = str.split(', ');
              } else {
                completed[i] = [str];
              }
            }
          }
        }
        // Fallback to single answer/reply string
        if (completed.isEmpty) {
          final ans =
              decoded['answer'] ?? decoded['reply'] ?? decoded['choice'];
          if (ans != null) {
            final str = ans.toString();
            if (str.contains(', ')) {
              completed[0] = str.split(', ');
            } else {
              completed[0] = [str];
            }
          }
        }
      } else if (decoded is List) {
        for (int i = 0; i < decoded.length; i++) {
          final ans = decoded[i];
          if (ans is List) {
            completed[i] = ans.map((e) => e.toString()).toList();
          } else if (ans != null) {
            final str = ans.toString();
            if (str.contains(', ')) {
              completed[i] = str.split(', ');
            } else {
              completed[i] = [str];
            }
          }
        }
      }
    } catch (_) {
      // If not JSON, it's a plain string.
      // Parse robustly using our question text matcher!
      bool matchedAny = false;
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final pattern = '"${q.questionText}"="';
        int idx = outputStr.indexOf(pattern);
        if (idx != -1) {
          int start = idx + pattern.length;
          int end = outputStr.indexOf('"', start);
          if (end != -1) {
            final ansStr = outputStr.substring(start, end);
            if (ansStr == 'Unanswered') {
              completed[i] = [];
            } else {
              completed[i] = ansStr.split(', ').map((e) => e.trim()).toList();
            }
            matchedAny = true;
          }
        }
      }

      // If that failed, use our default fallback parser
      if (!matchedAny) {
        if (_questions.length == 1) {
          completed[0] = [outputStr];
        } else {
          for (int i = 0; i < _questions.length; i++) {
            final q = _questions[i];
            final List<String> matches = [];
            for (final opt in q.options) {
              if (outputStr.toLowerCase().contains(opt.label.toLowerCase())) {
                matches.add(opt.label);
              }
            }
            if (matches.isNotEmpty) {
              completed[i] = matches;
            }
          }
        }
      }
    }

    _completedAnswersSource = rawOutput;
    return _completedAnswersCache = completed;
  }

  void _navigateToPage(int index) {
    if (index < 0 || index >= _questions.length) return;
    setState(() {
      _previousPageIndex = _currentPageIndex;
      _currentPageIndex = index;
    });
  }

  void _handleSelection(
    int questionIndex,
    String optionLabel,
    ParsedQuestion q,
  ) {
    final status = widget.part.toolStatus;
    if (status != ToolStateStatus.running &&
        status != ToolStateStatus.pending) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _customInputsOn[questionIndex] = false;
      if (!_selectedAnswers.containsKey(questionIndex)) {
        _selectedAnswers[questionIndex] = [];
      }
      final selectedList = _selectedAnswers[questionIndex]!;
      if (q.isMultiSelect) {
        if (selectedList.contains(optionLabel)) {
          selectedList.remove(optionLabel);
        } else {
          selectedList.add(optionLabel);
        }
      } else {
        selectedList.clear();
        selectedList.add(optionLabel);
      }
    });

    if (!q.isMultiSelect) {
      final bool allAnswered = _areAllQuestionsAnswered();

      if (allAnswered) {
        _submitAnswers();
      } else if (questionIndex == _currentPageIndex &&
          _currentPageIndex < _questions.length - 1) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _currentPageIndex == questionIndex) {
            _navigateToPage(_currentPageIndex + 1);
          }
        });
      }
    }
  }

  bool _areAllQuestionsAnswered() {
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.options.isEmpty) {
        if ((_textControllers[i]?.text.trim() ?? '').isEmpty) {
          return false;
        }
      } else {
        if (_customInputsOn[i] == true) {
          if ((_customInputControllers[i]?.text.trim() ?? '').isEmpty) {
            return false;
          }
        } else {
          if ((_selectedAnswers[i] ?? []).isEmpty) {
            return false;
          }
        }
      }
    }
    return true;
  }

  Future<String?> _resolveQuestionID() async {
    // 1. Local, network-free resolution: the question part's own `que_`
    // id/callID first, then the SSE-populated local index.
    final local = resolveQuestionIDLocal(
      widget.part,
      Get.find<SessionController>().questionIDForCallID,
    );
    if (local != null) return local;

    // 2. Fallback: fetch the pending questions list from the sidecar server to
    // map callID to QuestionID.
    try {
      final response = await _client.get(ApiEndpoints.questions);
      if (response.statusCode == 200) {
        final responseData = response.data;
        // v2 format: { location: {...}, data: [...] }
        final list = responseData is Map<String, dynamic>
            ? (responseData['data'] as List? ?? [])
            : (responseData is List ? responseData : []);
        for (final item in list) {
          if (item is Map) {
            final qId = item['id'] as String? ?? '';
            final tool = item['tool'];
            if (tool is Map && tool['callID'] == widget.part.callID) {
              if (qId.isNotEmpty) {
                return qId;
              }
            }
          }
        }
      }
    } catch (e) {
      AppLogger.e('Error resolving QuestionID: $e');
    }

    // Fallback to callID
    return widget.part.callID;
  }

  Future<void> _submitAnswers() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final String? questionID = await _resolveQuestionID();
    if (questionID == null || questionID.isEmpty) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'Could not resolve Question ID.';
        });
      }
      return;
    }

    if (_customInputsOn[_currentPageIndex] == true) {
      final val = _customInputControllers[_currentPageIndex]?.text.trim() ?? '';
      if (val.isEmpty) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _errorMessage = 'Please enter your custom answer.';
          });
        }
        return;
      }
    }

    // Match exactly the official schema from clone/opencode/packages/sdk/openapi.json
    // requestBody accepts strictly answers which is a list-of-lists of strings:
    // answers: [ [selectedLabel1], [selectedLabel2, selectedLabel3] ]
    // and additionalProperties is false, meaning NO other keys are allowed!
    final List<List<String>> answersPayload = [];

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.options.isEmpty) {
        final val = _textControllers[i]?.text.trim() ?? '';
        answersPayload.add([val]);
      } else {
        final selected = _selectedAnswers[i] ?? [];
        if (_customInputsOn[i] == true) {
          final customVal = _customInputControllers[i]?.text.trim() ?? '';
          if (q.isMultiSelect) {
            final List<String> combined = List<String>.from(selected);
            // `_confirmCustomInput` 已把自定义值写入 `_selectedAnswers`，
            // 这里仅在缺失时补一次，避免同一个自定义答案被发送两次。
            if (customVal.isNotEmpty && !combined.contains(customVal)) {
              combined.add(customVal);
            }
            answersPayload.add(combined);
          } else {
            answersPayload.add([customVal]);
          }
        } else {
          answersPayload.add(List<String>.from(selected));
        }
      }
    }

    final Map<String, dynamic> data = {'answers': answersPayload};

    try {
      final sid = widget.part.sessionID.isNotEmpty
          ? widget.part.sessionID
          : Get.find<SessionController>().activeSessionId.value;
      final response = await _client.post(
        ApiEndpoints.questionReply(questionID),
        data: data,
      );
      final code = response.statusCode ?? 0;
      // v1 reply may return 200/201/204.
      if (code != 200 && code != 201 && code != 204) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to submit: Server returned $code';
          });
        }
      } else {
        Get.find<SessionController>().noteQuestionResolved(
          questionID,
          sessionId: sid,
          rejected: false,
          answers: answersPayload,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to submit: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _rejectQuestion() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final String? questionID = await _resolveQuestionID();
    if (questionID == null || questionID.isEmpty) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'Could not resolve Question ID.';
        });
      }
      return;
    }

    try {
      final sid = widget.part.sessionID.isNotEmpty
          ? widget.part.sessionID
          : Get.find<SessionController>().activeSessionId.value;
      final response = await _client.post(
        ApiEndpoints.questionReject(questionID),
        data: {},
      );
      final code = response.statusCode ?? 0;
      if (code != 200 && code != 201 && code != 204) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to reject: Server returned $code';
          });
        }
      } else {
        Get.find<SessionController>().noteQuestionResolved(
          questionID,
          sessionId: sid,
          rejected: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to reject: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _buildQuestion(BuildContext context, int index) {
    final theme = Theme.of(context);
    final status = widget.part.toolStatus;
    final isPending =
        status == ToolStateStatus.running || status == ToolStateStatus.pending;

    final q = _questions[index];
    final Map<int, List<String>> activeAnswers = isPending
        ? _selectedAnswers
        : _getCompletedAnswers();
    final selectedList = activeAnswers[index] ?? [];
    final textController = _textControllers[index];

    // Find if there is any custom completed answer
    final customCompletedAnswers = isPending
        ? <String>[]
        : selectedList
              .where((ans) => !q.options.any((opt) => opt.label == ans))
              .toList();

    final customInputOn = _customInputsOn[index] ?? false;
    final customInputController = _customInputControllers[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_questions.length > 1) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Question ${index + 1} of ${_questions.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(
          q.questionText,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        if (q.options.isNotEmpty) ...[
          ...q.options.map((opt) {
            final isSelected =
                !isPending && selectedList.contains(opt.label) ||
                isPending && !customInputOn && selectedList.contains(opt.label);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: (isPending && !_submitting)
                    ? () => _handleSelection(index, opt.label, q)
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.05)
                        : (theme.brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.4)
                          : theme.dividerColor.withValues(alpha: 0.15),
                      width: isSelected ? 1.2 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        q.isMultiSelect
                            ? (isSelected
                                  ? CupertinoIcons.checkmark_square_fill
                                  : CupertinoIcons.square)
                            : (isSelected
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.circle),
                        size: 16,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.hintColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12.5,
                              ),
                            ),
                            if (opt.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                opt.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10.5,
                                  color: PremiumColors.secondaryText(
                                    theme.brightness,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          if (isPending && q.custom) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: !_submitting
                    ? () => _handleCustomInputSelection(index, q)
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: customInputOn
                        ? theme.colorScheme.primary.withValues(alpha: 0.05)
                        : (theme.brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: customInputOn
                          ? theme.colorScheme.primary.withValues(alpha: 0.4)
                          : theme.dividerColor.withValues(alpha: 0.15),
                      width: customInputOn ? 1.2 : 0.8,
                    ),
                    boxShadow: customInputOn
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            q.isMultiSelect
                                ? (customInputOn
                                      ? CupertinoIcons.checkmark_square_fill
                                      : CupertinoIcons.square)
                                : (customInputOn
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle),
                            size: 16,
                            color: customInputOn
                                ? theme.colorScheme.primary
                                : theme.hintColor.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Type your own answer...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: customInputOn
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12.5,
                                color: customInputOn
                                    ? theme.textTheme.bodyMedium?.color
                                    : theme.hintColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (customInputOn) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: customInputController,
                                  enabled: !_submitting,
                                  autofocus: true,
                                  style: const TextStyle(fontSize: 12.5),
                                  onChanged: (_) {
                                    if (_errorMessage != null) {
                                      setState(() {
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                  onSubmitted: (_) =>
                                      _confirmCustomInput(index, q),
                                  decoration: InputDecoration(
                                    hintText: LocaleKeys.enterYourAnswer.tr,
                                    hintStyle: TextStyle(
                                      fontSize: 12.5,
                                      color: theme.hintColor.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary,
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: ElevatedButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _confirmCustomInput(index, q),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: _submitting
                                    ? const Icon(
                                        CupertinoIcons.arrow_up_circle_fill,
                                        size: 20,
                                        color: Colors.white54,
                                      )
                                    : const Icon(
                                        CupertinoIcons.arrow_up_circle_fill,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (!isPending && customCompletedAnswers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      q.isMultiSelect
                          ? CupertinoIcons.checkmark_square_fill
                          : CupertinoIcons.checkmark_circle_fill,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customCompletedAnswers.join(', '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Custom answer',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10.5,
                              color: PremiumColors.secondaryText(
                                theme.brightness,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ] else ...[
          if (isPending)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              child: TextField(
                controller: textController,
                maxLines: 3,
                enabled: !_submitting,
                style: const TextStyle(fontSize: 12.5),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: LocaleKeys.enterYourAnswerHere.tr,
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: theme.hintColor.withValues(alpha: 0.7),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
              child: Text(
                (selectedList.isNotEmpty && selectedList.first.isNotEmpty)
                    ? selectedList.first
                    : '(No response)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontStyle:
                      (selectedList.isEmpty || selectedList.first.isEmpty)
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: (selectedList.isEmpty || selectedList.first.isEmpty)
                      ? theme.hintColor
                      : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSkippedView(ThemeData theme, bool isDark) {
    final questions = _questions;
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < questions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      questions[i].questionText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = widget.part.toolStatus;
    final isPending =
        status == ToolStateStatus.running || status == ToolStateStatus.pending;
    final isCompleted = status == ToolStateStatus.completed;

    if (widget.isInlinePlaceholder && isPending) {
      return const SizedBox.shrink();
    }

    final questions = _questions;

    // ── Compact completed view: show Q&A summary or "Skipped" tag ──
    if (!isPending && questions.isNotEmpty) {
      final completedAnswers = _getCompletedAnswers();
      if (completedAnswers.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(left: 0, right: 0, top: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < questions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                // Q&A block — simple text, no card wrapper
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.questionAskPrefix.trParams({
                          'text': questions[i].questionText,
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: LocaleKeys.questionAnswerPrefix.tr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: (completedAnswers[i]?.isNotEmpty ?? false)
                                  ? completedAnswers[i]!.join(', ')
                                  : '(No response)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      } else {
        return _buildSkippedView(theme, isDark);
      }
    }

    // When questions are still preparing or empty
    if (questions.isEmpty) {
      if (isPending) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 14, height: 14),
              const SizedBox(width: 12),
              Text(
                'Preparing questions...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          child: Text(
            isCompleted ? 'Completed' : 'Rejected',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        );
      }
    }

    final bool hasManualSubmit = questions.any(
      (q) => q.options.isEmpty || q.isMultiSelect,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              final inRight = _currentPageIndex >= _previousPageIndex;
              final begin = inRight
                  ? const Offset(0.3, 0.0)
                  : const Offset(-0.3, 0.0);
              return SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Container(
              key: ValueKey<int>(_currentPageIndex),
              child: _buildQuestion(context, _currentPageIndex),
            ),
          ),
          const SizedBox(height: 8),

          if (questions.length > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(CupertinoIcons.chevron_left, size: 16),
                    onPressed: _currentPageIndex > 0
                        ? () => _navigateToPage(_currentPageIndex - 1)
                        : null,
                    color: theme.colorScheme.primary,
                    disabledColor: theme.hintColor.withValues(alpha: 0.3),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(questions.length, (i) {
                    final isActive = i == _currentPageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 12 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.hintColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(CupertinoIcons.chevron_right, size: 16),
                    onPressed: _currentPageIndex < questions.length - 1
                        ? () => _navigateToPage(_currentPageIndex + 1)
                        : null,
                    color: theme.colorScheme.primary,
                    disabledColor: theme.hintColor.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (isPending) ...[
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),

            if (hasManualSubmit) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                int? firstIncompleteIndex;
                                for (int i = 0; i < questions.length; i++) {
                                  final q = questions[i];
                                  if (q.options.isEmpty) {
                                    if ((_textControllers[i]?.text.trim() ?? '')
                                        .isEmpty) {
                                      firstIncompleteIndex ??= i;
                                    }
                                  } else {
                                    if (_customInputsOn[i] == true) {
                                      if ((_customInputControllers[i]?.text
                                                  .trim() ??
                                              '')
                                          .isEmpty) {
                                        firstIncompleteIndex ??= i;
                                      }
                                    } else {
                                      if ((_selectedAnswers[i] ?? []).isEmpty) {
                                        firstIncompleteIndex ??= i;
                                      }
                                    }
                                  }
                                }

                                if (firstIncompleteIndex != null) {
                                  final incompleteIndex = firstIncompleteIndex;
                                  setState(() {
                                    _previousPageIndex = _currentPageIndex;
                                    _currentPageIndex = incompleteIndex;
                                    _errorMessage =
                                        'Please complete Question ${incompleteIndex + 1} before submitting.';
                                  });
                                  return;
                                }

                                _submitAnswers();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: _submitting
                            ? const Text(
                                'Submit Answers',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white54,
                                ),
                              )
                            : const Text(
                                'Submit Answers',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _rejectQuestion,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(
                          color: theme.colorScheme.error.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _submitting ? null : _rejectQuestion,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: theme.colorScheme.error.withValues(alpha: 0.8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
