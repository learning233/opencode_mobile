import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/translations.dart';

/// 自建服务器连接配置表单视图。
class SplashSelfHostedView extends StatelessWidget {
  const SplashSelfHostedView({
    super.key,
    required this.formKey,
    required this.urlController,
    required this.usernameController,
    required this.passwordController,
    required this.isBusy,
    this.errorText,
    required this.onConnect,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController urlController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool isBusy;
  final String? errorText;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: urlController,
            decoration: InputDecoration(
              labelText: LocaleKeys.mobileServerUrl.tr,
              hintText: 'http://192.168.1.100:4096',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(CupertinoIcons.link),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? LocaleKeys.mobileServerUrlRequired.tr
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: usernameController,
            decoration: InputDecoration(
              labelText: LocaleKeys.username.tr,
              hintText: 'opencode',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(CupertinoIcons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: LocaleKeys.mobilePassword.tr,
              hintText: 'your-password-here',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(CupertinoIcons.lock),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorText!,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isBusy ? null : onConnect,
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.radiowaves_right),
            label: Text(
              isBusy
                  ? LocaleKeys.mobileConnecting.tr
                  : LocaleKeys.mobileConnectServer.tr,
            ),
          ),
        ],
      ),
    );
  }
}
