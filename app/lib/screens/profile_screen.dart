import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ads/ad_consent.dart';
import '../app_settings/locale_controller.dart';
import '../l10n/gen/app_localizations.dart';
import 'watchlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _personalizedAds = false;
  bool _savingConsent = false;

  @override
  void initState() {
    super.initState();
    // Переключатель раньше всегда открывался выключенным, даже если
    // пользователь уже разрешил персонализированную рекламу раньше —
    // теперь от этого согласия реально зависит, какую рекламу показывать
    // (см. widgets/ad_banner.dart), так что подгружаем сохранённое значение.
    hasPersonalizedAdsConsent().then((value) {
      if (mounted) setState(() => _personalizedAds = value);
    });
  }

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
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteAccountTitle),
        content: Text(t.deleteAccountDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.dialogOk),
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
    final t = AppLocalizations.of(context)!;
    final localeController = LocaleScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.profileTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.email ?? t.guestLabel),
            subtitle: Text(t.accountLabel),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.languageSectionTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SegmentedButton<Locale>(
                  segments: [
                    ButtonSegment(value: const Locale('ru'), label: Text(t.languageRussian)),
                    ButtonSegment(value: const Locale('lv'), label: Text(t.languageLatvian)),
                    ButtonSegment(value: const Locale('en'), label: Text(t.languageEnglish)),
                  ],
                  selected: {localeController.locale},
                  onSelectionChanged: (selection) =>
                      localeController.setLocale(selection.first),
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: Text(t.personalizedAdsTitle),
            subtitle: Text(t.personalizedAdsSubtitle),
            value: _personalizedAds,
            onChanged: _savingConsent ? null : _setPersonalizedAds,
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: Text(t.watchlistMenuTitle),
            subtitle: Text(t.watchlistMenuSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WatchlistScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(t.privacyPolicyTitle),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(t.aboutAppTitle),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t.logoutTitle),
            onTap: () => Supabase.instance.client.auth.signOut(),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text(t.deleteAccountTitle,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }
}
