import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:opencode_app/controllers/tablet_tool_controller.dart';
import 'package:opencode_app/init.dart';
import 'package:opencode_app/utils/app_settings_store.dart';
import 'package:opencode_app/widgets/browser/in_app_browser_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Global.settings = AppSettingsStore(prefs);
    Get.reset();
    Get.put(TabletToolController(), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  Widget wrap() {
    return const MaterialApp(home: Scaffold(body: InAppBrowserView()));
  }

  group('InAppBrowserView empty-tab rendering', () {
    testWidgets('renders the empty placeholder when no tabs are open',
        (tester) async {
      // Regression guard: an empty tab list must not crash the browser
      // (0.clamp(0, -1) throws ArgumentError). No WebViewController is created
      // in this state, so no webview_flutter platform mock is required.
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(InAppBrowserView), findsOneWidget);
    });

    testWidgets('screenshot button is disabled when no tabs are open',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(CupertinoIcons.photo_camera),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, isNotNull);
      expect(button.onPressed, isNull);
    });
  });
}
