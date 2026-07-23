import 'package:supabase_flutter/supabase_flutter.dart';

/// Разрешена ли персонализированная реклама — читает последнюю запись
/// согласия (consent_type='personalized_ads', см. profile_screen.dart и
/// legal/DATA_PROCESSING_CONSENT.md). По умолчанию (не вошёл, или согласия
/// ещё не было) — false: показываем только неперсонализированную рекламу,
/// это безопасный вариант по GDPR, а не наоборот.
Future<bool> hasPersonalizedAdsConsent() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;

  final rows = await Supabase.instance.client
      .from('user_consents')
      .select('granted')
      .eq('user_id', userId)
      .eq('consent_type', 'personalized_ads')
      .order('created_at', ascending: false)
      .limit(1);

  if (rows.isEmpty) return false;
  return rows.first['granted'] as bool? ?? false;
}
