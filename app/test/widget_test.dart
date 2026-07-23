import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app/app_settings/locale_controller.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/screens/home_shell.dart';
import 'package:app/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    // ProfileScreen читает Supabase.instance — в тестах достаточно
    // локальной инициализации без реального сетевого запроса. shared_preferences
    // требует мок-значений, так как в тестовой среде нет платформенного канала.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('Home shell starts on the catalog tab with bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(LocaleScope(
      controller: LocaleController(),
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeShell(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Каталог'), findsWidgets);
    expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
  });

  testWidgets('English locale renders translated navigation labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(LocaleScope(
      controller: LocaleController(),
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeShell(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Catalog'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Latviešu'), findsOneWidget);
  });
}
