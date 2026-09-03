import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/cloud_workspace_config.dart';
import '../../utils/translations.dart';
import '../../utils/url_utils.dart';

/// E2B 云端沙盒模式视图（未配 Key / 活跃沙盒恢复 / 无活跃沙盒三态）。
class SplashCloudView extends StatelessWidget {
  const SplashCloudView({
    super.key,
    required this.config,
    required this.isBusy,
    this.cloudHint,
    this.errorText,
    required this.cloudStepMessage,
    required this.onConfigApiKey,
    required this.onNewSandbox,
    required this.onSelectSandbox,
    required this.onConnectCloud,
  });

  final CloudWorkspaceConfig config;
  final bool isBusy;
  final String? cloudHint;
  final String? errorText;
  final String cloudStepMessage;
  final VoidCallback onConfigApiKey;
  final VoidCallback onNewSandbox;
  final VoidCallback onSelectSandbox;
  final VoidCallback onConnectCloud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = config.e2bApiKey.trim().isNotEmpty;

    // 状态 1: 未配置 Key
    if (!hasKey) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.vpn_key_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      LocaleKeys.e2bNoApiKey.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                LocaleKeys.e2bNoApiKeyDesc.tr,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onConfigApiKey,
                icon: const Icon(Icons.vpn_key_outlined, size: 18),
                label: Text(LocaleKeys.e2bConfigApiKey.tr),
              ),
            ],
          ),
        ),
      );
    }

    // 状态 2: 有活跃沙盒 (可一键唤醒连接 / 新建 / 管理)
    if (config.hasActiveSandbox) {
      final sandboxId = config.activeSandboxId!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_outlined,
                              color: theme.colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sandboxId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (config.activeSandboxUrl != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            maskUrl(config.activeSandboxUrl!),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        iconSize: 20,
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: LocaleKeys.e2bNewSandbox.tr,
                        onPressed: isBusy ? null : onNewSandbox,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        iconSize: 20,
                        icon: const Icon(Icons.list_alt),
                        tooltip: LocaleKeys.e2bSandboxList.tr,
                        onPressed: isBusy ? null : onSelectSandbox,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (cloudHint != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.7,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cloudHint!,
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorText!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isBusy) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cloudStepMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isBusy ? null : onConnectCloud,
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bolt, size: 18),
            label: Text(
              cloudHint != null
                  ? LocaleKeys.e2bWakeAndConnect.tr
                  : LocaleKeys.e2bConnectLastSandbox.tr,
            ),
          ),
        ],
      );
    }

    // 状态 3: 无活跃沙箱 (但已配 Key)
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LocaleKeys.e2bTitle.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isBusy ? null : onNewSandbox,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(LocaleKeys.e2bNewSandbox.tr),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: isBusy ? null : onSelectSandbox,
              icon: const Icon(Icons.list_alt, size: 16),
              label: Text(LocaleKeys.e2bSelectSandbox.tr),
            ),
          ],
        ),
      ),
    );
  }
}
