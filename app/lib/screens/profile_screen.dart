import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'watchlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _personalizedAds = false;
  bool _savingConsent = false;

  Future<void> _setPersonalizedAds(bool value) async {
    setState(() {
      _personalizedAds = value;
      _savingConsent = true;
    });
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await Supabase.instance.client.from('user_consents').insert({
        'user_id': userId,
        'consent_type': 'personalized_ads',
        'granted': value,
        'policy_version': 'v0.1',
      });
    }
    if (mounted) setState(() => _savingConsent = false);
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт'),
        content: const Text(
          'Удаление аккаунта и всех данных выполняется через отдельный '
          'защищённый процесс (Edge Function с проверкой личности) — он '
          'ещё не подключён в этой сборке. Пока что для удаления аккаунта '
          'напишите на адрес поддержки (см. legal/ACCOUNT_DELETION_POLICY.md).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Намеренно не реализовано: удаление аккаунта требует service-role
      // доступа (auth.admin.deleteUser), который нельзя вызывать из
      // клиентского приложения — см. legal/ACCOUNT_DELETION_POLICY.md.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.email ?? 'Гость'),
            subtitle: const Text('Аккаунт'),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Персонализированная реклама'),
            subtitle: const Text('Можно включить или выключить в любой момент'),
            value: _personalizedAds,
            onChanged: _savingConsent ? null : _setPersonalizedAds,
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Отслеживаемые товары'),
            subtitle: const Text('Ловите акции на избранные товары'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WatchlistScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Политика конфиденциальности'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении и источниках данных'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () => Supabase.instance.client.auth.signOut(),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('Удалить аккаунт',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }
}
