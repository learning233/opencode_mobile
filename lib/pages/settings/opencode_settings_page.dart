import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes.dart';
import '../../utils/translations.dart';

class OpenCodeSettingsPage extends StatelessWidget {
  const OpenCodeSettingsPage({super.key});

  static final _tiles = [
    _HubTile(
      LocaleKeys.tabConnection,
      Icons.link,
      AppRoutes.opencodeConnection,
    ),
    _HubTile(LocaleKeys.tabGeneral, Icons.tune, AppRoutes.opencodeGeneral),
    _HubTile(LocaleKeys.tabProviders, Icons.login, AppRoutes.opencodeProviders),
    _HubTile(
      LocaleKeys.tabModels,
      Icons.smart_toy_outlined,
      AppRoutes.opencodeModels,
    ),
    _HubTile(
      LocaleKeys.tabMcp,
      Icons.extension_outlined,
      AppRoutes.opencodeMcp,
    ),
    _HubTile(LocaleKeys.tabLsp, Icons.code, AppRoutes.opencodeLsp),
    _HubTile(
      LocaleKeys.tabSkills,
      Icons.psychology_outlined,
      AppRoutes.opencodeSkills,
    ),
    _HubTile(
      LocaleKeys.tabRules,
      Icons.rule_folder_outlined,
      AppRoutes.opencodeRules,
    ),
    _HubTile(
      LocaleKeys.tabAgent,
      Icons.support_agent_outlined,
      AppRoutes.opencodeAgent,
    ),
    _HubTile(
      LocaleKeys.tabPermissions,
      Icons.security_outlined,
      AppRoutes.opencodePermissions,
    ),
    _HubTile(
      LocaleKeys.tabDeveloper,
      Icons.terminal,
      AppRoutes.opencodeDeveloper,
    ),
    _HubTile(
      LocaleKeys.tabAdvanced,
      Icons.settings_outlined,
      AppRoutes.opencodeAdvanced,
    ),
    _HubTile(
      LocaleKeys.tabExperimental,
      Icons.science_outlined,
      AppRoutes.opencodeExperimental,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.opencodeSettingsTitle.tr,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: ListView(
        children: [
          for (final tile in _tiles)
            ListTile(
              leading: Icon(tile.icon, size: 20),
              title: Text(
                tile.titleKey.tr,
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Get.toNamed(tile.route),
            ),
        ],
      ),
    );
  }
}

class _HubTile {
  final String titleKey;
  final IconData icon;
  final String route;

  const _HubTile(this.titleKey, this.icon, this.route);
}
