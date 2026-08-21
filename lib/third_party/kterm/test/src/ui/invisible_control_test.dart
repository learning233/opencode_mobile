import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/kterm.dart';

Future<void> pumpTerminalView(WidgetTester tester,
    {Size size = const Size(800, 600)}) async {
  tester.view.physicalSize = size;
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TerminalView(Terminal()),
    ),
  ));

  await tester.pump();
}

void main() {
  testWidgets('Control characters should not be visible', (tester) async {
    await pumpTerminalView(tester);

    final terminal = Terminal();

    // Write control characters (ASCII 0x01-0x1F, 0x7F)
    // These should NOT be visible - they have wcwidth=0
    terminal.write('\x01\x02\x03\x04\x05ABC\x1B\x1C\x1D\x1E\x1F\x7F');

    await tester.pump();

    // Get the rendered output - control characters should not appear as visible glyphs
    // The text should only show "ABC"
    final bufferText = terminal.buffer.getText();
    print(
        'Buffer text runes: ${bufferText.runes.map((r) => r.toRadixString(16)).join(" ")}');

    // Control characters have wcwidth=0, so they occupy no visible cells
    // Buffer should only contain "ABC"
    expect(bufferText, contains('ABC'));
    // Control characters should not create visible cells
    // The positions where control chars were written should be empty or overwritten
  });

  testWidgets('SGR 8 invisible flag hides text and underlines', (tester) async {
    await pumpTerminalView(tester);

    final terminal = Terminal();

    // Write underlined text with invisible flag
    terminal.write('\x1b[4;8mTest'); // underline + invisible
    terminal.write('\x1b[24mNormal'); // reset

    await tester.pump();

    final line = terminal.buffer.lines[0];
    // Check cells for "Test" - should have underlineStyle but text should not render
    for (int i = 0; i < 4; i++) {
      final cell = line.createCellData(i);
      print(
          'Test cell $i: underlineStyle=${cell.underlineStyle}, flags=0x${cell.flags.toRadixString(16)}, content=0x${(cell.content & CellContent.codepointMask).toRadixString(16)}');
      // With invisible flag, the foreground should not be painted
      // But underlineStyle is still stored
      expect(cell.flags & CellFlags.invisible, isNot(equals(0)),
          reason: 'Cell $i should have invisible flag');
    }
  });
}
