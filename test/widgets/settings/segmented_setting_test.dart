import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_app/pages/settings/widgets/segmented_setting.dart';

void main() {
  testWidgets('SegmentedSetting calls onChanged', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SegmentedSetting(
            title: 'Sound',
            desc: 'Notify',
            value: 'none',
            options: const ['none', 'dang'],
            labels: const ['No', 'Dang'],
            onChanged: (v) => selected = v,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dang'));
    await tester.pumpAndSettle();
    expect(selected, 'dang');
  });
}
