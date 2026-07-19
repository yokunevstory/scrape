import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (_isSignUp && !_consentGiven) {
      setState(() => _error =
          'Нужно подтвердить согласие на обработку данных, чтобы создать аккаунт.');
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
            _info = 'Аккаунт создан. Проверьте почту '
                '${_emailController.text.trim()} и подтвердите email по '
                'ссылке из письма, затем войдите с этим паролем.';
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
      setState(() => _error = 'Не удалось выполнить запрос: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    'PriceCompare LV',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Создать аккаунт' : 'Вход',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      border: OutlineInputBorder(),
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
                      title: const Text(
                        'Согласен(-на) с условиями обработки данных, '
                        'описанными в Политике конфиденциальности',
                        style: TextStyle(fontSize: 13),
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
                        : Text(_isSignUp ? 'Зарегистрироваться' : 'Войти'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                      _info = null;
                    }),
                    child: Text(
                      _isSignUp
                          ? 'Уже есть аккаунт? Войти'
                          : 'Нет аккаунта? Зарегистрироваться',
                    ),
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
