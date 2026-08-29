import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/endpoints.dart';
import '../../api/models/snapshot_file_diff.dart';
import '../../api/opencode_client.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../init.dart';
import '../../models/session_runtime_state.dart';
import '../../utils/app_logger.dart';
import '../../utils/diff_paths.dart';
import '../../utils/translations.dart';
import '../diff/diff_code_view.dart';
import '../diff/diff_view.dart';

/// Review tab content for the tablet tool panel.
///
/// Supports three scopes controlled by [TabletToolController.reviewType]:
/// - message: diffs for one user message (`GET /session/{id}/diff?messageID=`)
/// - session: workspace diff filtered to the current session's changed files
/// - all: full workspace diff (`GET /vcs/diff?mode=git`)
///
/// Any scope opens its involved files as a multi-tab strip above the currently
/// selected file's diff. The top bar shows the current scope and a button that
/// jumps to "all".
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final TabletToolController _toolCtrl;
  late final SessionController _sessionCtrl;
  final List<Worker> _workers = [];
  final Map<String, GlobalKey> _tabKeys = {};

  bool _loading = false;
  bool _failed = false;
  List<SnapshotFileDiff> _diffs = const [];
  String _selectedPath = '';

  /// Last tab the file-tab bar auto-scrolled to. Prevents every rebuild from
  /// yanking the horizontal scroll back to the selected tab (fighting the
  /// user's manual scroll); only a *changed* selection triggers ensureVisible.
  String _lastEnsuredTab = '';
  int _requestSeq = 0;

  /// 当前 diff 的跳转变更块句柄（DiffCodeViewState 提供 jumpToChange）。
  final GlobalKey<DiffCodeViewState> _diffViewKey =
      GlobalKey<DiffCodeViewState>();
  int _changeIndex = 0;
  bool _pendingJumpToFirstChange = false;

  int get _changeBlockCount => _diffViewKey.currentState?.changeBlockCount ?? 0;

  @override
  void initState() {
    super.initState();
    _toolCtrl = Get.find<TabletToolController>();
    _sessionCtrl = Get.find<SessionController>();
    _workers.addAll([
      ever(_toolCtrl.reviewReloadTick, (_) => _load()),
      ever(_toolCtrl.reviewSelectedFile, (file) {
        if (file.isEmpty) return;
        _selectFile(file);
      }),
      ever(_toolCtrl.showChangesOnly, (_) => setState(() {})),
      // 切换 session：若用户显示 changefiles 且目标会话的 changefiles 展开，
      // 后台预刷新右侧 Review（不切 tab）。
      ever(_sessionCtrl.activeSessionId, (id) {
        if (id.isEmpty) return;
        if (!Global.isCardVisible('input_session_diff')) return;
        final state = _sessionCtrl.stateOf(id);
        if (state.expandedSection.value != SessionExpandedSection.diff) return;
        _toolCtrl.openReviewSession(id, switchTab: false);
      }),
    ]);
    _load();
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    final type = _toolCtrl.reviewType.value;
    if (type.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = false;
          _resetState();
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }

    try {
      List<SnapshotFileDiff> result;
      if (type == TabletToolController.reviewTypeMessage) {
        result = await _fetchMessageDiff();
      } else {
        final all = await _fetchVcsDiff();
        result = type == TabletToolController.reviewTypeSession
            ? _filterBySession(all)
            : all;
      }

      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _diffs = result;
        _loading = false;

        // 变更块由 DiffCodeView 内部按当前 diff 计算；此处仅维护文件 tab 键清理集合。
        final filePaths = {for (final d in result) d.file};
        _tabKeys.removeWhere((path, _) => !filePaths.contains(path));

        final preferred = _toolCtrl.reviewSelectedFile.value;
        final preferredDiff = preferred.isNotEmpty
            ? result.where((d) => diffPathsEqual(d.file, preferred)).firstOrNull
            : null;
        _selectedPath =
            preferredDiff?.file ?? (result.isNotEmpty ? result.first.file : '');
        // Keep the shared selection pointing at a file that is actually
        // visible so left-side lists never highlight a missing file.
        if (_selectedPath.isEmpty) {
          _toolCtrl.reviewSelectedFile.value = '';
        } else if (!diffPathsEqual(
          _toolCtrl.reviewSelectedFile.value,
          _selectedPath,
        )) {
          _toolCtrl.reviewSelectedFile.value = _selectedPath;
        }
        _changeIndex = 0;
        _pendingJumpToFirstChange = result.isNotEmpty;
      });
    } catch (e) {
      AppLogger.e('ReviewPage load failed: $e');
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _failed = true;
        _resetState();
      });
    }
  }

  /// Clears loaded diffs and selection state (empty / error paths).
  void _resetState() {
    _diffs = const [];
    _selectedPath = '';
    _changeIndex = 0;
    _pendingJumpToFirstChange = false;
    _tabKeys.clear();
  }

  SnapshotFileDiff? get _selectedDiff {
    if (_diffs.isEmpty) return null;
    return _diffs.firstWhere(
      (d) => d.file == _selectedPath,
      orElse: () => _diffs.first,
    );
  }

  /// Selects a file of the current review scope without recomputing anything.
  /// Mirrors the selection back to [TabletToolController.reviewSelectedFile] so
  /// the left-side file lists (session panel / message cards) stay highlighted.
  /// Idempotent: re-selecting the current file is a no-op.
  ///
  /// [path] may come from the left-side lists whose path format differs from
  /// the fetched diffs (worktree prefix, separators, etc.); it is resolved to
  /// the matching fetched diff before switching.
  void _selectFile(String path) {
    final target = _resolveDiffPath(path);
    if (target == null) return;
    if (!diffPathsEqual(_toolCtrl.reviewSelectedFile.value, path)) {
      _toolCtrl.reviewSelectedFile.value = path;
    }
    if (diffPathsEqual(_selectedPath, path)) return;
    setState(() {
      _selectedPath = target;
      _changeIndex = 0;
      _pendingJumpToFirstChange = true;
    });
  }

  /// Returns the canonical `file` value (as stored in `_diffs`) that matches
  /// [path], or null when no fetched diff corresponds to it.
  String? _resolveDiffPath(String path) {
    for (final d in _diffs) {
      if (diffPathsEqual(d.file, path)) return d.file;
    }
    return null;
  }

  /// Scrolls the diff view so the change block at [index] is visible.
  void _jumpToChange(int index) {
    _diffViewKey.currentState?.jumpToChange(index);
  }

  /// Scroll to the previous/next change block of the selected diff.
  void _goToChange(int delta) {
    if (_changeBlockCount == 0) return;
    final newIndex = (_changeIndex + delta).clamp(0, _changeBlockCount - 1);
    if (newIndex == _changeIndex) return;
    setState(() => _changeIndex = newIndex);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _jumpToChange(newIndex),
    );
  }

  /// Switch to the previous/next file tab in the current review scope.
  void _switchFile(int delta) {
    if (_diffs.isEmpty) return;
    final curIdx = _diffs.indexWhere((d) => d.file == _selectedPath);
    final base = curIdx == -1 ? 0 : curIdx;
    final newIdx = (base + delta).clamp(0, _diffs.length - 1);
    if (newIdx == base) return;
    _selectFile(_diffs[newIdx].file);
  }

  Future<List<SnapshotFileDiff>> _fetchMessageDiff() async {
    final sessionId = _toolCtrl.reviewSessionId.value;
    final messageId = _toolCtrl.reviewMessageId.value;
    if (sessionId.isEmpty || messageId.isEmpty) return const [];

    return Get.find<SessionController>().fetchMessageDiff(sessionId, messageId);
  }

  Future<List<SnapshotFileDiff>> _fetchVcsDiff() async {
    final response = await OpenCodeClient().get(
      ApiEndpoints.vcsDiff,
      queryParameters: {'mode': 'git'},
    );
    if (response.statusCode != 200) return const [];
    return _parseList(response.data);
  }

  List<SnapshotFileDiff> _parseList(dynamic data) {
    final rawList = data is Map && data['data'] is List
        ? data['data'] as List
        : (data is List ? data : const []);
    return rawList
        .whereType<Map>()
        .map((e) => SnapshotFileDiff.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.file.isNotEmpty)
        .toList();
  }

  List<SnapshotFileDiff> _filterBySession(List<SnapshotFileDiff> all) {
    final sessionId = _toolCtrl.reviewSessionId.value;
    if (sessionId.isEmpty) return all;
    final sessionCtrl = Get.find<SessionController>();
    final sessionFiles = sessionCtrl
        .stateOf(sessionId)
        .effectiveSessionDiffs
        .map((d) => d.file)
        .toList();
    if (sessionFiles.isEmpty) return const [];
    return all
        .where((d) => sessionFiles.any((f) => diffPathsEqual(d.file, f)))
        .toList();
  }

  String get _typeTitle {
    switch (_toolCtrl.reviewType.value) {
      case TabletToolController.reviewTypeMessage:
        return LocaleKeys.reviewTypeMessage.tr;
      case TabletToolController.reviewTypeSession:
        return LocaleKeys.reviewTypeSession.tr;
      case TabletToolController.reviewTypeAll:
        return LocaleKeys.reviewTypeAll.tr;
      default:
        return LocaleKeys.tabletReviewTab.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFiles = _diffs.isNotEmpty;

    if (_pendingJumpToFirstChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pendingJumpToFirstChange) {
          _pendingJumpToFirstChange = false;
          _jumpToChange(0);
        }
      });
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            const Divider(height: 1),
            if (hasFiles) _buildFileTabBar(theme),
            Expanded(child: _buildBody(theme)),
          ],
        ),
        if (hasFiles)
          Positioned(right: 60, bottom: 220, child: _buildNavButtons(theme)),
      ],
    );
  }

  /// Cross-shaped direction pad in the bottom-right corner:
  /// up/down jump between change blocks, left/right switch file tabs.
  Widget _buildNavButtons(ThemeData theme) {
    final curIdx = _diffs.indexWhere((d) => d.file == _selectedPath);
    final canUp = _changeIndex > 0;
    final canDown =
        _changeBlockCount > 0 && _changeIndex < _changeBlockCount - 1;
    final canLeft = curIdx > 0;
    final canRight = curIdx != -1 && curIdx < _diffs.length - 1;

    Widget spacer() => const SizedBox(width: 36, height: 36);

    Widget btn({
      required IconData icon,
      required String tooltip,
      required bool enabled,
      required VoidCallback onTap,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onTap : null,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        iconSize: 18,
        color: theme.colorScheme.primary,
        disabledColor: theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.3,
        ),
        icon: Icon(icon),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              spacer(),
              btn(
                icon: CupertinoIcons.chevron_up,
                tooltip: LocaleKeys.reviewPrevChange.tr,
                enabled: canUp,
                onTap: () => _goToChange(-1),
              ),
              spacer(),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              btn(
                icon: CupertinoIcons.chevron_left,
                tooltip: LocaleKeys.reviewPrevFile.tr,
                enabled: canLeft,
                onTap: () => _switchFile(-1),
              ),
              spacer(),
              btn(
                icon: CupertinoIcons.chevron_right,
                tooltip: LocaleKeys.reviewNextFile.tr,
                enabled: canRight,
                onTap: () => _switchFile(1),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              spacer(),
              btn(
                icon: CupertinoIcons.chevron_down,
                tooltip: LocaleKeys.reviewNextChange.tr,
                enabled: canDown,
                onTap: () => _goToChange(1),
              ),
              spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final isAll =
        _toolCtrl.reviewType.value == TabletToolController.reviewTypeAll;
    final changesOnly = _toolCtrl.showChangesOnly.value;

    return Container(
      height: 40,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              _typeTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message:
                    (changesOnly
                            ? LocaleKeys.reviewShowFull
                            : LocaleKeys.reviewShowChangesOnly)
                        .tr,
                child: IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    changesOnly
                        ? CupertinoIcons.chevron_up_chevron_down
                        : CupertinoIcons.arrow_up_left_arrow_down_right,
                    color: changesOnly
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                  ),
                  onPressed: () => _toolCtrl.toggleReviewShowChangesOnly(),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: LocaleKeys.reviewTypeAll.tr,
                child: IconButton(
                  icon: Icon(
                    isAll
                        ? CupertinoIcons.square_stack_3d_up_fill
                        : CupertinoIcons.square_stack_3d_up,
                    size: 18,
                    color: isAll
                        ? theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.35,
                          )
                        : theme.colorScheme.primary,
                  ),
                  onPressed: isAll ? null : () => _toolCtrl.setReviewAll(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Multi-tab strip: every diff file opens as a tab (any review scope).
  Widget _buildFileTabBar(ThemeData theme) {
    if (_selectedPath != _lastEnsuredTab) {
      _lastEnsuredTab = _selectedPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedPath.isNotEmpty) {
          final key = _tabKeys[_selectedPath];
          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          }
        }
      });
    }

    return Container(
      height: 34,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _diffs.length,
        itemBuilder: (ctx, index) {
          final d = _diffs[index];
          final isActive = diffPathsEqual(d.file, _selectedPath);
          final key = _tabKeys.putIfAbsent(d.file, () => GlobalKey());

          return Padding(
            key: key,
            padding: const EdgeInsets.only(
              left: 4,
              right: 2,
              top: 4,
              bottom: 4,
            ),
            child: InkWell(
              onTap: () => _selectFile(d.file),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                    width: 1,
                  ),
                ),
                child: Text(
                  _fileName(d),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Basename only (no relative path) for the tab label.
  String _fileName(SnapshotFileDiff d) {
    final n = d.file.replaceAll('\\', '/');
    final parts = n.split('/');
    return parts.isNotEmpty ? parts.last : d.file;
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Text(
          LocaleKeys.reviewLoadFailed.tr,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    if (_diffs.isEmpty) {
      final hasScope = _toolCtrl.reviewType.value.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            hasScope
                ? LocaleKeys.mobileNoDiff.tr
                : LocaleKeys.reviewEmptyHint.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final selected = _selectedDiff!;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DiffCodeView(
          key: _diffViewKey,
          lines: parsePatchLines(selected.patch),
          hideContextLines: _toolCtrl.showChangesOnly.value,
          showLineNumbers: false,
        ),
      ),
    );
  }
}
