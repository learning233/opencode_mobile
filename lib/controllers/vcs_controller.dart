import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../api/endpoints.dart';
import '../api/models/vcs_info.dart';
import '../api/opencode_client.dart';
import '../controllers/project_controller.dart';
import '../utils/app_logger.dart';

class VcsController extends GetxController {
  final OpenCodeClient _client = OpenCodeClient();

  final branch = ''.obs;
  final defaultBranch = ''.obs;
  final isClean = true.obs;
  final statusFiles = <VcsStatusFile>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  Worker? _projectWorker;

  @override
  void onInit() {
    super.onInit();
    // 不在启动时立即拉取：连接尚未建立，请求注定失败且可能提前触发全局 401。
    // 项目扫描设置 activeProject 后由 worker 触发首次刷新，面板打开时也会刷新。

    if (Get.isRegistered<ProjectController>()) {
      _projectWorker = ever(Get.find<ProjectController>().activeProject, (_) {
        refreshAll();
      });
    }
  }

  @override
  void onClose() {
    _projectWorker?.dispose();
    super.onClose();
  }

  bool get hasUncommittedChanges => statusFiles.isNotEmpty;

  int get modifiedCount => statusFiles.where((f) => f.isModified).length;
  int get addedCount => statusFiles.where((f) => f.isAdded).length;
  int get deletedCount => statusFiles.where((f) => f.isDeleted).length;

  DateTime? _lastRefreshTime;
  String? _lastRefreshWorktree;

  /// 并发刷新代号：force 与非 force 刷新可能同时在飞（如 sheet 打开的
  /// 常规刷新 + 用户点手动刷新），后完成的旧响应不得覆盖新结果。
  int _refreshSeq = 0;

  /// 刷新 VCS 状态与分支信息。
  /// [force] 为 false 时，若距离上次刷新不足 3 秒且处于同一 worktree，则直接跳过避免重复请求。
  Future<void> refreshAll({String? worktree, bool force = false}) async {
    final targetWorktree =
        worktree ??
        (Get.isRegistered<ProjectController>()
            ? Get.find<ProjectController>().activeProject.value?.worktree
            : null);

    final now = DateTime.now();
    if (!force &&
        _lastRefreshTime != null &&
        _lastRefreshWorktree == targetWorktree &&
        now.difference(_lastRefreshTime!) < const Duration(seconds: 3)) {
      return;
    }

    _lastRefreshTime = now;
    _lastRefreshWorktree = targetWorktree;

    final seq = ++_refreshSeq;

    isLoading.value = true;
    error.value = null;

    try {
      await Future.wait([
        fetchVcsInfo(worktree: targetWorktree, requestSeq: seq),
        fetchVcsStatus(worktree: targetWorktree, requestSeq: seq),
      ]);
    } catch (e) {
      // 回滚节流时间戳，失败后允许立即重试；时间戳前置写入是为了
      // 防止并发的 force=false 调用同时穿过节流检查。
      // 两个 fetch 的失败（404/400 非 git 仓库语义除外）在这里汇聚。
      _lastRefreshTime = null;
      AppLogger.w('Failed to refresh VCS: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchVcsInfo({
    String? worktree,
    required int requestSeq,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.vcsInfo,
        directory: worktree,
      );

      if (requestSeq != _refreshSeq) return;

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final info = VcsInfo.fromJson(data);
          branch.value = info.branch;
          defaultBranch.value = info.defaultBranch;
          isClean.value = info.isClean;
        } else if (data is Map) {
          final info = VcsInfo.fromJson(Map<String, dynamic>.from(data));
          branch.value = info.branch;
          defaultBranch.value = info.defaultBranch;
          isClean.value = info.isClean;
        }
      }
    } on DioException catch (e) {
      AppLogger.w('Fetch VCS info failed: $e');
      if (e.response?.statusCode == 404 || e.response?.statusCode == 400) {
        // Not a git repo：稳定状态（重试不会改变结果），不上抛、不回滚节流。
        branch.value = '';
        defaultBranch.value = '';
      } else {
        // 其余失败上抛给 refreshAll：记录错误并回滚节流时间戳。
        rethrow;
      }
    }
  }

  Future<void> fetchVcsStatus({
    String? worktree,
    required int requestSeq,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.vcsStatus,
        directory: worktree,
      );

      if (requestSeq != _refreshSeq) return;

      if (response.statusCode == 200) {
        final data = response.data;
        final rawList = (data is Map && data['data'] is List)
            ? data['data'] as List
            : (data is Map && data['files'] is List)
            ? data['files'] as List
            : (data is List ? data : []);

        final list = <VcsStatusFile>[];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            list.add(VcsStatusFile.fromJson(item));
          } else if (item is Map) {
            list.add(VcsStatusFile.fromJson(Map<String, dynamic>.from(item)));
          }
        }

        statusFiles.assignAll(list);
        isClean.value = list.isEmpty;
      } else {
        error.value = 'HTTP ${response.statusCode}';
      }
    } on DioException catch (e) {
      AppLogger.w('Fetch VCS status failed: $e');
      error.value = e.message;
      statusFiles.clear();
      if (e.response?.statusCode == 404 || e.response?.statusCode == 400) {
        // Not a git repo：稳定状态，不上抛（与 fetchVcsInfo 口径一致）。
        return;
      }
      rethrow;
    }
  }
}
