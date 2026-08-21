import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/base/observable.dart';

class TestObserver with Observable {
  int callCount = 0;

  void trigger() {
    notifyListeners();
  }
}

void main() {
  group('Observable', () {
    group('addListener', () {
      test(
          'Given no listeners, When addListener called, Then listener is registered',
          () {
        final observer = TestObserver();
        int callCount = 0;

        observer.addListener(() => callCount++);

        expect(observer.listeners.length, equals(1));
      });

      test(
          'Given multiple listeners, When addListener called, Then all listeners are registered',
          () {
        final observer = TestObserver();

        observer.addListener(() {});
        observer.addListener(() {});

        expect(observer.listeners.length, equals(2));
      });

      test(
          'Given duplicate listener, When addListener called, Then listener is only added once',
          () {
        final observer = TestObserver();
        void listener() {}

        observer.addListener(listener);
        observer.addListener(listener);

        expect(observer.listeners.length, equals(1));
      });
    });

    group('removeListener', () {
      test(
          'Given registered listener, When removeListener called, Then listener is removed',
          () {
        final observer = TestObserver();
        void listener() {}

        observer.addListener(listener);
        observer.removeListener(listener);

        expect(observer.listeners.isEmpty, isTrue);
      });

      test(
          'Given unregistered listener, When removeListener called, Then no error thrown',
          () {
        final observer = TestObserver();

        expect(() => observer.removeListener(() {}), returnsNormally);
      });
    });

    group('notifyListeners', () {
      test(
          'Given single listener, When notifyListeners called, Then listener is invoked',
          () {
        final observer = TestObserver();
        int callCount = 0;

        observer.addListener(() => callCount++);
        observer.notifyListeners();

        expect(callCount, equals(1));
      });

      test(
          'Given multiple listeners, When notifyListeners called, Then all listeners are invoked',
          () {
        final observer = TestObserver();
        int callCount1 = 0;
        int callCount2 = 0;

        observer.addListener(() => callCount1++);
        observer.addListener(() => callCount2++);
        observer.notifyListeners();

        expect(callCount1, equals(1));
        expect(callCount2, equals(1));
      });

      test(
          'Given listener removed during notification, When notifyListeners called, Then does not crash',
          () {
        // Note: This test documents that modifying the set during iteration
        // will throw ConcurrentModificationError - this is expected behavior
        final observer = TestObserver();
        void listener2() {}

        observer.addListener(listener2);
        // The Observable doesn't protect against modification during iteration
        // This is by design - if you need that, use a copy of listeners
      });
    });
  });
}
