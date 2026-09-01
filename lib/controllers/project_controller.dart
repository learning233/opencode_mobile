import 'dart:async';

import 'package:get/get.dart';
import '../api/endpoints.dart';
import '../api/models/file_entry.dart';
import '../api/models/project.dart';
import '../api/opencode_client.dart';
import '../init.dart';
import '../models/e2b_sandbox_info.dart';
import '../services/e2b_workspace_service.dart';
import '../utils/app_logger.dart';

import 'session_controller.dart';

class ProjectController extends GetxController {
  final OpenCodeClient _client = OpenCodeClient();

  final projects = <ProjectModel>[].obs;
  final activeProject = Rxn<ProjectModel>();
  final isLoading = false.obs;

  /// 最近一次 `fetchProjects` 的失败原因（null = 成功）。
  /// 供项目列表在空结果时给出重试入口。
  final projectsError = RxnString();

  /// 全局响应式 E2B 沙盒列表
  final sandboxes = <E2bSandboxInfo>[].obs;
  final isLoadingSandboxes = false.obs;
  final sandboxesError = RxnString();

  /// 已隐藏项目的归一化 worktree 路径。纯本地显示偏好：仅用于 drawer
  /// 列表过滤，不影响激活项目与会话（后端没有删除项目的接口）。
  final hiddenProjectKeys = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    hiddenProjectKeys
      ..clear()
      ..addAll(Global.settings.hiddenProjects.map(normalizeDirectory).toSet());
    fetchSandboxes();
  }

  bool isProjectHidden(ProjectModel project) =>
      hiddenProjectKeys.contains(hiddenKeyFor(project));

  static String hiddenKeyFor(ProjectModel project) =>
      normalizeDirectory(project.worktree);

  /// 用户主动隐藏：仅从 drawer 列表过滤，激活状态与会话不动。
  Future<void> hideProject(ProjectModel project) async {
    final key = hiddenKeyFor(project);
    if (hiddenProjectKeys.contains(key)) return;
    hiddenProjectKeys.add(key);
    await Global.settings.setHiddenProjects(hiddenProjectKeys.toList());
  }

  Future<void> unhideProjectByKey(String key) async {
    if (!hiddenProjectKeys.contains(key)) return;
    hiddenProjectKeys.remove(key);
    await Global.settings.setHiddenProjects(hiddenProjectKeys.toList());
  }

  Future<void> refreshAfterConnect() async {
    projects.clear();
    activeProject.value = null;
    await Future.wait([
      fetchProjects(),
      fetchSandboxes(),
    ]);
    _restoreLastProject();
  }

  Future<void> fetchSandboxes() async {
    final apiKey = Global.settings.cloudWorkspaceConfig.e2bApiKey.trim();
    if (apiKey.isEmpty) {
      sandboxes.clear();
      isLoadingSandboxes.value = false;
      sandboxesError.value = null;
      return;
    }
    isLoadingSandboxes.value = true;
    try {
      final list = await E2bWorkspaceService.instance.fetchSandboxes(apiKey);
      sandboxes.assignAll(list);
      sandboxesError.value = null;
    } catch (e) {
      sandboxesError.value = '$e';
    } finally {
      isLoadingSandboxes.value = false;
    }
  }

  void _restoreLastProject() {
    final lastId = Global.lastProjectId;
    if (lastId != null && lastId.isNotEmpty) {
      // 1) Try exact ID match
      var match = projects.firstWhereOrNull((p) => p.id == lastId);
      // 2) Fallback: match by worktree path
      match ??= projects.firstWhereOrNull((p) => p.worktree == lastId);
      if (match != null) {
        selectProject(match);
        return;
      }
    }
    // If last project is not on this server (e.g. switched server/sandbox),
    // pick the first project available on the current server.
    if (projects.isNotEmpty) {
      selectProject(projects.first);
    } else {
      activeProject.value = null;
    }
  }

  Future<void> fetchProjects() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await _client.get(
        ApiEndpoints.projects,
        skipDirectory: true,
      );
      if (response.statusCode == 200) {
        projectsError.value = null;
        final responseData = response.data;
        final data = responseData is Map<String, dynamic>
            ? (responseData['data'] as List? ?? const [])
            : (responseData as List);
        final rawList = data
            .map((json) => ProjectModel.fromJson(json as Map<String, dynamic>))
            .where(
              (p) =>
                  p.id != 'global' &&
                  p.worktree != '/' &&
                  p.worktree.isNotEmpty,
            )
            .toList();

        // Deduplicate projects by worktree paths.
        final seenWorktrees = <String>{};
        final uniqueProjects = <ProjectModel>[];
        for (final p in rawList) {
          if (!seenWorktrees.contains(p.worktree)) {
            seenWorktrees.add(p.worktree);
            uniqueProjects.add(p);
          }
        }

        projects.assignAll(uniqueProjects);

        // Re-point activeProject to the canonical entry after the update
        final active = activeProject.value;
        if (active != null) {
          final reResolved = projects.firstWhereOrNull(
            (p) => p.id == active.id || p.worktree == active.worktree,
          );
          if (reResolved != null && reResolved.id != active.id) {
            activeProject.value = reResolved;
          } else if (reResolved == null && projects.isNotEmpty) {
            selectProject(projects.first);
          }
        } else if (projects.isNotEmpty) {
          selectProject(projects.first);
        }
      }
    } catch (e) {
      AppLogger.e('Failed to fetch projects', e);
      projectsError.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addProjectByPath(String path) async {
    try {
      // Normalize exactly like the interceptor does when sending, so the
      // worktree comparison below (and any locally-stored model) stays
      // consistent with what the server persists (no trailing slash).
      final normalized = normalizeDirectory(path);

      // Trigger sidecar discovery by making a lightweight API call.
      // Pass the directory explicitly instead of mutating the global
      // activeDirectory: adding a project must not re-scope in-flight
      // session/SSE requests until the user actually selects it.
      try {
        await _client.get(ApiEndpoints.sessions, directory: normalized);
      } catch (_) {
        // Ignore — the call is only to nudge the sidecar into discovering
        // the directory; it may return an empty list and that's fine.
      }

      const maxRetries = 3;
      const retryDelay = Duration(milliseconds: 500);

      for (var attempt = 0; attempt < maxRetries; attempt++) {
        await fetchProjects();

        final matched = projects.firstWhereOrNull(
          (p) => normalizeDirectory(p.worktree) == normalized,
        );
        if (matched != null) {
          return true;
        }

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
        }
      }

      // Sidecar hasn't discovered the project yet — likely the directory was
      // first added before git init, so the server cached it as id "global"
      // (InstanceStore keyed by directory) and keeps returning the stale entry.
      // Force the server to drop the cached instance and re-run fromDirectory,
      // then nudge discovery again so a newly-initialized git repo resolves to
      // a real project id. /instance/dispose releases the instance *after* the
      // response, so we must re-nudge afterwards rather than before.
      try {
        await _client.post(ApiEndpoints.instanceDispose, directory: normalized);
        await _client.get(ApiEndpoints.sessions, directory: normalized);
      } catch (_) {
        // Best-effort — if the endpoint is unavailable, fall through to the
        // local model fallback below (pre-fix behavior).
      }

      for (var attempt = 0; attempt < maxRetries; attempt++) {
        await fetchProjects();

        final matched = projects.firstWhereOrNull(
          (p) => normalizeDirectory(p.worktree) == normalized,
        );
        if (matched != null) {
          return true;
        }

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
        }
      }

      // Sidecar hasn't discovered the project yet — fall back to local model
      projects.insert(0, ProjectModel(id: normalized, worktree: normalized));
      return projects.any((p) => normalizeDirectory(p.worktree) == normalized);
    } catch (e) {
      AppLogger.e('Failed to add project by path', e);
      return false;
    }
  }

  Future<void> selectProject(ProjectModel project) async {
    final oldActive = activeProject.value;
    if (oldActive != null &&
        oldActive.id == project.id &&
        oldActive.worktree == project.worktree) {
      return;
    }
    activeProject.value = project;
    _client.activeDirectory = project.worktree;
    // 写库即忘（非关键路径），但用显式 unawaited 让"丢弃 Future"是有意的。
    unawaited(Global.settings.setLastProjectId(project.id));
    AppLogger.i('Selected project: ${project.displayName} (${project.id})');

    // 目录缓存按 worktree 隔离但无 TTL，且非激活项目的文件变更不会触发
    // SSE 失效；切项目时整体清空，避免切回旧项目时命中过期列表。
    invalidateDirectoryCache();

    // Refresh sessions and re-scope SSE for the new project
    final sessionCtrl = Get.find<SessionController>();
    sessionCtrl.onProjectChanged(project.worktree);
  }

  // ── 目录树缓存 (Directory Cache) ──

  /// 全局目录列表缓存，key 格式为 "$worktree\u0000$path"。
  /// 避免侧边栏抽屉关闭/切 Tab 导致 State 销毁重建后重复发起网络请求。
  /// 注意：[loadDirectory] 返回的是缓存中的共享 List 实例，调用方只读，
  /// 不得原地修改（增删排序都会污染缓存）。
  final Map<String, List<FileEntry>> directoryCache = {};

  /// directoryCache 容量兜底：单项目长会话内浏览大量目录时 FIFO 淘汰。
  static const int _directoryCacheMaxEntries = 256;

  /// 缓存代际：任何失效操作都会递增。[loadDirectory] 在请求发出前记录
  /// 代际，响应返回后代际已变（期间发生过失效）则跳过写回，避免在途
  /// 旧响应把过期列表写回已失效的缓存（下次非 force 读取会命中过期数据）。
  int _directoryCacheGeneration = 0;

  /// 始终带 worktree 前缀（null 与空串同为空前缀），保证同一目录
  /// 只会产生一种 key 形态。
  static String dirKey(String path, String? worktree) =>
      '${worktree ?? ''}\u0000$path';

  /// 获取目录下的文件列表（带内存缓存与排序）。
  /// [force] 为 true 时忽略缓存强制走网络拉取。
  Future<List<FileEntry>> loadDirectory(
    String path, {
    String? worktree,
    bool force = false,
  }) async {
    final effectiveWorktree = worktree ?? activeProject.value?.worktree ?? '';
    final key = dirKey(path, effectiveWorktree);

    if (!force && directoryCache.containsKey(key)) {
      return directoryCache[key]!;
    }

    final generation = _directoryCacheGeneration;

    final response = await _client.get(
      ApiEndpoints.fsList,
      queryParameters: {'path': path},
      directory: effectiveWorktree.isNotEmpty ? effectiveWorktree : null,
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final rawList = (data is Map && data['data'] is List)
          ? data['data'] as List
          : (data is List ? data : const []);
      final list = rawList
          .map((json) => FileEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort: directories first, then files alphabetically
      list.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (generation == _directoryCacheGeneration) {
        // 容量兜底：单项目长会话内浏览大量目录时防止无界增长（LinkedHashMap
        // 保持插入序，FIFO 淘汰最早写入的条目；失效/清空逻辑不受影响）。
        while (directoryCache.length >= _directoryCacheMaxEntries) {
          directoryCache.remove(directoryCache.keys.first);
        }
        directoryCache[key] = list;
      }
      return list;
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  /// 失效目录缓存。若指定 [path]，只失效对应目录；若未指定，失效对应 [worktree]（或全部）的目录缓存。
  void invalidateDirectoryCache({String? path, String? worktree}) {
    _directoryCacheGeneration++;
    if (path != null) {
      final effectiveWorktree = worktree ?? activeProject.value?.worktree ?? '';
      directoryCache.remove(dirKey(path, effectiveWorktree));
    } else if (worktree != null) {
      final prefix = '$worktree\u0000';
      directoryCache.removeWhere((k, _) => k.startsWith(prefix));
    } else {
      directoryCache.clear();
    }
  }

  /// Mirrors the directory normalization in `OpenCodeClient`'s interceptor:
  /// trim, convert backslashes, drop trailing slashes. Used so worktree
  /// comparisons and locally-stored models stay consistent with the server.
  static String normalizeDirectory(String path) {
    var normalized = path.trim().replaceAll('\\', '/');
    while (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
