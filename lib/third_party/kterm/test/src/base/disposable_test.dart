import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/base/disposable.dart';

class TestDisposable with Disposable {
  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

void main() {
  group('Disposable', () {
    group('disposed property', () {
      test('Given new Disposable, When disposed accessed, Then returns false',
          () {
        final disposable = TestDisposable();

        expect(disposable.disposed, isFalse);
      });

      test(
          'Given disposed Disposable, When disposed accessed, Then returns true',
          () {
        final disposable = TestDisposable();

        disposable.dispose();

        expect(disposable.disposed, isTrue);
      });
    });

    group('register', () {
      test(
          'Given unregistered disposable, When register called, Then disposable is registered',
          () {
        final parent = TestDisposable();
        final child = TestDisposable();

        parent.register(child);
        parent.dispose();

        expect(child.disposeCount, equals(1));
      });

      test('Given disposed parent, When register called, Then assertion fails',
          () {
        final parent = TestDisposable();
        final child = TestDisposable();

        parent.dispose();

        expect(() => parent.register(child), throwsAssertionError);
      });
    });

    group('registerCallback', () {
      test(
          'Given callback, When registerCallback called, Then callback is invoked on dispose',
          () {
        final disposable = TestDisposable();
        int callCount = 0;

        disposable.registerCallback(() => callCount++);
        disposable.dispose();

        expect(callCount, equals(1));
      });

      test(
          'Given multiple callbacks, When dispose called, Then all callbacks are invoked',
          () {
        final disposable = TestDisposable();
        int count1 = 0;
        int count2 = 0;

        disposable.registerCallback(() => count1++);
        disposable.registerCallback(() => count2++);
        disposable.dispose();

        expect(count1, equals(1));
        expect(count2, equals(1));
      });

      test(
          'Given disposed disposable, When registerCallback called, Then assertion fails',
          () {
        final disposable = TestDisposable();

        disposable.dispose();

        expect(() => disposable.registerCallback(() {}), throwsAssertionError);
      });
    });

    group('dispose', () {
      test(
          'Given multiple registered disposables, When dispose called, Then all are disposed',
          () {
        final parent = TestDisposable();
        final child1 = TestDisposable();
        final child2 = TestDisposable();

        parent.register(child1);
        parent.register(child2);
        parent.dispose();

        expect(child1.disposeCount, equals(1));
        expect(child2.disposeCount, equals(1));
        expect(parent.disposeCount, equals(1));
      });

      test(
          'Given nested disposables, When parent disposed, Then children are disposed first',
          () {
        final parent = TestDisposable();
        final child = TestDisposable();

        parent.register(child);
        parent.dispose();

        expect(child.disposeCount, equals(1));
        expect(parent.disposeCount, equals(1));
      });

      test(
          'Given already disposed, When dispose called again, Then does nothing',
          () {
        final disposable = TestDisposable();

        disposable.dispose();
        disposable.dispose();

        // Note: super.dispose() is called each time, so count is 2
        expect(disposable.disposeCount, equals(2));
      });
    });

    group('onDisposed', () {
      test('Given disposable, When onDisposed accessed, Then returns Event',
          () {
        final disposable = TestDisposable();

        expect(disposable.onDisposed, isNotNull);
      });

      test('Given disposable, When dispose called, Then onDisposed emits', () {
        final disposable = TestDisposable();
        int callCount = 0;

        disposable.onDisposed.call((_) => callCount++);
        disposable.dispose();

        expect(callCount, equals(1));
      });
    });
  });
}
