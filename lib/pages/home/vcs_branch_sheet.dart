import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../api/models/vcs_info.dart';
import '../../controllers/project_controller.dart';
import '../../controllers/tablet_tool_controller.dart';
import '../../controllers/vcs_controller.dart';
import '../../routes.dart';
import '../../utils/layout_utils.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/translations.dart';
import '../tablet/review_page.dart';

/// BottomSheet widget displaying VCS branch details and workspace status files.
class VcsBranchSheet extends StatefulWidget {
  const VcsBranchSheet({super.key});

  @override
  State<VcsBranchSheet> createState() => _VcsBranchSheetState();
}

class _VcsBranchSheetState extends State<VcsBranchSheet> {
  VcsController get _vcsCtrl => Get.find<VcsController>();

  @override
  void initState() {
    super.initState();
    _vcsCtrl.refreshAll();
  }

  void _openChangedFile(String path) {
    if (path.isEmpty) return;
    final fileName = path.contains('/')
        ? path.split('/').last
        : (path.contains('\\') ? path.split('\\').last : path);
    final activeProject = Get.find<ProjectController>().activeProject.value;
    final worktree = activeProject?.worktree;

    final toolCtrl = Get.find<TabletToolController>();
    toolCtrl.openFile(path, fileName, worktree: worktree);

    final isTablet = isTabletLayout(context);
    Navigator.of(context).pop();

    if (!isTablet) {
      if (Get.currentRoute != AppRoutes.fileList) {
        Get.toNamed(AppRoutes.fileList);
      }
    }
  }

  void _openFullReview() {
    final toolCtrl = Get.find<TabletToolController>();
    toolCtrl.setReviewAll();
    toolCtrl.activeTabIndex.value = TabletToolController.tabReview;
    if (!toolCtrl.isVisible.value) toolCtrl.isVisible.value = true;

    final isTablet = isTabletLayout(context);
    Navigator.of(context).pop();

    if (!isTablet) {
      Get.to(
        () => Scaffold(
          appBar: AppBar(title: Text(LocaleKeys.csTabReview.tr)),
          body: const ReviewPage(),
        ),
      );
    }
  }

  Widget _buildStatusBadge(ThemeData theme, VcsStatusFile file) {
    Color bg;
    Color fg;
    String label;

    if (file.isAdded) {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.green.shade700;
      label = 'A';
    } else if (file.isDeleted) {
      bg = Colors.red.withValues(alpha: 0.15);
      fg = Colors.red.shade700;
      label = 'D';
    } else {
      bg = Colors.amber.withValues(alpha: 0.18);
      fg = Colors.orange.shade800;
      label = 'M';
    }

    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Bar: Title & Actions ──
            Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_branch,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Obx(() {
                    final branch = _vcsCtrl.branch.value;
                    final isDefault =
                        branch.isNotEmpty &&
                        branch == _vcsCtrl.defaultBranch.value;

                    if (branch.isEmpty) {
                      return Text(
                        LocaleKeys.vcsBranch.tr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }

                    return Row(
                      children: [
                        Flexible(
                          child: InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: branch));
                              Snack.success(
                                '${LocaleKeys.vcsBranchCopied.tr}: $branch',
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                branch,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              LocaleKeys.vcsDefault.tr,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ),
                // Review Diff Button
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  icon: const Icon(Icons.difference_outlined, size: 15),
                  label: Text(
                    LocaleKeys.vcsViewDiff.tr,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _openFullReview,
                ),
                const SizedBox(width: 4),
                // Refresh Button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: LocaleKeys.retry.tr,
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  onPressed: () => _vcsCtrl.refreshAll(force: true),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Metrics Bar ──
            Obx(() {
              final files = _vcsCtrl.statusFiles;
              if (files.isEmpty) return const SizedBox.shrink();

              final modCount = _vcsCtrl.modifiedCount;
              final addCount = _vcsCtrl.addedCount;
              final delCount = _vcsCtrl.deletedCount;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          LocaleKeys.vcsChangedFiles.trParams({
                            'count': files.length.toString(),
                          }),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (modCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$modCount ${LocaleKeys.vcsModified.tr}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                      if (addCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$addCount ${LocaleKeys.vcsAdded.tr}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                      if (delCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$delCount ${LocaleKeys.vcsDeleted.tr}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            // ── Divider / Loading Progress Bar ──
            Obx(() {
              final isLoading = _vcsCtrl.isLoading.value;
              return SizedBox(
                height: 2,
                child: isLoading
                    ? LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: theme.dividerColor.withValues(
                          alpha: 0.15,
                        ),
                        color: theme.colorScheme.primary,
                      )
                    : Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.25),
                      ),
              );
            }),

            // ── Changed Files List / Empty / Error ──
            Expanded(
              child: Obx(() {
                if (_vcsCtrl.error.value != null &&
                    _vcsCtrl.statusFiles.isEmpty &&
                    !_vcsCtrl.isLoading.value) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 32,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _vcsCtrl.branch.value.isEmpty
                                ? LocaleKeys.vcsNotGitRepo.tr
                                : _vcsCtrl.error.value!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => _vcsCtrl.refreshAll(force: true),
                            child: Text(LocaleKeys.retry.tr),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final files = _vcsCtrl.statusFiles;
                if (files.isEmpty) {
                  if (_vcsCtrl.isLoading.value) {
                    return const SizedBox.shrink();
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 40,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            LocaleKeys.vcsClean.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: files.length,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final file = files[idx];
                    final rawPath = file.file;
                    final fileName = rawPath.contains('/')
                        ? rawPath.split('/').last
                        : (rawPath.contains('\\')
                              ? rawPath.split('\\').last
                              : rawPath);
                    final dirPath = rawPath.contains('/')
                        ? rawPath.substring(0, rawPath.lastIndexOf('/'))
                        : (rawPath.contains('\\')
                              ? rawPath.substring(0, rawPath.lastIndexOf('\\'))
                              : '');

                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      leading: _buildStatusBadge(theme, file),
                      title: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: file.isDeleted
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                )
                              : theme.colorScheme.onSurface,
                          decoration: file.isDeleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: dirPath.isNotEmpty
                          ? Text(
                              dirPath,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (file.additions > 0)
                            Text(
                              '+${file.additions}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          if (file.additions > 0 && file.deletions > 0)
                            const SizedBox(width: 4),
                          if (file.deletions > 0)
                            Text(
                              '-${file.deletions}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      onTap: file.isDeleted
                          ? null
                          : () => _openChangedFile(rawPath),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
