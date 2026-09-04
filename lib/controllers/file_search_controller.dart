import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../api/endpoints.dart';
import '../api/models/search_result.dart';
import '../api/opencode_client.dart';
import '../utils/app_logger.dart';

enum SearchMode { text, files }

class FileSearchController extends GetxController {
  final OpenCodeClient _client = OpenCodeClient();

  final Rx<SearchMode> mode = SearchMode.text.obs;
  final RxString query = ''.obs;
  final RxBool isSearching = false.obs;
  final RxList<String> fileResults = <String>[].obs;
  final RxList<FileSearchGroup> textResults = <FileSearchGroup>[].obs;
  final RxnString errorMessage = RxnString();

  Timer? _debounceTimer;
  CancelToken? _cancelToken;
  int _requestSeq = 0;

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    super.onClose();
  }

  int get totalMatchCount {
    if (mode.value == SearchMode.files) {
      return fileResults.length;
    }
    return textResults.fold<int>(0, (sum, g) => sum + g.matches.length);
  }

  bool get hasQuery => query.value.trim().isNotEmpty;

  void onQueryChanged(String val, {String? worktree}) {
    query.value = val;
    _debounceTimer?.cancel();

    if (val.trim().isEmpty) {
      clear();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      performSearch(worktree: worktree);
    });
  }

  void setMode(SearchMode newMode, {String? worktree}) {
    if (mode.value == newMode) return;
    mode.value = newMode;
    // 切换模式时清空另一模式的历史结果与错误信息，保证 loading 态与空态正常展示
    if (newMode == SearchMode.files) {
      textResults.clear();
    } else {
      fileResults.clear();
    }
    errorMessage.value = null;
    if (hasQuery) {
      performSearch(worktree: worktree);
    }
  }

  Future<void> performSearch({String? worktree}) async {
    final trimmed = query.value.trim();
    if (trimmed.isEmpty) {
      clear();
      return;
    }

    final seq = ++_requestSeq;
    _cancelToken?.cancel('new_search_started');
    final token = CancelToken();
    _cancelToken = token;

    isSearching.value = true;
    errorMessage.value = null;
    // 搜索开始时清空旧结果，使 loading 态立即生效，避免旧模式残存结果干扰
    fileResults.clear();
    textResults.clear();

    try {
      if (mode.value == SearchMode.files) {
        final response = await _client.get(
          ApiEndpoints.findFile,
          queryParameters: {'query': trimmed, 'limit': 60, 'type': 'file'},
          directory: worktree,
          cancelToken: token,
        );

        if (seq != _requestSeq) return;

        if (response.statusCode == 200) {
          final data = response.data;
          final rawList = (data is Map && data['data'] is List)
              ? data['data'] as List
              : data is List
              ? data
              : [];
          final list = rawList.map((e) => e.toString()).toList();
          fileResults.assignAll(list);
        } else {
          errorMessage.value = 'HTTP ${response.statusCode}';
        }
      } else {
        final response = await _client.get(
          ApiEndpoints.findText,
          queryParameters: {'pattern': trimmed},
          directory: worktree,
          cancelToken: token,
        );

        if (seq != _requestSeq) return;

        if (response.statusCode == 200) {
          final data = response.data;
          final rawList = (data is Map && data['data'] is List)
              ? data['data'] as List
              : data is List
              ? data
              : [];
          final matches = <TextSearchMatch>[];
          for (final item in rawList) {
            if (item is Map) {
              matches.add(
                TextSearchMatch.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }

          final Map<String, List<TextSearchMatch>> grouped = {};
          for (final m in matches) {
            grouped.putIfAbsent(m.path, () => []).add(m);
          }

          final groupList = grouped.entries
              .map((e) => FileSearchGroup(path: e.key, matches: e.value))
              .toList();

          textResults.assignAll(groupList);
        } else {
          errorMessage.value = 'HTTP ${response.statusCode}';
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || seq != _requestSeq) return;
      AppLogger.w('Search failed: $e');
      errorMessage.value = e.message ?? 'Search error';
    } catch (e) {
      if (seq != _requestSeq) return;
      AppLogger.e('Unexpected search error: $e');
      errorMessage.value = e.toString();
    } finally {
      if (seq == _requestSeq) {
        isSearching.value = false;
      }
    }
  }

  void toggleGroupExpanded(int index) {
    if (index >= 0 && index < textResults.length) {
      textResults[index].isExpanded = !textResults[index].isExpanded;
      textResults.refresh();
    }
  }

  void clear() {
    _requestSeq++;
    _debounceTimer?.cancel();
    _cancelToken?.cancel('cleared');
    query.value = '';
    fileResults.clear();
    textResults.clear();
    isSearching.value = false;
    errorMessage.value = null;
  }
}
