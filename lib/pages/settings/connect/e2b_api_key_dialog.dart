import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../init.dart';
import '../../../utils/translations.dart';

/// 轻量级 E2B API Key 输入对话框。
///
/// 仅包含一个 TextField 和保存按钮，用于账户级 API Key 的首次配置或修改。
/// 返回 `true` 表示用户已保存（Key 可能为空——清除场景）。
class E2bApiKeyDialog extends StatefulWidget {
  const E2bApiKeyDialog({super.key});

  /// 弹出 API Key 输入对话框，返回是否保存成功。
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => const E2bApiKeyDialog(),
    );
  }

  @override
  State<E2bApiKeyDialog> createState() => _E2bApiKeyDialogState();
}

class _E2bApiKeyDialogState extends State<E2bApiKeyDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: Global.settings.cloudWorkspaceConfig.e2bApiKey,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    await Global.settings.updateCloudWorkspaceConfig(
      (curr) => curr.copyWith(e2bApiKey: key),
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.vpn_key_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            LocaleKeys.e2bApiKey.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.e2bApiKeyHint.tr,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.text,
            enableSuggestions: true,
            autocorrect: false,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'API Key',
              hintText: 'e2b_sk_...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => _ctrl.clear(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(LocaleKeys.cancel.tr),
        ),
        FilledButton(onPressed: _save, child: Text(LocaleKeys.save.tr)),
      ],
    );
  }
}
