import 'package:get/get.dart';

import '../api/opencode_client.dart';
import '../controllers/project_controller.dart';

/// Canonicalizes a file path so that paths coming from different sources
/// (client-side tool parts, message `summary.diffs`, and the server snapshot
/// `GET /session/{id}/diff` / `GET /vcs/diff`) compare equal.
///
/// Handles: `\` → `/`, a leading worktree/active-directory root, `./` and
/// leading `/`, and `.` / `..` segments. Returns `''` for an empty input.
///
/// When [worktreeRoots] is omitted, the project worktree / active directory are
/// resolved from the app controllers; tests can pass them explicitly.
///
/// Results are memoized keyed by `(worktreeRoots signature, path)` so the
/// per-call controller lookups in [_worktreeRoots] don't run for every diff row.
final Map<String, String> _normalizeCache = <String, String>{};
const int _normalizeCacheLimit = 512;

String normalizeDiffPath(String path, [Iterable<String>? worktreeRoots]) {
  if (path.isEmpty) return path;
  final roots = worktreeRoots ?? _worktreeRoots();
  final sig = StringBuffer('r');
  for (final r in roots) {
    sig
      ..write(r.length)
      ..write(r)
      ..write(';');
  }
  final key = '$sig|$path';
  final cached = _normalizeCache[key];
  if (cached != null) return cached;

  var p = path.replaceAll('\\', '/').trim();

  for (final root in roots) {
    if (root.isEmpty) continue;
    final lowerP = p.toLowerCase();
    final lowerRoot = root.toLowerCase();
    if (lowerP.length > lowerRoot.length && lowerP.startsWith(lowerRoot)) {
      final rest = p.substring(root.length);
      if (rest.startsWith('/')) {
        p = rest.substring(1);
        break;
      }
    }
  }

  while (p.startsWith('/')) {
    p = p.substring(1);
  }
  while (p.startsWith('./')) {
    p = p.substring(2);
  }

  final segments = <String>[];
  for (final seg in p.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(seg);
  }
  final result = segments.join('/');
  if (_normalizeCache.length >= _normalizeCacheLimit) {
    _normalizeCache.clear();
  }
  _normalizeCache[key] = result;
  return result;
}

/// True when [a] and [b] refer to the same file after [normalizeDiffPath],
/// with a case-insensitive fallback (Windows / cross-platform paths).
bool diffPathsEqual(String a, String b, [Iterable<String>? worktreeRoots]) {
  if (a == b) return true;
  final roots = worktreeRoots ?? _worktreeRoots();
  final na = normalizeDiffPath(a, roots);
  final nb = normalizeDiffPath(b, roots);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  return na.toLowerCase() == nb.toLowerCase();
}

/// The project worktree and the client active directory, normalized to `/`.
List<String> _worktreeRoots() {
  final roots = <String>[];
  try {
    if (Get.isRegistered<ProjectController>()) {
      final wt =
          Get.find<ProjectController>().activeProject.value?.worktree ?? '';
      if (wt.isNotEmpty) roots.add(wt.replaceAll('\\', '/'));
    }
  } catch (_) {}
  try {
    final ad = OpenCodeClient().activeDirectory;
    if (ad != null && ad.isNotEmpty) roots.add(ad.replaceAll('\\', '/'));
  } catch (_) {}
  return roots;
}
