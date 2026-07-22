import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_gate.dart';

/// Загрузочный экран — логотип + слоган, коротко показывается при старте
/// перед AuthGate. Текст слогана берётся по языку устройства (ru -> русский,
/// иначе — английский); остальной интерфейс приложения пока не локализован
/// (весь UI на русском), это касается только самого слогана на этом экране.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRussian =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ru';

    return Scaffold(
      backgroundColor: const Color(0xFF0F6E73),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icon/app_logo_mark.png',
                width: 140,
                height: 140,
              ),
              const SizedBox(height: 28),
              Text(
                isRussian
                    ? 'Самая выгодная корзина — автоматически.'
                    : 'Your cheapest basket. Automatically.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
