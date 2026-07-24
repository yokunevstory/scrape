/// Конфигурация подключения к Supabase.
///
/// Значения передаются через --dart-define при запуске/сборке, а не
/// зашиваются в код — так конфиг легко менять между окружениями (dev/prod,
/// основной проект/архив) без правки исходников:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
library;

class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Deep link, на который Supabase Auth возвращает пользователя из письма
  /// восстановления пароля (см. lib/auth/forgot_password_screen.dart).
  /// Схема зарегистрирована в AndroidManifest.xml и ios/Runner/Info.plist;
  /// URL нужно добавить в Supabase Dashboard → Authentication → URL
  /// Configuration → Redirect URLs, иначе Supabase отклонит редирект
  /// (см. SETUP.md §7 — это нужно сделать через дашборд, сам я не могу).
  static const passwordResetRedirectUrl = 'lv.centik.app://reset-callback';
}
