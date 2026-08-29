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

  Future<void> refreshAll({String? worktree}) async {
    isLoading.value = true;
    error.value = null;

    final targetWorktree =
        worktree ??
        (Get.isRegistered<ProjectController>()
            ? Get.find<ProjectController>().activeProject.value?.worktree
            : null);

    try {
      await Future.wait([
        fetchVcsInfo(worktree: targetWorktree),
        fetchVcsStatus(worktree: targetWorktree),
      ]);
    } catch (e) {
      AppLogger.w('Failed to refresh VCS: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchVcsInfo({String? worktree}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.vcsInfo,
        directory: worktree,
      );

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
        // Not a git repo
        branch.value = '';
        defaultBranch.value = '';
      }
    } catch (e) {
      AppLogger.e('Unexpected error in fetchVcsInfo: $e');
    }
  }

  Future<void> fetchVcsStatus({String? worktree}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.vcsStatus,
        directory: worktree,
      );

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
        if (list.isEmpty) {
          isClean.value = true;
        } else {
          isClean.value = false;
        }
      } else {
        error.value = 'HTTP ${response.statusCode}';
      }
    } on DioException catch (e) {
      AppLogger.w('Fetch VCS status failed: $e');
      error.value = e.message;
      statusFiles.clear();
    } catch (e) {
      AppLogger.e('Unexpected error in fetchVcsStatus: $e');
      error.value = e.toString();
      statusFiles.clear();
    }
  }
}
