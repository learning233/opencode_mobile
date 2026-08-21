import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../init.dart';
import '../../utils/card_visibility.dart';
import '../../utils/translations.dart';

/// Standalone page for chat display preferences (font scale, density, card visibility).
class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.mobileDisplay.tr,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Obx(() {
        // Touch reactive getters so Obx rebuilds when Global display prefs change.
        final fontScale = Global.fontScaleRx.value;
        final density = Global.messageDensityRx.value;
        final _ = Map<String, bool>.from(Global.cardVisibilityRx);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _SectionHeader(title: LocaleKeys.edFontSize.tr),
            const SizedBox(height: 4),
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
            const SizedBox(height: 16),
            _SectionHeader(title: LocaleKeys.mobileMessageDensity.tr),
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
            const Divider(height: 1),
            const SizedBox(height: 12),
            _SectionHeader(title: LocaleKeys.inputPanelsSection.tr),
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
              onChanged: (v) => Global.setCardVisible('input_session_diff', v),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _SectionHeader(title: LocaleKeys.mobileCardVisibility.tr),
                const Spacer(),
                TextButton(
                  onPressed: () => Global.setAllCardVisible(true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    LocaleKeys.mobileShowAll.tr,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => Global.setAllCardVisible(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    LocaleKeys.mobileHideAll.tr,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
              ),
              itemCount: CardVisibilityKeys.all.length,
              itemBuilder: (context, index) {
                final key = CardVisibilityKeys.all[index];
                final isSelected = Global.isCardVisible(key);
                final label = CardVisibilityKeys.labelFor(key);
                final theme = Theme.of(context);

                return InkWell(
                  onTap: () => Global.setCardVisible(key, !isSelected),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.6,
                            )
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
