import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/session_controller.dart';
import '../../api/models/session.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/translations.dart';

class SessionListPage extends StatefulWidget {
  const SessionListPage({super.key});

  @override
  State<SessionListPage> createState() => _SessionListPageState();
}

class _SessionListPageState extends State<SessionListPage> {
  final _searchCtrl = TextEditingController();
  final _query = ''.obs;
  final _loading = false.obs;

  SessionController get _ctrl => Get.find<SessionController>();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _loading.value = true;
    // fetchSessions never rethrows — errors are surfaced via sessionsError.
    await _ctrl.fetchSessions();
    _loading.value = false;
  }

  List<SessionModel> _filtered(List<SessionModel> all) {
    final q = _query.value.trim().toLowerCase();
    // `all` is already a fresh copy from the caller (sessions.toList()), so
    // sort in place instead of copying again.
    all.sort((a, b) => b.time.updated.compareTo(a.time.updated));
    if (q.isEmpty) return all;
    return all.where((s) {
      final name = s.displayName.toLowerCase();
      return name.contains(q) || s.id.toLowerCase().contains(q);
    }).toList();
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return LocaleKeys.mobileJustNow.tr;
    if (diff.inHours < 1) {
      return LocaleKeys.mobileMinutesAgo.trParams({
        'count': '${diff.inMinutes}',
      });
    }
    if (diff.inDays < 1) {
      return LocaleKeys.mobileHoursAgo.trParams({'count': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return LocaleKeys.mobileDaysAgo.trParams({'count': '${diff.inDays}'});
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  final _deleting = <String>{};

  Future<bool> _confirmDeleteDialog(SessionModel session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.mobileDeleteSessionTitle.tr),
        content: Text(
          LocaleKeys.mobileDeleteSessionConfirm.trParams({
            'name': session.displayName,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleKeys.cancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.delete.tr),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Actually deletes the session and surfaces failures. Returns true on
  /// success so callers can dismiss the row; false on failure (row stays).
  Future<bool> _doDelete(SessionModel session) async {
    if (_deleting.contains(session.id)) return false;
    _deleting.add(session.id);
    try {
      final ok = await _ctrl.deleteSession(session.id);
      if (!ok) {
        Snack.error(LocaleKeys.mobileDeleteSessionFailed.tr);
      }
      return ok;
    } finally {
      _deleting.remove(session.id);
    }
  }

  void _openSession(SessionModel session) {
    _ctrl.selectSession(session.id);
    // Return to the existing root HomePage. offNamedUntil(home, isFirst) keeps
    // the root route AND pushes a second HomePage, so use popUntil instead.
    Get.until((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.mobileSessions.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: LocaleKeys.mobileSearchSessions.tr,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: Obx(() {
                  if (_query.value.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _query.value = '';
                    },
                  );
                }),
              ),
              onChanged: (v) => _query.value = v,
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_loading.value && _ctrl.sessions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_ctrl.sessionsError.value != null && _ctrl.sessions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _ctrl.sessionsError.value!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _refresh,
                        child: Text(LocaleKeys.retry.tr),
                      ),
                    ],
                  ),
                );
              }
              final list = _filtered(_ctrl.sessions.toList());
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    _query.value.isEmpty
                        ? LocaleKeys.mobileNoSessions.tr
                        : LocaleKeys.mobileNoMatchingSessions.tr,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final s = list[i];
                    final isOpened = _ctrl.openedSessionIds.contains(s.id);
                    return Dismissible(
                      key: ValueKey(s.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        if (!await _confirmDeleteDialog(s)) return false;
                        return _doDelete(s);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: theme.colorScheme.error,
                        child: Icon(
                          Icons.delete,
                          color: theme.colorScheme.onError,
                        ),
                      ),
                      child: ListTile(
                        selected: isOpened,
                        title: Text(
                          s.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isOpened
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          _formatTime(s.time.updated),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () async {
                            if (await _confirmDeleteDialog(s)) {
                              await _doDelete(s);
                            }
                          },
                        ),
                        onTap: () => _openSession(s),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
