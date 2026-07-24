import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../l10n/gen/app_localizations.dart';
import '../screens/home_shell.dart';
import 'reset_password_screen.dart';
import 'sign_in_screen.dart';

/// Показывает экран входа/регистрации, если пользователь не авторизован,
/// экран смены пароля — если пользователь пришёл по ссылке восстановления
/// пароля (см. ForgotPasswordScreen), иначе — основной интерфейс (HomeShell).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _passwordRecoveryPending = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    if (Env.isConfigured) {
      _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          setState(() => _passwordRecoveryPending = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

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
        if (session == null) return const SignInScreen();
        if (_passwordRecoveryPending) {
          return ResetPasswordScreen(
            onDone: () => setState(() => _passwordRecoveryPending = false),
          );
        }
        return const HomeShell();
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
            AppLocalizations.of(context)!.notConfiguredMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
