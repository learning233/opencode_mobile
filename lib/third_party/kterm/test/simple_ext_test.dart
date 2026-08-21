import 'package:test/test.dart';
import 'package:kterm/kterm.dart';

void main() {
  test('dump works', () {
    expect([1, 2, 3].dump(), '01 02 03');
  });
}
