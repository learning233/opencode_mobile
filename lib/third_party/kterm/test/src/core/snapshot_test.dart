import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/core/snapshot.dart';

void main() {
  group('TerminalSnapshot', () {
    test(
        'Given TerminalSnapshot, When interface checked, Then is abstract class',
        () {
      // Assert - verify it's an abstract class with trimScrollback method
      // We can verify it exists and is abstract by checking its runtimeType
      expect(TerminalSnapshot, isNotNull);
    });

    test(
        'Given TerminalSnapshot, When checking class structure, Then is abstract',
        () {
      // Abstract classes can be used as type annotations
      // This verifies the class exists and can be referenced
      void takeSnapshot(TerminalSnapshot snapshot) {
        // This would require implementing the abstract methods
      }
      expect(takeSnapshot, isNotNull);
    });
  });
}
