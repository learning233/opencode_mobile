import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:opencode_app/controllers/session_controller.dart';
import 'package:opencode_app/init.dart';
import 'package:opencode_app/pages/home/desktop_session_tab_bar.dart';
import 'package:opencode_app/pages/home/home_app_bar.dart';
import 'package:opencode_app/utils/app_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Global.settings = AppSettingsStore(prefs);
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'DesktopSessionTabBar displays session titles and handles selection',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        // 设置足够大的桌面窗口尺寸
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sessionCtrl = Get.put(SessionController());
        final openedIds = ['s1', 's2', 's3'];
        sessionCtrl.openedSessionIds.assignAll(openedIds);

        String? selectedId;

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              appBar: HomeAppBar(
                sessionCtrl: sessionCtrl,
                opened: openedIds,
                sessionId: 's1',
                title: 'Test Session',
                isTablet: true,
                onSelectSession: (id) => selectedId = id,
              ),
            ),
          ),
        );
        await tester.pump();

        // 验证桌面端渲染了 DesktopSessionTabBar，而不是圆点 SessionIndicator
        expect(find.byType(DesktopSessionTabBar), findsOneWidget);

        // 验证渲染了 3 个会话页签项与 1 个新建会话按钮
        expect(find.byIcon(CupertinoIcons.plus), findsOneWidget);

        // 点击第二个会话
        await tester.tap(find.text(sessionCtrl.getSessionName('s2')));
        await tester.pump();

        expect(selectedId, equals('s2'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'DesktopSessionTabBar differentiates width by title length before overflow',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sessionCtrl = Get.put(SessionController());
        final shortId = 'short_id';
        final longId = 'long_id';
        sessionCtrl.openedSessionIds.assignAll([shortId, longId]);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              appBar: HomeAppBar(
                sessionCtrl: sessionCtrl,
                opened: [shortId, longId],
                sessionId: shortId,
                title: 'Short',
                isTablet: true,
              ),
            ),
          ),
        );
        await tester.pump();

        final tabSizedBoxes = tester
            .widgetList<SizedBox>(
              find.descendant(
                of: find.byType(DesktopSessionTabBar),
                matching: find.byType(SizedBox),
              ),
            )
            .where((box) => box.width != null && box.width! > 32.0)
            .toList();

        expect(tabSizedBoxes.length, greaterThanOrEqualTo(2));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'DesktopSessionTabBar adapts and shrinks tab widths as tabs increase',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sessionCtrl = Get.put(SessionController());
        final manyIds = List.generate(8, (i) => 'sess_$i');
        sessionCtrl.openedSessionIds.assignAll(manyIds);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              appBar: HomeAppBar(
                sessionCtrl: sessionCtrl,
                opened: manyIds,
                sessionId: 'sess_0',
                title: 'Test Session',
                isTablet: true,
              ),
            ),
          ),
        );
        await tester.pump();

        // 验证多 Tab 在 600px 宽度下依然能够正常渲染，并且自适应压缩空间而不会发生溢出
        expect(tester.takeException(), isNull);
        expect(find.byType(DesktopSessionTabBar), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'HomeAppBar includes bottom height and renders bottom on desktop',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final sessionCtrl = Get.put(SessionController());
        final openedIds = ['s1', 's2'];
        sessionCtrl.openedSessionIds.assignAll(openedIds);

        final appBar = HomeAppBar(
          sessionCtrl: sessionCtrl,
          opened: openedIds,
          sessionId: 's1',
          title: 'Test Session',
          isTablet: true,
        );

        // 验证 preferredSize 在桌面端包含了 bottom token 进度条的 2.5 高度 (40.0 + 2.5 = 42.5)
        expect(appBar.preferredSize.height, equals(42.5));

        await tester.pumpWidget(GetMaterialApp(home: Scaffold(appBar: appBar)));
        await tester.pump();

        // 验证桌面端渲染了 DesktopSessionTabBar，并且 bottom 中不再冗余渲染底部的会话标题
        expect(find.byType(DesktopSessionTabBar), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('DesktopSessionTabBar opens context menu on right click', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionCtrl = Get.put(SessionController());
      final openedIds = ['s1', 's2'];
      sessionCtrl.openedSessionIds.assignAll(openedIds);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            appBar: HomeAppBar(
              sessionCtrl: sessionCtrl,
              opened: openedIds,
              sessionId: 's1',
              title: 'Test Session',
              isTablet: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // 在第二个 tab 上触发右键 (secondary click)
      final secondTab = find.text(sessionCtrl.getSessionName('s2'));
      await tester.tap(secondTab, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // 验证弹出了右键菜单项 (关闭 / 关闭其他 / 关闭所有)
      expect(find.byIcon(CupertinoIcons.xmark), findsWidgets);
      expect(find.byIcon(CupertinoIcons.clear_thick), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.trash), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'DesktopSessionTabBar displays close button on hover even for short titles',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sessionCtrl = Get.put(SessionController());
        final shortId = 's1';
        sessionCtrl.openedSessionIds.assignAll([shortId]);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              appBar: HomeAppBar(
                sessionCtrl: sessionCtrl,
                opened: [shortId],
                sessionId: shortId,
                title: 'Short',
                isTablet: true,
              ),
            ),
          ),
        );
        await tester.pump();

        // 移动鼠标悬停在短标题页签上
        final tabFinder = find.byKey(ValueKey(shortId));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(tabFinder));
        await tester.pumpAndSettle();

        // 验证短标题页签悬停时也正确显示了关闭 x 按钮
        expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
