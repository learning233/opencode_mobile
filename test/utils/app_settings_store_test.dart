import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/app_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsStore per-project preview port', () {
    late AppSettingsStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = AppSettingsStore(await SharedPreferences.getInstance());
    });

    test('returns null when nothing is bound', () {
      expect(store.getPreviewPort('projA'), isNull);
    });

    test('binds a port per project', () async {
      await store.setPreviewPort('projA', '5173');
      await store.setPreviewPort('projB', '3000');

      expect(store.getPreviewPort('projA'), '5173');
      expect(store.getPreviewPort('projB'), '3000');
    });

    test('projects are isolated', () async {
      await store.setPreviewPort('projA', '5173');
      expect(store.getPreviewPort('projB'), isNull);
    });

    test('clears a binding with null or empty', () async {
      await store.setPreviewPort('projA', '5173');
      await store.setPreviewPort('projA', null);
      expect(store.getPreviewPort('projA'), isNull);

      await store.setPreviewPort('projB', '3000');
      await store.setPreviewPort('projB', '');
      expect(store.getPreviewPort('projB'), isNull);
    });

    test('overwrites an existing binding', () async {
      await store.setPreviewPort('projA', '5173');
      await store.setPreviewPort('projA', '8080');
      expect(store.getPreviewPort('projA'), '8080');
    });

    test('getPreviewPorts returns all bindings', () async {
      await store.setPreviewPort('projA', '5173');
      await store.setPreviewPort('projB', '3000');
      final all = store.getPreviewPorts();
      expect(all, {'projA': '5173', 'projB': '3000'});
    });

    test('empty project key is ignored', () async {
      await store.setPreviewPort('', '5173');
      expect(store.getPreviewPort(''), isNull);
      expect(store.getPreviewPorts(), isEmpty);
    });
  });
}
