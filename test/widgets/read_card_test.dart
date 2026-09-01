import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:opencode_app/api/models/message.dart';
import 'package:opencode_app/controllers/tablet_tool_controller.dart';
import 'package:opencode_app/init.dart';
import 'package:opencode_app/utils/app_settings_store.dart';
import 'package:opencode_app/pages/home/widgets/message/tool_cards/read_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Part _readPart({
  required String status,
  String filePath = 'lib/main.dart',
  String output = '',
}) {
  return Part(
    id: 'p1',
    sessionID: 's1',
    messageID: 'm1',
    type: PartType.tool,
    raw: {
      'id': 'p1',
      'sessionID': 's1',
      'messageID': 'm1',
      'type': 'tool',
      'tool': 'read',
      'state': {
        'status': status,
        'input': <String, dynamic>{
          'filePath': filePath,
          'offset': 10,
          'limit': 20,
        },
        if (output.isNotEmpty) 'output': output,
      },
    },
  );
}

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

  testWidgets(
    'ReadCard renders filename and opens file on tap without locking line',
    (tester) async {
      final part = _readPart(status: 'completed');

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: ReadCard(part: part)),
        ),
      );

      final finder = find.byType(InkWell);
      expect(finder, findsOneWidget);

      final toolCtrl = Get.find<TabletToolController>();
      expect(toolCtrl.openedFiles.isEmpty, isTrue);

      // Tap on the filename
      await tester.tap(finder);
      await tester.pumpAndSettle();

      expect(toolCtrl.openedFiles.length, 1);
      expect(toolCtrl.openedFiles.first.path, 'lib/main.dart');
      expect(toolCtrl.openedFiles.first.targetLine, isNull);
      expect(toolCtrl.activeTabIndex.value, TabletToolController.tabCode);
      expect(toolCtrl.isVisible.value, isTrue);
    },
  );
}
