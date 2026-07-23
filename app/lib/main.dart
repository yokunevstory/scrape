import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  final localeController = LocaleController();
  await localeController.load();
  runApp(PriceCompareApp(localeController: localeController));
}

class PriceCompareApp extends StatefulWidget {
  const PriceCompareApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<PriceCompareApp> createState() => _PriceCompareAppState();
}

class _PriceCompareAppState extends State<PriceCompareApp> {
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
