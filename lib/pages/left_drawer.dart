import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../controllers/project_controller.dart';
import 'left_drawer/left_drawer_mode.dart';
import 'left_drawer/left_panel_content.dart';
import 'left_drawer/widgets/drawer_bottom_bar.dart';
import 'left_drawer/widgets/drawer_mode_switcher.dart';
import 'left_drawer/widgets/drawer_version_tile.dart';

/// page 根目录左抽屉结构文件：定义左侧抽屉的整体布局骨架，
/// 具体 UI 元素放入对应文件夹中（如 lib/pages/left_drawer/）。
class LeftDrawer extends StatefulWidget {
  final DrawerMode? initialMode;

  const LeftDrawer({super.key, this.initialMode});

  @override
  State<LeftDrawer> createState() => _LeftDrawerState();
}

class _LeftDrawerState extends State<LeftDrawer> {
  late final Rx<DrawerMode> _drawerMode;
  String _appVersion = 'v0.9.8';

  @override
  void initState() {
    super.initState();
    _drawerMode = (widget.initialMode ?? DrawerMode.projects).obs;
    _loadVersion();
    if (Get.isRegistered<ProjectController>()) {
      Get.find<ProjectController>().fetchSandboxes();
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 1. 内容主体区域（根据模式分发展示项目列表或文件树）
            Expanded(
              child: LeftDrawerBody(drawerMode: _drawerMode, isDrawer: true),
            ),
            // 2. 项目与文件浏览模式切换条
            DrawerModeSwitcher(drawerMode: _drawerMode),
            const Divider(height: 1),
            // 3. 底部设置快捷工具栏（主题切换、语言、语音 VAD、设置主页）
            const DrawerBottomBar(isDrawer: true),
            // 4. 底部版本号展示
            DrawerVersionTile(appVersion: _appVersion, isDrawer: true),
          ],
        ),
      ),
    );
  }
}
