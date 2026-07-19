import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Обращения к каталогу товаров (store_products) — публичные данные,
/// читаются без ограничений RLS (см. supabase/migrations/0001_init_schema.sql,
/// политика "public read store_products").
class ProductRepository {
  final _client = Supabase.instance.client;

  static const _selectWithStore =
      'id, product_id, raw_name, raw_category_path, package_price, regular_price, '
      'unit_price, unit_type, is_promo, image_url, source_url, '
      'stores(display_name, slug)';

  /// [matchPatterns] комбинируются через И (все подстроки должны
  /// встретиться в пути категории) — так подкатегория может фильтровать и
  /// по своему паттерну, и по паттерну родительской категории одновременно,
  /// что нужно, когда общее слово (например, "dzērieni") само по себе
  /// слишком общее, а в сочетании с родительским паттерном — уже точное.
  Future<List<StoreProductRow>> fetchByCategory(List<String> matchPatterns) async {
    var query = _client.from('store_products').select(_selectWithStore);
    for (final pattern in matchPatterns) {
      query = query.ilike('raw_category_path', '%$pattern%');
    }
    final rows = await query.order('unit_price', ascending: true).limit(200);
    return (rows as List)
        .map((r) => StoreProductRow.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Поиск устойчив к опечаткам (напр. "bezpiens" находит "biezpiens") —
  /// использует нечёткое сравнение по триграммам (pg_trgm), см.
  /// supabase/migrations/0005_fuzzy_search.sql, а не только точную подстроку.
  Future<List<StoreProductRow>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final rows = await _client.rpc('search_products', params: {
      'search_query': trimmed,
      'result_limit': 200,
    });
    return (rows as List)
        .map((r) => StoreProductRow.fromRpcMap(r as Map<String, dynamic>))
        .toList();
  }

  static const _matchedProductsSelect = 'id, canonical_name, brand, '
      'store_products(id, product_id, raw_name, raw_category_path, package_price, '
      'regular_price, unit_price, unit_type, is_promo, image_url, '
      'source_url, stores(display_name, slug))';

  /// Товары, у которых есть предложения минимум от двух магазинов —
  /// результат scraper/match_products.py (SPEC.md §8.2). Это гарантированное
  /// сопоставление (в отличие от приблизительного поиска по категориям),
  /// поэтому можно честно показывать разницу в цене как экономию.
  Future<List<MatchedProduct>> fetchMatchedProducts() async {
    final rows = await _client.from('products').select(_matchedProductsSelect);
    final products = (rows as List)
        .map((r) => MatchedProduct.fromMap(r as Map<String, dynamic>))
        .where((p) => p.offers.length >= 2)
        .toList();
    products.sort((a, b) => a.canonicalName.compareTo(b.canonicalName));
    return products;
  }
}
