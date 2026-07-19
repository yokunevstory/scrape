import 'package:supabase_flutter/supabase_flutter.dart';

/// Версия текста согласия из legal/DATA_PROCESSING_CONSENT.md — фиксируется
/// вместе с записью согласия, чтобы всегда знать, на какую именно версию
/// текста согласился пользователь.
const consentPolicyVersion = 'v0.1';

/// Записывает согласие на обработку данных аккаунта, если оно ещё не
/// записано для этого пользователя. Нужен отдельным шагом (не прямо внутри
/// signUp), потому что при включённом подтверждении email сессии сразу после
/// signUp ещё нет — auth.uid() пуст, и запись в user_consents упадёт по RLS
/// (см. политику "own consents" в supabase/migrations/0001_init_schema.sql).
/// Поэтому вызываем это при каждом входе с уже подтверждённой сессией —
/// если запись уже есть, ничего не делаем.
Future<void> ensureAccountConsentRecorded(String userId) async {
  final client = Supabase.instance.client;
  final existing = await client
      .from('user_consents')
      .select('id')
      .eq('user_id', userId)
      .eq('consent_type', 'account_data')
      .limit(1);

  if ((existing as List).isNotEmpty) return;

  await client.from('user_consents').insert({
    'user_id': userId,
    'consent_type': 'account_data',
    'granted': true,
    'policy_version': consentPolicyVersion,
  });
}
