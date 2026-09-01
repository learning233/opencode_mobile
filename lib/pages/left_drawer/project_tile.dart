import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../api/models/project.dart';
import '../../utils/layout_utils.dart';
import '../../utils/translations.dart';

class ProjectTile extends StatelessWidget {
  final ProjectModel project;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onBrowseFiles;

  const ProjectTile({
    super.key,
    required this.project,
    required this.isActive,
    required this.onTap,
    required this.onBrowseFiles,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = isTabletLayout(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(
        project.displayName,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: !isTablet
          ? IconButton(
              icon: const Icon(Icons.folder_open_outlined, size: 20),
              padding: EdgeInsets.zero,
              onPressed: onBrowseFiles,
              tooltip: LocaleKeys.mobileBrowseFiles.tr,
            )
          : null,
      selected: isActive,
      dense: true,
      onTap: onTap,
    );
  }
}
