import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'api/opencode_client.dart';
import 'bindings.dart';
import 'init.dart';
import 'routes.dart';
import 'utils/app_logger.dart';
import 'utils/app_theme.dart';
import 'utils/snackbar_utils.dart';
import 'utils/translations.dart';

class OpenCodeApp extends StatefulWidget {
  const OpenCodeApp({super.key});

  @override
  State<OpenCodeApp> createState() => _OpenCodeAppState();
}

class _OpenCodeAppState extends State<OpenCodeApp> {
  late final Worker _themeSub;
  late final Worker _localeSub;
  late final Worker _unauthorizedSub;
  DateTime _lastAuthNoticeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    // 仅订阅主题/语言两个 Rx，避免 Obx 隐式包裹整棵 GetMaterialApp。
    _themeSub = ever(Global.themeIsLightRx, (_) => setState(() {}));
    _localeSub = ever(Global.languageRx, (_) => setState(() {}));
    // HTTP 侧 401/403 的全局消费端：提示用户并复位标志形成闭环。
    // 一批并发请求会连续置位，按时间窗去重，避免弹窗刷屏。
    _unauthorizedSub = ever<bool>(OpenCodeClient.unauthorized, _onUnauthorized);
  }

  void _onUnauthorized(bool value) {
    if (!value) return;
    OpenCodeClient.resetUnauthorized();
    final now = DateTime.now();
    if (now.difference(_lastAuthNoticeAt) < const Duration(seconds: 10)) return;
    _lastAuthNoticeAt = now;
    AppLogger.e('HTTP credentials rejected — prompting user');
    Snack.error(
      LocaleKeys.mobileSseAuthFailed.tr,
      title: 'OpenCode',
    );
  }

  @override
  void dispose() {
    _themeSub.dispose();
    _localeSub.dispose();
    _unauthorizedSub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Global.themeIsLightRx.value;
    final currentLocale = Global.languageRx.value ?? Global.language;
    return GetMaterialApp(
      title: 'OpenCode',
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
      initialBinding: GlobalBinding(),
      theme: light,
      darkTheme: dark,
      themeMode: isLight ? ThemeMode.light : ThemeMode.dark,
      translations: Messages(),
      locale: currentLocale,
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
    );
  }
}
