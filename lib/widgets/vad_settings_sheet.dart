import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../init.dart';
import '../utils/translations.dart';

/// Bottom sheet for configuring VAD (Voice Activity Detection) settings.
class VadSettingsSheet extends StatefulWidget {
  const VadSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const VadSettingsSheet(),
    );
  }

  @override
  State<VadSettingsSheet> createState() => _VadSettingsSheetState();
}

class _VadSettingsSheetState extends State<VadSettingsSheet> {
  late final TextEditingController _commandCtrl;

  @override
  void initState() {
    super.initState();
    _commandCtrl = TextEditingController(text: Global.voiceSendCommandRx.value);
  }

  @override
  void dispose() {
    _commandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Obx(() {
            final threshold = Global.vadThresholdRx.value;
            final minSilence = Global.vadMinSilenceDurationRx.value;
            final minSpeech = Global.vadMinSpeechDurationRx.value;
            final maxSpeech = Global.vadMaxSpeechDurationRx.value;
            final speechPad = Global.vadSpeechPadMsRx.value;

            return ListView(
              shrinkWrap: true,
              children: [
                // ── 连续语音输入 ──
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    LocaleKeys.voiceContinuousInput.tr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    LocaleKeys.voiceContinuousInputDesc.tr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  value: Global.continuousVoiceInputRx.value,
                  onChanged: (v) => Global.continuousVoiceInput = v,
                ),

                // ── 自动发送 ──
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    LocaleKeys.voiceAutoSend.tr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    LocaleKeys.voiceAutoSendDesc.tr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  value: Global.autoSendVoiceEnabledRx.value,
                  onChanged: (v) => Global.autoSendVoiceEnabled = v,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.voiceSendCommand.tr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _commandCtrl,
                        onChanged: (v) => Global.voiceSendCommand = v,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: LocaleKeys.voiceSendCommandHint.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.waveform,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          LocaleKeys.vadSettingsTitle.tr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => Global.resetVadSettings(),
                      icon: const Icon(CupertinoIcons.refresh, size: 16),
                      label: Text(
                        LocaleKeys.vadResetDefault.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // ── VAD Config ──
                Text(
                  LocaleKeys.voiceVadParams.tr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Threshold
                _buildSliderTile(
                  context: context,
                  title: LocaleKeys.vadThreshold.tr,
                  subtitle: LocaleKeys.vadThresholdDesc.tr,
                  valueText: threshold.toStringAsFixed(2),
                  child: Slider(
                    value: threshold,
                    min: 0.1,
                    max: 0.9,
                    divisions: 16,
                    label: threshold.toStringAsFixed(2),
                    onChanged: (v) => Global.vadThreshold = double.parse(
                      v.toStringAsFixed(2),
                    ),
                  ),
                ),

                // 2. Min silence duration
                _buildSliderTile(
                  context: context,
                  title: LocaleKeys.vadMinSilenceDuration.tr,
                  subtitle: LocaleKeys.vadMinSilenceDesc.tr,
                  valueText: '${minSilence.toStringAsFixed(1)}s',
                  child: Slider(
                    value: minSilence,
                    min: 0.1,
                    max: 3.0,
                    divisions: 29,
                    label: '${minSilence.toStringAsFixed(1)}s',
                    onChanged: (v) => Global.vadMinSilenceDuration =
                        double.parse(v.toStringAsFixed(1)),
                  ),
                ),

                // 3. Min speech duration
                _buildSliderTile(
                  context: context,
                  title: LocaleKeys.vadMinSpeechDuration.tr,
                  subtitle: LocaleKeys.vadMinSpeechDesc.tr,
                  valueText: '${minSpeech.toStringAsFixed(2)}s',
                  child: Slider(
                    value: minSpeech,
                    min: 0.05,
                    max: 2.0,
                    divisions: 39,
                    label: '${minSpeech.toStringAsFixed(2)}s',
                    onChanged: (v) => Global.vadMinSpeechDuration =
                        double.parse(v.toStringAsFixed(2)),
                  ),
                ),

                // 4. Max speech duration
                _buildSliderTile(
                  context: context,
                  title: LocaleKeys.vadMaxSpeechDuration.tr,
                  subtitle: LocaleKeys.vadMaxSpeechDesc.tr,
                  valueText: '${maxSpeech.toStringAsFixed(0)}s',
                  child: Slider(
                    value: maxSpeech,
                    min: 2.0,
                    max: 30.0,
                    divisions: 28,
                    label: '${maxSpeech.toStringAsFixed(0)}s',
                    onChanged: (v) => Global.vadMaxSpeechDuration =
                        double.parse(v.toStringAsFixed(0)),
                  ),
                ),

                // 5. Speech pad ms
                _buildSliderTile(
                  context: context,
                  title: LocaleKeys.vadSpeechPadMs.tr,
                  subtitle: LocaleKeys.vadSpeechPadDesc.tr,
                  valueText: '${speechPad}ms',
                  child: Slider(
                    value: speechPad.toDouble(),
                    min: 0,
                    max: 1000,
                    divisions: 20,
                    label: '${speechPad}ms',
                    onChanged: (v) => Global.vadSpeechPadMs = v.round(),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String valueText,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Row(children: [Expanded(child: child)]),
        ],
      ),
    );
  }
}
