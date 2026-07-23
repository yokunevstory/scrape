import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/gen/app_localizations.dart';
import 'consent.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _consentGiven = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (_isSignUp && !_consentGiven) {
      setState(() => _error = t.consentRequiredError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final auth = Supabase.instance.client.auth;
    try {
      if (_isSignUp) {
        final res = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final userId = res.user?.id;
        if (res.session != null && userId != null) {
          // Сессия уже есть (подтверждение email выключено в проекте) —
          // можно сразу записать согласие.
          await ensureAccountConsentRecorded(userId);
        } else {
          // Подтверждение email включено в настройках Supabase Auth —
          // сессии пока нет, согласие запишется при первом входе после
          // подтверждения (см. ensureAccountConsentRecorded ниже).
          setState(() {
            _info = t.signUpSuccessInfo(_emailController.text.trim());
            _isSignUp = false;
          });
        }
      } else {
        final res = await auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final userId = res.user?.id;
        if (userId != null) {
          await ensureAccountConsentRecorded(userId);
        }
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = t.genericRequestError('$e'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.appTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? t.signUpTitle : t.signInTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: t.emailLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: t.passwordLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _consentGiven,
                      onChanged: (value) =>
                          setState(() => _consentGiven = value ?? false),
                      title: Text(
                        t.consentCheckboxLabel,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _info!,
                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? t.buttonSignUp : t.buttonSignIn),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                      _info = null;
                    }),
                    child: Text(_isSignUp ? t.toggleToSignIn : t.toggleToSignUp),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
