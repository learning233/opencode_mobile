import 'package:get/get.dart';
import '../api/endpoints.dart';
import '../api/models/project.dart';
import '../api/opencode_client.dart';
import '../init.dart';
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

  Future<void> refreshAfterConnect() async {
    await fetchProjects();
    _restoreLastProject();
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
      // Server doesn't have this project yet — restore from local storage.
      // Only meaningful when lastId is a real path (locally-added project whose
      // id == worktree == path). Server IDs are "global" or a hex hash and must
      // NOT be reused as a worktree, or activeDirectory would point at garbage.
      if (lastId.contains('/') || lastId.contains(r'\')) {
        final local = ProjectModel(id: lastId, worktree: lastId);
        projects.insert(0, local);
        selectProject(local);
        return;
      }
    }
    if (projects.isNotEmpty && activeProject.value == null) {
      selectProject(projects.first);
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

        // Some remote servers only return the global workspace entry via /project.
        // Preserve local projects that the server doesn't know about yet.
        final localOnly = projects.where((p) {
          return !uniqueProjects.any(
            (s) => s.id == p.id || s.worktree == p.worktree,
          );
        }).toList();

        projects.assignAll([...uniqueProjects, ...localOnly]);

        // Re-point activeProject to the canonical entry after the merge: a
        // locally-added project (id == worktree == path) may have been replaced
        // by the server's version under a hashed id with the same worktree.
        // Without this, the list highlight (compared by id) would silently drop.
        final active = activeProject.value;
        if (active != null) {
          final reResolved = projects.firstWhereOrNull(
            (p) => p.id == active.id || p.worktree == active.worktree,
          );
          if (reResolved != null && reResolved.id != active.id) {
            activeProject.value = reResolved;
          }
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
        await _client.post(
          ApiEndpoints.instanceDispose,
          directory: normalized,
        );
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
    Global.lastProjectId = project.id;
    AppLogger.i('Selected project: ${project.displayName} (${project.id})');

    // Refresh sessions and re-scope SSE for the new project
    final sessionCtrl = Get.find<SessionController>();
    sessionCtrl.onProjectChanged(project.worktree);
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
