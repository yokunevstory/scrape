import 'package:flutter/material.dart';

/// Цветовая палитра из SPEC.md §14: синий/бирюзовый — доверие,
/// зелёный — выгода/экономия, янтарный — CTA/лучшее предложение.
/// Красный используется только точечно (рост цены), не как основной цвет.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.savings,
    required this.onSavings,
    required this.savingsContainer,
    required this.deal,
    required this.onDeal,
    required this.priceUp,
  });

  final Color savings;
  final Color onSavings;
  final Color savingsContainer;
  final Color deal;
  final Color onDeal;
  final Color priceUp;

  static const light = AppColors(
    savings: Color(0xFF2E9E5B),
    onSavings: Color(0xFFFFFFFF),
    savingsContainer: Color(0xFFDCF3E4),
    deal: Color(0xFFF5A623),
    onDeal: Color(0xFF3A2600),
    priceUp: Color(0xFFD64545),
  );

  static const dark = AppColors(
    savings: Color(0xFF57C285),
    onSavings: Color(0xFF00391B),
    savingsContainer: Color(0xFF154D2C),
    deal: Color(0xFFFFC061),
    onDeal: Color(0xFF3A2600),
    priceUp: Color(0xFFE58585),
  );

  @override
  AppColors copyWith({
    Color? savings,
    Color? onSavings,
    Color? savingsContainer,
    Color? deal,
    Color? onDeal,
    Color? priceUp,
  }) {
    return AppColors(
      savings: savings ?? this.savings,
      onSavings: onSavings ?? this.onSavings,
      savingsContainer: savingsContainer ?? this.savingsContainer,
      deal: deal ?? this.deal,
      onDeal: onDeal ?? this.onDeal,
      priceUp: priceUp ?? this.priceUp,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      savings: Color.lerp(savings, other.savings, t)!,
      onSavings: Color.lerp(onSavings, other.onSavings, t)!,
      savingsContainer: Color.lerp(savingsContainer, other.savingsContainer, t)!,
      deal: Color.lerp(deal, other.deal, t)!,
      onDeal: Color.lerp(onDeal, other.onDeal, t)!,
      priceUp: Color.lerp(priceUp, other.priceUp, t)!,
    );
  }
}

const _seedColor = Color(0xFF0F6E73);

ThemeData buildAppTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark ? null : const Color(0xFFFAFAFA),
    extensions: [isDark ? AppColors.dark : AppColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
    ),
  );
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
