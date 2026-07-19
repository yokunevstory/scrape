import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../screens/home_shell.dart';
import 'sign_in_screen.dart';

/// Показывает экран входа/регистрации, если пользователь не авторизован,
/// иначе — основной интерфейс приложения (HomeShell).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Env.isConfigured) {
      return const _NotConfiguredScreen();
    }

    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      initialData: AuthState(AuthChangeEvent.initialSession, auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        return session == null ? const SignInScreen() : const HomeShell();
      },
    );
  }
}

class _NotConfiguredScreen extends StatelessWidget {
  const _NotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Supabase не настроен: запустите приложение с '
            '--dart-define=SUPABASE_URL=... и '
            '--dart-define=SUPABASE_ANON_KEY=... '
            '(см. scripts/build_web.bat).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
