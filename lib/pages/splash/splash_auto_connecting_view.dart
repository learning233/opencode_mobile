import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../init.dart';
import '../../utils/translations.dart';
import '../../utils/url_utils.dart';

/// 启动时自动连接/探测沙盒的等待视图。
class SplashAutoConnectingView extends StatelessWidget {
  const SplashAutoConnectingView({
    super.key,
    required this.selectedMode,
    required this.onCancel,
  });

  final int selectedMode;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              selectedMode == 1
                  ? LocaleKeys.e2bProbingSandbox.tr
                  : LocaleKeys.mobileAutoConnecting.trParams({
                      'url': maskUrl(Global.selfHostedServerUrl),
                    }),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onCancel,
              child: Text(LocaleKeys.mobileCancelConnection.tr),
            ),
          ],
        ),
      ),
    );
  }
}
