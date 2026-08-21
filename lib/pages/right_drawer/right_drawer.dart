import 'package:flutter/material.dart';
import 'right_panel_content.dart';

class RightDrawer extends StatelessWidget {
  const RightDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(child: RightPanelContent(isDrawer: true));
  }
}
