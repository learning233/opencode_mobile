import 'package:flutter/material.dart';
import 'left_drawer/left_panel_content.dart';

class LeftDrawer extends StatelessWidget {
  final DrawerMode? initialMode;

  const LeftDrawer({super.key, this.initialMode});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: LeftPanelContent(isDrawer: true, initialMode: initialMode),
    );
  }
}
