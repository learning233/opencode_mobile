import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'bindings.dart';
import 'init.dart';
import 'routes.dart';
import 'utils/app_theme.dart';
import 'utils/translations.dart';

class OpenCodeApp extends StatefulWidget {
  const OpenCodeApp({super.key});

  @override
  State<OpenCodeApp> createState() => _OpenCodeAppState();
}

class _OpenCodeAppState extends State<OpenCodeApp> {
  late final Worker _themeSub;
  late final Worker _localeSub;

  @override
  void initState() {
    super.initState();
    // 仅订阅主题/语言两个 Rx，避免 Obx 隐式包裹整棵 GetMaterialApp。
    _themeSub = ever(Global.themeIsLightRx, (_) => setState(() {}));
    _localeSub = ever(Global.languageRx, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _themeSub.dispose();
    _localeSub.dispose();
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
