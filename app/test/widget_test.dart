import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const HomeShell(),
    ));

    expect(find.text('Каталог'), findsWidgets);
    expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
  });
}
