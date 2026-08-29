import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/controllers/tablet_tool_controller.dart';

void main() {
  group('TabletToolController content cache', () {
    late TabletToolController ctrl;

    setUp(() {
      ctrl = TabletToolController();
      ctrl.openFile('lib/a.dart', 'a.dart');
    });

    test('cachedContent returns null before any cache write', () {
      expect(ctrl.cachedContent('lib/a.dart'), isNull);
    });

    test('cacheFileContent stores content for a path', () {
      ctrl.cacheFileContent('lib/a.dart', 'hello');
      expect(ctrl.cachedContent('lib/a.dart'), 'hello');
    });

    test('cacheFileContent overwrites previous content', () {
      ctrl.cacheFileContent('lib/a.dart', 'v1');
      ctrl.cacheFileContent('lib/a.dart', 'v2');
      expect(ctrl.cachedContent('lib/a.dart'), 'v2');
    });

    test('cacheFileContent does not replace the OpenedFile in openedFiles', () {
      ctrl.cacheFileContent('lib/a.dart', 'hello');
      final file = ctrl.openedFiles.firstWhere((f) => f.path == 'lib/a.dart');
      expect(file.initialContent, isNull);
    });

    test(
      'cacheFileContent works for any path (independent of openedFiles)',
      () {
        ctrl.cacheFileContent('lib/unknown.dart', 'x');
        expect(ctrl.cachedContent('lib/unknown.dart'), 'x');
      },
    );

    test('invalidateFileContent drops the cached content', () {
      ctrl.cacheFileContent('lib/a.dart', 'hello');
      ctrl.invalidateFileContent('lib/a.dart');
      expect(ctrl.cachedContent('lib/a.dart'), isNull);
    });

    test('closeFile clears the cache entry for that path', () {
      ctrl.cacheFileContent('lib/a.dart', 'hello');
      ctrl.closeFile('lib/a.dart');
      expect(ctrl.cachedContent('lib/a.dart'), isNull);
      expect(ctrl.openedFiles, isEmpty);
    });
  });

  group('TabletToolController file change signals', () {
    test('fileChangeTick starts at zero', () {
      final ctrl = TabletToolController();
      expect(ctrl.fileChangeTick.value, 0);
    });

    test('lastChangedFile starts empty', () {
      final ctrl = TabletToolController();
      expect(ctrl.lastChangedFile.value, isEmpty);
    });
  });

  group('TabletToolController cross-worktree tabs', () {
    test('same relative path from different worktrees are distinct tabs', () {
      final ctrl = TabletToolController();
      ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projA');
      ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projB');
      expect(ctrl.openedFiles.length, 2);
      expect(
        ctrl.activeFileKey,
        TabletToolController.fileKey('lib/a.dart', '/projB'),
      );
    });

    test(
      're-opening the same worktree+path activates instead of duplicating',
      () {
        final ctrl = TabletToolController();
        ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projA');
        ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projB');
        ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projA');
        expect(ctrl.openedFiles.length, 2);
        expect(
          ctrl.activeFileKey,
          TabletToolController.fileKey('lib/a.dart', '/projA'),
        );
      },
    );

    test('selectFile disambiguates by worktree', () {
      final ctrl = TabletToolController();
      ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projA');
      ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projB');
      ctrl.selectFile('lib/a.dart', worktree: '/projA');
      expect(
        ctrl.activeFileKey,
        TabletToolController.fileKey('lib/a.dart', '/projA'),
      );
      ctrl.selectFile('lib/a.dart', worktree: '/projB');
      expect(
        ctrl.activeFileKey,
        TabletToolController.fileKey('lib/a.dart', '/projB'),
      );
    });

    test('closeFile by worktree removes only that tab and fixes active', () {
      final ctrl = TabletToolController();
      ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projA');
      ctrl.openFile('lib/a.dart', 'a.dart', worktree: '/projB');
      ctrl.selectFile('lib/a.dart', worktree: '/projB');
      ctrl.closeFile('lib/a.dart', worktree: '/projB');
      expect(ctrl.openedFiles.length, 1);
      expect(
        ctrl.activeFileKey,
        TabletToolController.fileKey('lib/a.dart', '/projA'),
      );
    });

    test('content cache is keyed by worktree+path', () {
      final ctrl = TabletToolController();
      ctrl.cacheFileContent('lib/a.dart', 'contentA', worktree: '/projA');
      ctrl.cacheFileContent('lib/a.dart', 'contentB', worktree: '/projB');
      expect(ctrl.cachedContent('lib/a.dart', worktree: '/projA'), 'contentA');
      expect(ctrl.cachedContent('lib/a.dart', worktree: '/projB'), 'contentB');
      ctrl.invalidateFileContent('lib/a.dart', worktree: '/projA');
      expect(ctrl.cachedContent('lib/a.dart', worktree: '/projA'), isNull);
      expect(ctrl.cachedContent('lib/a.dart', worktree: '/projB'), 'contentB');
    });
  });

  group('TabletToolController review tab switching', () {
    test(
      'openReviewMessageFile in same scope switches to review tab and shows panel',
      () {
        final ctrl = TabletToolController();
        ctrl.openReviewMessage('s1', 'm1', selectFile: 'a.dart');
        ctrl.activeTabIndex.value = TabletToolController.tabCode;
        ctrl.isVisible.value = false;

        ctrl.openReviewMessageFile('s1', 'm1', selectFile: 'b.dart');

        expect(ctrl.reviewSelectedFile.value, 'b.dart');
        expect(ctrl.activeTabIndex.value, TabletToolController.tabReview);
        expect(ctrl.isVisible.value, isTrue);
      },
    );

    test(
      'openReviewMessageFile in a different scope refetches and switches',
      () {
        final ctrl = TabletToolController();
        ctrl.activeTabIndex.value = TabletToolController.tabCode;
        final tickBefore = ctrl.reviewReloadTick.value;

        ctrl.openReviewMessageFile('s1', 'm1', selectFile: 'a.dart');

        expect(ctrl.reviewType.value, TabletToolController.reviewTypeMessage);
        expect(ctrl.reviewSessionId.value, 's1');
        expect(ctrl.reviewMessageId.value, 'm1');
        expect(ctrl.reviewSelectedFile.value, 'a.dart');
        expect(ctrl.reviewReloadTick.value, tickBefore + 1);
        expect(ctrl.activeTabIndex.value, TabletToolController.tabReview);
      },
    );

    test(
      'openReviewSessionFile in same scope switches to review tab and shows panel',
      () {
        final ctrl = TabletToolController();
        ctrl.openReviewSession('s1', selectFile: 'a.dart');
        ctrl.activeTabIndex.value = TabletToolController.tabCode;
        ctrl.isVisible.value = false;

        ctrl.openReviewSessionFile('s1', selectFile: 'b.dart');

        expect(ctrl.reviewSelectedFile.value, 'b.dart');
        expect(ctrl.activeTabIndex.value, TabletToolController.tabReview);
        expect(ctrl.isVisible.value, isTrue);
      },
    );

    test(
      'openReviewSessionFile in a different scope refetches and switches',
      () {
        final ctrl = TabletToolController();
        ctrl.activeTabIndex.value = TabletToolController.tabCode;
        final tickBefore = ctrl.reviewReloadTick.value;

        ctrl.openReviewSessionFile('s1', selectFile: 'a.dart');

        expect(ctrl.reviewType.value, TabletToolController.reviewTypeSession);
        expect(ctrl.reviewSessionId.value, 's1');
        expect(ctrl.reviewSelectedFile.value, 'a.dart');
        expect(ctrl.reviewReloadTick.value, tickBefore + 1);
        expect(ctrl.activeTabIndex.value, TabletToolController.tabReview);
      },
    );

    test(
      'openReviewSession with switchTab=false refreshes data without switching tab',
      () {
        final ctrl = TabletToolController();
        ctrl.activeTabIndex.value = TabletToolController.tabCode;
        ctrl.isVisible.value = false;
        final tickBefore = ctrl.reviewReloadTick.value;

        ctrl.openReviewSession('s1', selectFile: 'a.dart', switchTab: false);

        expect(ctrl.reviewType.value, TabletToolController.reviewTypeSession);
        expect(ctrl.reviewSessionId.value, 's1');
        expect(ctrl.reviewSelectedFile.value, 'a.dart');
        expect(ctrl.reviewReloadTick.value, tickBefore + 1);
        expect(ctrl.activeTabIndex.value, TabletToolController.tabCode);
        expect(ctrl.isVisible.value, isFalse);
      },
    );
  });

  group('TabletToolController browser tabs', () {
    test(
      'openUrl with empty url switches to web tab without creating a tab',
      () {
        final ctrl = TabletToolController();
        ctrl.activeTabIndex.value = TabletToolController.tabCode;
        ctrl.isVisible.value = false;

        ctrl.openUrl('');

        expect(ctrl.browserTabs, isEmpty);
        expect(ctrl.activeTabIndex.value, TabletToolController.tabWeb);
        expect(ctrl.isVisible.value, isTrue);
      },
    );

    test('openUrl creates a new tab and focuses it', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');

      expect(ctrl.browserTabs.length, 1);
      expect(ctrl.browserTabs[0].url, 'https://example.com/a');
      expect(ctrl.activeBrowserTabIndex.value, 0);
      expect(ctrl.activeTabIndex.value, TabletToolController.tabWeb);
    });

    test('openUrl normalizes scheme-less URLs', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('localhost:8080');

      expect(ctrl.browserTabs[0].url, 'https://localhost:8080');
    });

    test(
      'openUrl with an existing normalized URL switches instead of duplicating',
      () {
        final ctrl = TabletToolController();
        ctrl.openUrl('https://example.com/a');
        ctrl.openUrl('https://example.com/b');
        expect(ctrl.browserTabs.length, 2);
        expect(ctrl.activeBrowserTabIndex.value, 1);

        ctrl.openUrl('example.com/a');

        expect(ctrl.browserTabs.length, 2);
        expect(ctrl.activeBrowserTabIndex.value, 0);
      },
    );

    test('newBrowserTab adds a blank tab and focuses it', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');
      ctrl.newBrowserTab();

      expect(ctrl.browserTabs.length, 2);
      expect(ctrl.browserTabs[1].url, '');
      expect(ctrl.activeBrowserTabIndex.value, 1);
    });

    test('switchBrowserTab ignores out-of-range index', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');
      ctrl.switchBrowserTab(5);
      expect(ctrl.activeBrowserTabIndex.value, 0);
    });

    test('closeBrowserTab closes active tab and selects neighbor', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');
      ctrl.openUrl('https://example.com/b');
      ctrl.openUrl('https://example.com/c');
      ctrl.activeBrowserTabIndex.value = 1;

      ctrl.closeBrowserTab(1);

      expect(ctrl.browserTabs.length, 2);
      expect(ctrl.browserTabs[1].url, 'https://example.com/c');
      expect(ctrl.activeBrowserTabIndex.value, 1);
    });

    test('closeBrowserTab closes a non-active tab before it', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');
      ctrl.openUrl('https://example.com/b');
      ctrl.openUrl('https://example.com/c');
      ctrl.activeBrowserTabIndex.value = 2;

      ctrl.closeBrowserTab(0);

      expect(ctrl.browserTabs.length, 2);
      expect(ctrl.activeBrowserTabIndex.value, 1);
    });

    test('closeBrowserTab of the only tab resets to index 0', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');
      ctrl.closeBrowserTab(0);
      expect(ctrl.browserTabs, isEmpty);
      expect(ctrl.activeBrowserTabIndex.value, 0);
    });

    test('updateBrowserTabUrl updates url and normalizes', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');
      ctrl.updateBrowserTabUrl(0, 'example.com/b');
      expect(ctrl.browserTabs[0].url, 'https://example.com/b');
    });

    test('updateBrowserTabUrl ignores blank url', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');
      ctrl.updateBrowserTabUrl(0, '   ');
      expect(ctrl.browserTabs[0].url, 'https://example.com/a');
    });

    test('toggleBrowserTabDesktopMode flips per-tab desktop mode', () {
      final ctrl = TabletToolController();
      ctrl.openUrl('https://example.com/a');
      ctrl.openUrl('https://example.com/b');

      ctrl.toggleBrowserTabDesktopMode(0);

      expect(ctrl.browserTabs[0].isDesktopMode, isTrue);
      expect(ctrl.browserTabs[1].isDesktopMode, isFalse);

      ctrl.toggleBrowserTabDesktopMode(0);
      expect(ctrl.browserTabs[0].isDesktopMode, isFalse);
    });
  });
}
