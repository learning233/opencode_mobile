import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Double Back To Exit Tests', () {
    test('LocaleKeys contains pressBackAgainToExit in zh and en maps', () {
      final translations = Messages();
      final zh = translations.keys['zh_CN'];
      final en = translations.keys['en_US'];

      expect(zh, isNotNull);
      expect(en, isNotNull);

      expect(zh![LocaleKeys.pressBackAgainToExit], '再按一次退出应用');
      expect(en![LocaleKeys.pressBackAgainToExit], 'Press back again to exit');
    });

    test('Double back interval logic (2 seconds limit)', () {
      DateTime? lastBackTime;
      bool shouldExit = false;

      void onBackInvoked(DateTime now) {
        if (lastBackTime == null ||
            now.difference(lastBackTime!) > const Duration(seconds: 2)) {
          lastBackTime = now;
          shouldExit = false;
        } else {
          shouldExit = true;
        }
      }

      final t0 = DateTime(2026, 9, 1, 12, 0, 0);
      onBackInvoked(t0);
      expect(shouldExit, isFalse, reason: 'First tap should not exit');

      // 1.5 seconds later -> tap again -> should exit
      final t1 = t0.add(const Duration(milliseconds: 1500));
      onBackInvoked(t1);
      expect(shouldExit, isTrue, reason: 'Second tap within 2s should exit');

      // Reset
      lastBackTime = null;
      onBackInvoked(t0);
      expect(shouldExit, isFalse);

      // 2.5 seconds later -> tap again -> should NOT exit (expired)
      final t2 = t0.add(const Duration(milliseconds: 2500));
      onBackInvoked(t2);
      expect(shouldExit, isFalse, reason: 'Tap after 2s should reset timer');
    });
  });
}
