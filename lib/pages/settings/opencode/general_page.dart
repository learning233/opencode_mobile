import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/settings_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/translations.dart';
import '../widgets/settings.dart';

class OpencodeGeneralPage extends StatefulWidget {
  const OpencodeGeneralPage({super.key});

  @override
  State<OpencodeGeneralPage> createState() => _OpencodeGeneralPageState();
}

class _OpencodeGeneralPageState extends State<OpencodeGeneralPage> {
  final _usernameCtrl = TextEditingController();
  bool _usernameDirty = false;

  SettingsController get _settings => Get.find<SettingsController>();

  static const _fallbackShells = ['bash', 'zsh', 'fish', 'powershell', 'cmd'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _settings.fetchGlobalConfig(),
        _settings.fetchShells(),
      ]);
      if (mounted) _syncUsernameField();
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _syncUsernameField() {
    if (_usernameDirty || _usernameCtrl.text.isNotEmpty) return;
    _usernameCtrl.text = _settings.username ?? '';
  }

  /// 统一保存反馈：控制器不再抛异常，只以返回值表达成败；失败提示（成功静默）。
  Future<void> _applyPatch(Future<bool> op) async {
    final ok = await op;
    if (!ok) Snack.error(LocaleKeys.saveFailed.tr);
  }

  Future<void> _saveUsername() async {
    final value = _usernameCtrl.text.trim();
    final ok = await _settings.setUsername(value);
    if (ok) {
      _usernameDirty = false;
    } else {
      Snack.error(LocaleKeys.generalSaveUsernameFailed.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.tabGeneral.tr,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(title: LocaleKeys.secNotifications.tr),
          SettingsCard(
            children: [
              Obx(
                () => SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  dense: true,
                  title: Text(LocaleKeys.notificationSound.tr),
                  subtitle: Text(LocaleKeys.notificationSoundDesc.tr),
                  value: _settings.notificationEnabled.value,
                  onChanged: (v) => _settings.setNotificationEnabled(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(title: LocaleKeys.secShell.tr),
          SettingsCard(
            children: [
              Obx(() {
                final shells = _settings.availableShells.isNotEmpty
                    ? _settings.availableShells
                    : _fallbackShells;
                return DropdownSetting(
                  title: LocaleKeys.defaultShell.tr,
                  desc: LocaleKeys.defaultShellDesc.tr,
                  value: _settings.shell ?? '',
                  items: shells,
                  isLoading: _settings.isLoadingShells.value,
                  onChanged: (v) => _applyPatch(_settings.setShell(v)),
                  display: (v) =>
                      v.isEmpty ? LocaleKeys.default_.tr : v.split('/').last,
                );
              }),
              Obx(() {
                _settings.globalConfig.value;
                return SegmentedSetting(
                  title: LocaleKeys.logLevel.tr,
                  desc: LocaleKeys.logLevelDesc.tr,
                  value: _settings.logLevel ?? 'INFO',
                  options: SettingsController.logLevels,
                  labels: const ['Debug', 'Info', 'Warn', 'Error'],
                  onChanged: (v) => _applyPatch(_settings.setLogLevel(v)),
                );
              }),
              SettingsRow(
                title: LocaleKeys.username.tr,
                desc: LocaleKeys.usernameDesc.tr,
                child: SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _usernameCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: LocaleKeys.usernamePlaceholder.tr,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onChanged: (_) => _usernameDirty = true,
                    onSubmitted: (_) => _saveUsername(),
                    onEditingComplete: _saveUsername,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(title: LocaleKeys.secSharing.tr),
          SettingsCard(
            children: [
              Obx(() {
                _settings.globalConfig.value;
                return SegmentedSetting(
                  title: LocaleKeys.sharingMode.tr,
                  desc: LocaleKeys.sharingModeDesc.tr,
                  value: _settings.shareMode ?? 'manual',
                  options: SettingsController.shareModes,
                  labels: const ['Manual', 'Auto', 'Disabled'],
                  onChanged: (v) => _applyPatch(_settings.setShareMode(v)),
                );
              }),
              Obx(() {
                _settings.globalConfig.value;
                final autoupdate = _settings.autoupdate;
                final value = autoupdate == true
                    ? 'auto'
                    : autoupdate == 'notify'
                    ? 'notify'
                    : 'off';
                return SegmentedSetting(
                  title: LocaleKeys.autoUpdate.tr,
                  desc: LocaleKeys.autoUpdateDesc.tr,
                  value: value,
                  options: const ['auto', 'notify', 'off'],
                  labels: const ['Auto', 'Notify', 'Off'],
                  onChanged: (v) => _applyPatch(
                    _settings.setAutoupdate(
                      v == 'auto' ? true : (v == 'notify' ? 'notify' : false),
                    ),
                  ),
                );
              }),
              Obx(() {
                _settings.globalConfig.value;
                return SettingsRow(
                  title: LocaleKeys.snapshotTracking.tr,
                  desc: LocaleKeys.snapshotTrackingDesc.tr,
                  child: Switch(
                    value: _settings.snapshot ?? true,
                    onChanged: (v) => _applyPatch(_settings.setSnapshot(v)),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(title: LocaleKeys.secCompaction.tr),
          SettingsCard(
            children: [
              Obx(() {
                final compaction = _settings.compaction;
                return SettingsRow(
                  title: LocaleKeys.autoCompaction.tr,
                  desc: LocaleKeys.autoCompactionDesc.tr,
                  child: Switch(
                    value: compaction?['auto'] as bool? ?? true,
                    onChanged: (v) {
                      final c = Map<String, dynamic>.from(compaction ?? {});
                      c['auto'] = v;
                      _applyPatch(_settings.setCompaction(c));
                    },
                  ),
                );
              }),
              Obx(() {
                final compaction = _settings.compaction;
                return SettingsRow(
                  title: LocaleKeys.pruneOldOutputs.tr,
                  desc: LocaleKeys.pruneOldOutputsDesc.tr,
                  child: Switch(
                    value: compaction?['prune'] as bool? ?? false,
                    onChanged: (v) {
                      final c = Map<String, dynamic>.from(compaction ?? {});
                      c['prune'] = v;
                      _applyPatch(_settings.setCompaction(c));
                    },
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
