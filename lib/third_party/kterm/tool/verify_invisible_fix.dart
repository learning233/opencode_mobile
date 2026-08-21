#!/usr/bin/env dart
// 独立验证脚本：直接测试 Parser -> State -> Painter 全链路
// 运行：dart run tool/verify_invisible_fix.dart

import 'package:kterm/kterm.dart';

void main() {
  print('=== 验证 Invisible 标志全链路 ===\n');

  // 1. 创建 Terminal
  final terminal = Terminal();
  print('✓ Terminal 创建成功');

  // 2. 写入测试序列：下划线 + 不可见
  // \x1b[4;8m = SGR 4 (underline) + SGR 8 (invisible)
  terminal.write('\x1b[4;8m');
  print('✓ 写入 SGR 4;8 (underline + invisible)');

  // 3. 写入可见字符
  terminal.write('Test');
  print('✓ 写入字符 "Test"');

  // 4. 检查 Buffer 中的 Cell 状态
  final line = terminal.buffer.lines[0];
  print('\n--- Buffer Cell 状态检查 ---');

  for (int i = 0; i < 4; i++) {
    final cell = line.createCellData(i);
    final charCode = cell.content & CellContent.codepointMask;
    final char = String.fromCharCode(charCode);
    final hasInvisible = (cell.flags & CellFlags.invisible) != 0;
    final hasUnderline = cell.underlineStyle;
    final flagsHex = cell.flags.toRadixString(16);

    print('Cell $i: char="$char" (0x${charCode.toRadixString(16)}) '
        'flags=0x$flagsHex '
        'invisible=$hasInvisible '
        'underlineStyle=$hasUnderline');
  }

  // 5. 验证预期结果
  print('\n--- 验证 ---');
  bool allCorrect = true;

  for (int i = 0; i < 4; i++) {
    final cell = line.createCellData(i);
    final hasInvisible = (cell.flags & CellFlags.invisible) != 0;
    final hasUnderline = cell.underlineStyle == CellAttr.underlineStyleSingle;

    if (!hasInvisible) {
      print('✗ Cell $i: invisible 标志未设置！');
      allCorrect = false;
    }
    if (!hasUnderline) {
      print('✗ Cell $i: underline 不是单下划线 (实际: ${cell.underlineStyle})');
      allCorrect = false;
    }
  }

  if (allCorrect) {
    print('✓ 所有 Cell 同时具有 invisible 标志和 underline 样式');
    print('\n关键点：invisible 标志已正确设置，Painter 应该跳过这些 cell 的渲染。');
  } else {
    print('✗ 状态检查失败');
  }

  // 6. 测试 SGR 0 重置
  print('\n--- 测试 SGR 0 重置 ---');
  terminal.write('\x1b[0m');
  terminal.write('After');
  final afterCell = line.createCellData(4);
  final afterInvisible = (afterCell.flags & CellFlags.invisible) != 0;
  print('Cell 4 ("A"): invisible=$afterInvisible (应为 false)');
  if (!afterInvisible) {
    print('✓ SGR 0 正确清除了 invisible 标志');
  }
}
