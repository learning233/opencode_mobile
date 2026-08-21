import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/controllers/session_controller.dart';
import 'package:opencode_app/init.dart';
import 'package:opencode_app/utils/app_logger.dart';
import 'package:opencode_app/utils/app_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Global.settings = AppSettingsStore(prefs);
    await AppLogger.init(logDir: Directory.systemTemp.createTempSync().path);
  });

  group('attachScreenshotToActiveSession', () {
    test('adds a PNG draft to the active session', () async {
      final ctrl = SessionController();
      ctrl.activeSessionId.value = 's1';

      final ok = await ctrl.attachScreenshotToActiveSession(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(ok, isTrue);
      final state = ctrl.stateOf('s1');
      expect(state.attachedImages.length, 1);
      final img = state.attachedImages.first;
      expect(img.mime, 'image/png');
      expect(img.ext, 'png');
      expect(img.bytes, [1, 2, 3]);
    });

    test('returns false when no active session can be created', () async {
      final ctrl = SessionController();

      final ok = await ctrl.attachScreenshotToActiveSession(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(ok, isFalse);
    });
  });
}
