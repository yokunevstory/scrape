import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Догружает price_week_ago пачкой для списка товаров (один запрос на весь
/// список, не по одному на карточку) и возвращает те же StoreProductRow, но
/// с заполненным priceWeekAgo — см. supabase/migrations/0011_price_trend.sql.
/// Общая функция для всех репозиториев, которые показывают карточки товаров
/// (ProductRepository, WatchlistRepository, ShoppingListRepository), чтобы
/// не дублировать этот запрос в каждом.
Future<List<StoreProductRow>> withPriceTrend(List<StoreProductRow> rows) async {
  if (rows.isEmpty) return rows;
  final ids = rows.map((r) => r.id).toSet().toList();
  final trendRows = await Supabase.instance.client
      .from('store_product_price_trend')
      .select('store_product_id, price_week_ago')
      .inFilter('store_product_id', ids);
  if ((trendRows as List).isEmpty) return rows;

  final trendMap = <String, double>{
    for (final t in trendRows.cast<Map<String, dynamic>>())
      t['store_product_id'] as String: (t['price_week_ago'] as num).toDouble(),
  };
  return rows.map((r) => r.copyWithPriceWeekAgo(trendMap[r.id])).toList();
}
