import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Список отслеживаемых товаров — "слежу за ценой", чтобы увидеть акцию или
/// падение цены на избранный товар при следующем открытии приложения (без
/// пуш-уведомлений — это отдельная задача на будущее, см. SPEC.md).
///
/// Если товар сматчен между магазинами (product.productId не null) —
/// отслеживаем канонический товар целиком: в списке будут видны предложения
/// из ВСЕХ магазинов сразу, а не только то, с которого нажали "следить".
/// Если не сматчен — отслеживаем конкретное предложение и запоминаем его
/// цену на момент постановки, чтобы потом можно было заметить, что цена
/// именно упала.
class WatchlistRepository {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<bool> isWatched(StoreProductRow product) async {
    final userId = _userId;
    if (userId == null) return false;
    final query = _client.from('watched_products').select('id').eq('user_id', userId);
    final rows = product.productId != null
        ? await query.eq('product_id', product.productId!).limit(1)
        : await query.eq('store_product_id', product.id).limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<void> addWatch(StoreProductRow product) async {
    final userId = _userId;
    if (userId == null) return;
    if (product.productId != null) {
      await _client.from('watched_products').upsert({
        'user_id': userId,
        'product_id': product.productId,
      }, onConflict: 'user_id,product_id');
    } else {
      await _client.from('watched_products').upsert({
        'user_id': userId,
        'store_product_id': product.id,
        'watched_at_price': product.packagePrice,
      }, onConflict: 'user_id,store_product_id');
    }
  }

  Future<void> removeWatch(StoreProductRow product) async {
    final userId = _userId;
    if (userId == null) return;
    final query = _client.from('watched_products').delete().eq('user_id', userId);
    if (product.productId != null) {
      await query.eq('product_id', product.productId!);
    } else {
      await query.eq('store_product_id', product.id);
    }
  }

  static const _storeProductSelect =
      'id, product_id, raw_name, raw_category_path, package_price, regular_price, '
      'unit_price, unit_type, is_promo, image_url, source_url, '
      'stores(display_name, slug)';

  Future<List<WatchlistEntry>> fetchWatchlist() async {
    final userId = _userId;
    if (userId == null) return [];

    final watchRows = await _client
        .from('watched_products')
        .select('product_id, store_product_id, watched_at_price')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final entries = <WatchlistEntry>[];
    for (final row in (watchRows as List).cast<Map<String, dynamic>>()) {
      final productId = row['product_id'] as String?;
      final storeProductId = row['store_product_id'] as String?;

      if (productId != null) {
        // Сматченный товар — подтягиваем предложения из всех магазинов.
        final offerRows = await _client
            .from('store_products')
            .select(_storeProductSelect)
            .eq('product_id', productId);
        final offers = (offerRows as List)
            .map((o) => StoreProductRow.fromMap(o as Map<String, dynamic>))
            .toList();
        if (offers.isNotEmpty) {
          entries.add(WatchlistEntry(offers: offers, watchedAtPrice: null));
        }
      } else if (storeProductId != null) {
        final offerRows = await _client
            .from('store_products')
            .select(_storeProductSelect)
            .eq('id', storeProductId)
            .limit(1);
        final offers = (offerRows as List)
            .map((o) => StoreProductRow.fromMap(o as Map<String, dynamic>))
            .toList();
        if (offers.isNotEmpty) {
          entries.add(WatchlistEntry(
            offers: offers,
            watchedAtPrice: (row['watched_at_price'] as num?)?.toDouble(),
          ));
        }
      }
    }
    return entries;
  }
}
