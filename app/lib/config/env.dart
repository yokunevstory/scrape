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
}
