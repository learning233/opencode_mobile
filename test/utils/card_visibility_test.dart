import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/utils/card_visibility.dart';

void main() {
  group('cardVisibilityKeyForTool', () {
    test('maps known tools', () {
      expect(cardVisibilityKeyForTool('read'), 'read');
      expect(cardVisibilityKeyForTool('shell'), 'bash');
      expect(cardVisibilityKeyForTool('write'), 'edit');
      expect(cardVisibilityKeyForTool('apply_patch'), 'batch');
      expect(cardVisibilityKeyForTool('list'), 'glob');
      expect(cardVisibilityKeyForTool('websearch'), 'web');
      expect(cardVisibilityKeyForTool('todo_write'), 'todo');
      expect(cardVisibilityKeyForTool('unknown_xyz'), 'fallback');
    });
  });

  group('isCardVisibleInMap', () {
    test('defaults missing key to true', () {
      expect(isCardVisibleInMap({}, 'read'), isTrue);
    });
    test('respects false', () {
      expect(isCardVisibleInMap({'read': false}, 'read'), isFalse);
    });
  });

  group('parseCardVisibilityJson', () {
    test('null and corrupt return empty', () {
      expect(parseCardVisibilityJson(null), isEmpty);
      expect(parseCardVisibilityJson('not-json'), isEmpty);
    });
    test('parses bool map', () {
      expect(parseCardVisibilityJson('{"read":false,"bash":true}'), {
        'read': false,
        'bash': true,
      });
    });
  });
}
