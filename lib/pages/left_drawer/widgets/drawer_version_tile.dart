import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes.dart';

/// 左抽屉底部版本号展示条目。
class DrawerVersionTile extends StatelessWidget {
  const DrawerVersionTile({
    super.key,
    required this.appVersion,
    this.isDrawer = true,
  });

  final String appVersion;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        InkWell(
          onTap: () {
            if (isDrawer) Navigator.pop(context);
            Get.toNamed(AppRoutes.about);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              appVersion,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
