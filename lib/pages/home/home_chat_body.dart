import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/session_controller.dart';
import '../../utils/translations.dart';
import 'chat_view.dart';
import 'prompt_input.dart';

/// Home 页面会话聊天流主体组件。
/// 封装了多会话横向滑动（PageView）、智能注意力滑跃调度、同步与空状态展示。
class HomeChatBody extends StatefulWidget {
  const HomeChatBody({super.key});

  @override
  State<HomeChatBody> createState() => _HomeChatBodyState();
}

class _HomeChatBodyState extends State<HomeChatBody> {
  late PageController _pageController;
  Worker? _activeSessionWorker;
  Worker? _openedSessionsWorker;
  int? _swipeStartPage;
  bool _isSmartNavigating = false;

  @override
  void initState() {
    super.initState();
    final sessionCtrl = Get.find<SessionController>();
    final initialActiveId = sessionCtrl.activeSessionId.value;
    final initialOpened = sessionCtrl.openedSessionIds.toList();
    final initialIdx = initialOpened.indexOf(initialActiveId);

    _pageController = PageController(
      initialPage: initialIdx != -1 ? initialIdx : 0,
    );

    void syncPageToActiveSession({bool immediate = false}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final activeId = sessionCtrl.activeSessionId.value;
        final opened = sessionCtrl.openedSessionIds.toList();
        final idx = opened.indexOf(activeId);
        if (idx != -1 && _pageController.page?.round() != idx) {
          if (immediate) {
            _pageController.jumpToPage(idx);
          } else {
            _pageController.animateToPage(
              idx,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }

    _activeSessionWorker = ever(
      sessionCtrl.activeSessionId,
      (_) => syncPageToActiveSession(),
    );
    _openedSessionsWorker = ever(
      sessionCtrl.openedSessionIds,
      (_) => syncPageToActiveSession(),
    );
  }

  @override
  void dispose() {
    _activeSessionWorker?.dispose();
    _openedSessionsWorker?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectCtrl = Get.find<ProjectController>();
    final sessionCtrl = Get.find<SessionController>();

    return Obx(() {
      final project = projectCtrl.activeProject.value;
      final opened = sessionCtrl.openedSessionIds.toList();

      if (project == null) {
        return Center(child: Text(LocaleKeys.mobileSelectProject.tr));
      }

      if (opened.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                LocaleKeys.mobileNoActiveSessions.tr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => sessionCtrl.createNewSession(),
                child: Text(LocaleKeys.cmdNewSession.tr),
              ),
            ],
          ),
        );
      }

      // Ensure PageController is synced to active session when returning/building
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final activeId = sessionCtrl.activeSessionId.value;
        final idx = opened.indexOf(activeId);
        if (idx != -1 && _pageController.page?.round() != idx) {
          _pageController.jumpToPage(idx);
        }
      });

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            if (_pageController.hasClients) {
              _swipeStartPage = _pageController.page?.round();
            }
          } else if (notification is ScrollEndNotification) {
            final startPage = _swipeStartPage;
            _swipeStartPage = null;
            if (startPage != null &&
                _pageController.hasClients &&
                !_isSmartNavigating) {
              final currentPage = _pageController.page?.round() ?? startPage;
              if (currentPage != startPage) {
                // Re-fetch latest opened list to avoid stale closure
                final latestOpened = sessionCtrl.openedSessionIds.toList();
                final isForward = currentPage > startPage;
                final targetIdx = sessionCtrl.getNextAttentionPageIndex(
                  currentIndex: startPage,
                  openedIds: latestOpened,
                  isForward: isForward,
                );
                // 若算法匹配到的待办卡片非相邻卡片（如由 Page 1 智能滑跃至 Page 4）
                if (targetIdx != currentPage &&
                    targetIdx >= 0 &&
                    targetIdx < latestOpened.length &&
                    (targetIdx - startPage).abs() > 1) {
                  _isSmartNavigating = true;
                  _pageController
                      .animateToPage(
                        targetIdx,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      )
                      .whenComplete(() {
                        _isSmartNavigating = false;
                      });
                  sessionCtrl.selectSession(latestOpened[targetIdx]);
                }
              }
            }
          }
          return false;
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: opened.length,
          allowImplicitScrolling: true,
          onPageChanged: (page) {
            if (!_isSmartNavigating && page >= 0) {
              final latestOpened = sessionCtrl.openedSessionIds.toList();
              if (page < latestOpened.length) {
                sessionCtrl.selectSession(latestOpened[page]);
              }
            }
          },
          itemBuilder: (context, index) {
            final sid = opened[index];
            return Column(
              key: ValueKey('page_$sid'),
              children: [
                Expanded(child: ChatView(sessionId: sid)),
                PromptInput(sessionId: sid),
              ],
            );
          },
        ),
      );
    });
  }
}
