import 'package:test/test.dart';
import 'package:kterm/src/utils/byte_consumer.dart';

void main() {
  group('ByteConsumer', () {
    group('add', () {
      test('adds data to the queue', () {
        final consumer = ByteConsumer();
        consumer.add('abc');
        expect(consumer.length, equals(3));
      });

      test('ignores empty string', () {
        final consumer = ByteConsumer();
        consumer.add('');
        expect(consumer.length, equals(0));
      });

      test('handles unicode characters', () {
        final consumer = ByteConsumer();
        consumer.add('你好');
        expect(consumer.length, equals(2));
      });

      test('appends to existing data', () {
        final consumer = ByteConsumer();
        consumer.add('ab');
        consumer.add('cd');
        expect(consumer.length, equals(4));
      });
    });

    group('consume', () {
      test('consumes bytes in order', () {
        final consumer = ByteConsumer();
        consumer.add('abcd');

        expect(consumer.consume(), equals('a'.codeUnitAt(0)));
        expect(consumer.consume(), equals('b'.codeUnitAt(0)));
        expect(consumer.consume(), equals('c'.codeUnitAt(0)));
        expect(consumer.consume(), equals('d'.codeUnitAt(0)));
      });

      test('crosses chunk boundaries', () {
        final consumer = ByteConsumer();
        consumer.add('ab');
        consumer.add('cd');

        expect(consumer.consume(), equals('a'.codeUnitAt(0)));
        expect(consumer.consume(), equals('b'.codeUnitAt(0)));
        expect(consumer.consume(), equals('c'.codeUnitAt(0)));
        expect(consumer.consume(), equals('d'.codeUnitAt(0)));
      });

      test('tracks totalConsumed', () {
        final consumer = ByteConsumer();
        consumer.add('abc');

        consumer.consume();
        consumer.consume();

        expect(consumer.totalConsumed, equals(2));
      });

      test('decreases length', () {
        final consumer = ByteConsumer();
        consumer.add('abc');

        expect(consumer.length, equals(3));
        consumer.consume();
        expect(consumer.length, equals(2));
      });
    });

    group('peek', () {
      test('returns next byte without consuming', () {
        final consumer = ByteConsumer();
        consumer.add('abc');

        expect(consumer.peek(), equals('a'.codeUnitAt(0)));
        expect(consumer.peek(), equals('a'.codeUnitAt(0)));
        expect(consumer.length, equals(3));
      });

      test('works across chunk boundaries', () {
        final consumer = ByteConsumer();
        consumer.add('ab');
        consumer.add('cd');

        expect(consumer.peek(), equals('a'.codeUnitAt(0)));
        consumer.consume();
        expect(consumer.peek(), equals('b'.codeUnitAt(0)));
        consumer.consume();
        expect(consumer.peek(), equals('c'.codeUnitAt(0)));
      });
    });

    group('rollback', () {
      test('rolls back a single byte', () {
        final consumer = ByteConsumer();
        consumer.add('abc');

        consumer.consume(); // consumed 'a'
        expect(consumer.length, equals(2));

        consumer.rollback(1);
        expect(consumer.length, equals(3));
        expect(consumer.peek(), equals('a'.codeUnitAt(0)));
      });

      test('rolls back multiple bytes', () {
        final consumer = ByteConsumer();
        consumer.add('abcd');

        consumer.consume(); // 'a'
        consumer.consume(); // 'b'
        consumer.consume(); // 'c'

        consumer.rollback(2);
        expect(consumer.length, equals(3));
        expect(consumer.peek(), equals('b'.codeUnitAt(0)));
      });

      test('rolls back across chunk boundaries', () {
        final consumer = ByteConsumer();
        consumer.add('ab');
        consumer.add('cd');

        consumer.consume(); // 'a'
        consumer.consume(); // 'b'
        consumer.consume(); // 'c'
        consumer.consume(); // 'd'

        consumer.rollback(3);
        expect(consumer.peek(), equals('b'.codeUnitAt(0)));
      });

      test('adjusts totalConsumed', () {
        final consumer = ByteConsumer();
        consumer.add('abc');

        consumer.consume();
        consumer.consume();
        expect(consumer.totalConsumed, equals(2));

        consumer.rollback(1);
        expect(consumer.totalConsumed, equals(1));
      });
    });

    group('rollbackTo', () {
      test('rolls back to specific length', () {
        final consumer = ByteConsumer();
        consumer.add('abcd');

        consumer.consume(); // length = 3
        consumer.consume(); // length = 2
        consumer.consume(); // length = 1

        consumer.rollbackTo(2);
        expect(consumer.length, equals(2));
      });
    });

    group('isEmpty / isNotEmpty', () {
      test('isEmpty returns true for empty consumer', () {
        final consumer = ByteConsumer();
        expect(consumer.isEmpty, isTrue);
        expect(consumer.isNotEmpty, isFalse);
      });

      test('isEmpty returns false for non-empty consumer', () {
        final consumer = ByteConsumer();
        consumer.add('a');
        expect(consumer.isEmpty, isFalse);
        expect(consumer.isNotEmpty, isTrue);
      });

      test('becomes empty after consuming all', () {
        final consumer = ByteConsumer();
        consumer.add('a');

        expect(consumer.isNotEmpty, isTrue);
        consumer.consume();
        expect(consumer.isEmpty, isTrue);
      });
    });

    group('unrefConsumedBlocks', () {
      test('clears consumed blocks', () {
        final consumer = ByteConsumer();
        consumer.add('ab');
        consumer.add('cd');

        // Consume all
        consumer.consume();
        consumer.consume();
        consumer.consume();
        consumer.consume();

        // At this point the consumer is empty
        expect(consumer.isEmpty, isTrue);

        // Unref should not throw
        consumer.unrefConsumedBlocks();
      });

      test('allows further operations after unref', () {
        final consumer = ByteConsumer();
        consumer.add('ab');
        consumer.consume();
        consumer.unrefConsumedBlocks();

        // After consuming 'a', 'b' remains in queue
        // After unref, we can still add more data
        consumer.add('cd');
        // Total: 'b' + 'cd' = 3
        expect(consumer.length, equals(3));
      });
    });

    group('reset', () {
      test('clears all state', () {
        final consumer = ByteConsumer();
        consumer.add('abc');
        consumer.consume();
        consumer.consume();

        consumer.reset();

        expect(consumer.length, equals(0));
        expect(consumer.totalConsumed, equals(0));
        expect(consumer.isEmpty, isTrue);
      });
    });

    group('length', () {
      test('starts at 0', () {
        final consumer = ByteConsumer();
        expect(consumer.length, equals(0));
      });

      test('increases with add', () {
        final consumer = ByteConsumer();
        consumer.add('ab');
        expect(consumer.length, equals(2));
        consumer.add('c');
        expect(consumer.length, equals(3));
      });

      test('decreases with consume', () {
        final consumer = ByteConsumer();
        consumer.add('abc');
        consumer.consume();
        expect(consumer.length, equals(2));
      });

      test('increases with rollback', () {
        final consumer = ByteConsumer();
        consumer.add('abc');
        consumer.consume();
        expect(consumer.length, equals(2));
        consumer.rollback(1);
        expect(consumer.length, equals(3));
      });
    });

    group('totalConsumed', () {
      test('starts at 0', () {
        final consumer = ByteConsumer();
        expect(consumer.totalConsumed, equals(0));
      });

      test('increases with consume', () {
        final consumer = ByteConsumer();
        consumer.add('abc');
        consumer.consume();
        expect(consumer.totalConsumed, equals(1));
        consumer.consume();
        expect(consumer.totalConsumed, equals(2));
      });

      test('decreases with rollback', () {
        final consumer = ByteConsumer();
        consumer.add('abc');
        consumer.consume();
        consumer.consume();
        expect(consumer.totalConsumed, equals(2));
        consumer.rollback(1);
        expect(consumer.totalConsumed, equals(1));
      });

      test('resets with reset()', () {
        final consumer = ByteConsumer();
        consumer.add('abc');
        consumer.consume();
        consumer.reset();
        expect(consumer.totalConsumed, equals(0));
      });
    });
  });
}
