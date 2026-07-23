import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_settings/locale_controller.dart';
import 'config/env.dart';
import 'l10n/gen/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }
  // Не блокируем старт приложения ожиданием инициализации рекламного SDK —
  // баннеры (см. widgets/ad_banner.dart) сами дождутся готовности через
  // AdWidget/BannerAd.load(), а если инициализация ещё не завершилась к
  // моменту первой загрузки баннера, google_mobile_ads это переживёт.
  unawaited(MobileAds.instance.initialize());
  final localeController = LocaleController();
  await localeController.load();
  runApp(CentikApp(localeController: localeController));
}

class CentikApp extends StatefulWidget {
  const CentikApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<CentikApp> createState() => _CentikAppState();
}

class _CentikAppState extends State<CentikApp> {
  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: widget.localeController,
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        locale: widget.localeController.locale,
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
