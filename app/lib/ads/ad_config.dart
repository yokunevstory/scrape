/// Конфигурация AdMob. По умолчанию — официальные тестовые ID Google
/// (https://developers.google.com/admob/android/test-ads), которые
/// показывают только тестовую рекламу и безопасны для разработки — своего
/// AdMob-аккаунта для них не нужно. Перед релизом заменить на настоящие
/// (см. SETUP.md §6): либо прямо здесь, либо через
/// --dart-define=ADMOB_BANNER_UNIT_ID=... по тому же принципу, что и
/// Supabase-конфиг (config/env.dart) — так реальные ID не попадают в git.
///
/// AdMob App ID (нужен ещё и в android/app/src/main/AndroidManifest.xml,
/// в meta-data com.google.android.gms.ads.APPLICATION_ID — там сейчас тоже
/// тестовый) поменять придётся отдельно, из кода Dart он не читается.
class AdConfig {
  static const String bannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
}
