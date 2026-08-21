import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../init.dart';
import '../utils/card_visibility.dart';
import '../utils/translations.dart';

/// Bottom sheet for chat display preferences (font scale, density, card visibility).
class DisplaySettingsSheet extends StatelessWidget {
  const DisplaySettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const DisplaySettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Obx(() {
            // Touch reactive getters so Obx rebuilds when Global display prefs change.
            final fontScale = Global.fontScaleRx.value;
            final density = Global.messageDensityRx.value;
            final _ = Map<String, bool>.from(Global.cardVisibilityRx);

            return ListView(
              shrinkWrap: true,
              children: [
                Text(
                  LocaleKeys.mobileDisplay.tr,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  LocaleKeys.edFontSize.tr,
                  style: theme.textTheme.labelLarge,
                ),
                Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: fontScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        label: '${(fontScale * 100).round()}%',
                        onChanged: (v) => Global.fontScaleRx.value = v,
                        onChangeEnd: (v) => Global.fontScale = v,
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  LocaleKeys.mobileMessageDensity.tr,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'compact',
                      label: Text(LocaleKeys.mobileCompact.tr),
                    ),
                    ButtonSegment(
                      value: 'comfortable',
                      label: Text(LocaleKeys.mobileComfortable.tr),
                    ),
                    ButtonSegment(
                      value: 'spacious',
                      label: Text(LocaleKeys.mobileSpacious.tr),
                    ),
                  ],
                  selected: {density},
                  onSelectionChanged: (s) {
                    if (s.isNotEmpty) Global.messageDensity = s.first;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  LocaleKeys.inputPanelsSection.tr,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(LocaleKeys.inputPanelTodo.tr),
                  value: Global.isCardVisible('input_todo'),
                  onChanged: (v) => Global.setCardVisible('input_todo', v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(LocaleKeys.inputPanelDiff.tr),
                  value: Global.isCardVisible('input_session_diff'),
                  onChanged: (v) =>
                      Global.setCardVisible('input_session_diff', v),
                ),
                const SizedBox(height: 16),
                Text(
                  LocaleKeys.mobileCardVisibility.tr,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                for (final key in CardVisibilityKeys.all)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(CardVisibilityKeys.labelFor(key)),
                    value: Global.isCardVisible(key),
                    onChanged: (v) => Global.setCardVisible(key, v),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
