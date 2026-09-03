import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes.dart';
import '../utils/translations.dart';
import 'right_drawer/widgets/right_drawer_bottom_bar.dart';
import 'right_drawer/widgets/right_drawer_header.dart';
import 'right_drawer/widgets/right_drawer_session_list.dart';

/// page 根目录右抽屉结构文件：定义右侧会话抽屉的整体布局骨架，
/// 具体 UI 元素放入对应文件夹中（如 lib/pages/right_drawer/）。
class RightDrawer extends StatelessWidget {
  const RightDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 1. 顶部 Header（标题与清除操作）
            const RightDrawerHeader(),
            // 2. 打开的会话列表区
            const Expanded(child: RightDrawerSessionList(isDrawer: true)),
            const Divider(height: 1),
            // 3. 查看全部会话入口
            ListTile(
              title: Text(
                LocaleKeys.mobileAllSessions.tr,
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.pop(context);
                Get.toNamed(AppRoutes.sessionList);
              },
            ),
            const Divider(height: 1),
            // 4. 底部快捷工具栏（显示设置、关键词唤醒、快捷短语、视觉模型）
            const RightDrawerBottomBar(isDrawer: true),
          ],
        ),
      ),
    );
  }
}
