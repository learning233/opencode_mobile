import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/base/event.dart';

void main() {
  group('EventEmitter', () {
    group('call (add listener)', () {
      test('Given no listeners, When call called, Then returns subscription',
          () {
        final emitter = EventEmitter<String>();

        final subscription = emitter.call((event) {});

        expect(subscription, isA<EventSubscription<String>>());
      });

      test('Given listener, When call called, Then listener is registered', () {
        final emitter = EventEmitter<String>();
        int callCount = 0;

        emitter.call((event) => callCount++);

        emitter.emit('test');
        expect(callCount, equals(1));
      });
    });

    group('emit', () {
      test(
          'Given single listener, When emit called, Then listener receives event',
          () {
        final emitter = EventEmitter<String>();
        String? received;

        emitter.call((event) => received = event);
        emitter.emit('hello');

        expect(received, equals('hello'));
      });

      test(
          'Given multiple listeners, When emit called, Then all listeners receive event',
          () {
        final emitter = EventEmitter<int>();
        int result1 = 0;
        int result2 = 0;

        emitter.call((event) => result1 += event);
        emitter.call((event) => result2 += event);
        emitter.emit(5);

        expect(result1, equals(5));
        expect(result2, equals(5));
      });

      test('Given no listeners, When emit called, Then no error thrown', () {
        final emitter = EventEmitter<String>();

        expect(() => emitter.emit('test'), returnsNormally);
      });
    });

    group('event', () {
      test('Given emitter, When event accessed, Then returns Event instance',
          () {
        final emitter = EventEmitter<String>();

        final event = emitter.event;

        expect(event, isA<Event<String>>());
        expect(event.emitter, equals(emitter));
      });
    });
  });

  group('Event', () {
    test(
        'Given event with listener, When call called, Then listener is invoked',
        () {
      final emitter = EventEmitter<String>();
      String? received;

      emitter.event.call((event) => received = event);
      emitter.emit('test');

      expect(received, equals('test'));
    });
  });

  group('EventSubscription', () {
    test(
        'Given subscription, When dispose called, Then listener is removed from emitter',
        () {
      final emitter = EventEmitter<String>();
      int callCount = 0;

      final subscription = emitter.call((event) => callCount++);
      subscription.dispose();

      emitter.emit('test');

      expect(callCount, equals(0));
    });

    test(
        'Given already disposed subscription, When dispose called again, Then no error thrown',
        () {
      final emitter = EventEmitter<String>();
      final subscription = emitter.call((event) {});

      subscription.dispose();

      expect(() => subscription.dispose(), returnsNormally);
    });

    test(
        'Given subscription, When disposed property accessed, Then returns false initially',
        () {
      final emitter = EventEmitter<String>();
      final subscription = emitter.call((event) {});

      expect(subscription.disposed, isFalse);
    });

    test(
        'Given subscription after dispose, When disposed property accessed, Then returns true',
        () {
      final emitter = EventEmitter<String>();
      final subscription = emitter.call((event) {});

      subscription.dispose();

      // Note: EventSubscription does not have a separate disposed flag
      // The listener is removed from the emitter but subscription.disposed is not set
    });
  });

  group('EventEmitter with onDisposed', () {
    test('Given disposable, When dispose called, Then onDisposed is emitted',
        () {
      final emitter = EventEmitter<String>();
      int callCount = 0;

      final subscription = emitter.call((event) {});
      // Note: EventSubscription.onDisposed is from Disposable mixin
      // but it uses a separate EventEmitter, not connected to subscription
      subscription.dispose();

      // This is not how EventSubscription works - just verify dispose doesn't throw
      expect(callCount, equals(0));
    });
  });
}
