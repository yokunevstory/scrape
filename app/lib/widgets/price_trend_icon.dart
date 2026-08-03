import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

/// Маленькая стрелка рядом с ценой — подешевело/подорожало по сравнению с
/// неделей назад (см. StoreProductRow.priceTrend,
/// supabase/migrations/0011_price_trend.sql). Ничего не рисует, если тренда
/// нет (цена не изменилась или история для товара ещё не набралась).
class PriceTrendIcon extends StatelessWidget {
  const PriceTrendIcon({super.key, required this.trend, this.size = 14});

  final PriceTrend trend;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (trend == PriceTrend.none) return const SizedBox.shrink();
    final colors = context.appColors;
    final isDown = trend == PriceTrend.down;
    return Icon(
      isDown ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
      size: size,
      color: isDown ? colors.savings : colors.priceUp,
    );
  }
}
