import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Список покупок пользователя — на MVP один список на пользователя
/// ("Мой список"), создаётся автоматически при первом обращении. Позиции —
/// конкретные товары (добавляются с карточки товара значком корзины), как и
/// в отслеживаемых товарах: если товар сматчен между магазинами — в списке
/// сразу видно, где он дешевле.
class ShoppingListRepository {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<String?> _ensureDefaultListId() async {
    final userId = _userId;
    if (userId == null) return null;
    final existing =
        await _client.from('shopping_lists').select('id').eq('user_id', userId).limit(1);
    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }
    final created = await _client
        .from('shopping_lists')
        .insert({'user_id': userId, 'name': 'Мой список'})
        .select('id')
        .single();
    return created['id'] as String;
  }

  Future<bool> contains(StoreProductRow product) async {
    final listId = await _ensureDefaultListId();
    if (listId == null) return false;
    final query = _client.from('shopping_list_items').select('id').eq('list_id', listId);
    final rows = product.productId != null
        ? await query.eq('product_id', product.productId!).limit(1)
        : await query.eq('store_product_id', product.id).limit(1);
    return rows.isNotEmpty;
  }

  Future<void> addProduct(StoreProductRow product) async {
    final listId = await _ensureDefaultListId();
    if (listId == null) return;
    if (product.productId != null) {
      await _client.from('shopping_list_items').upsert({
        'list_id': listId,
        'product_id': product.productId,
      }, onConflict: 'list_id,product_id');
    } else {
      await _client.from('shopping_list_items').upsert({
        'list_id': listId,
        'store_product_id': product.id,
      }, onConflict: 'list_id,store_product_id');
    }
  }

  Future<void> removeProduct(StoreProductRow product) async {
    final listId = await _ensureDefaultListId();
    if (listId == null) return;
    final query = _client.from('shopping_list_items').delete().eq('list_id', listId);
    if (product.productId != null) {
      await query.eq('product_id', product.productId!);
    } else {
      await query.eq('store_product_id', product.id);
    }
  }

  Future<void> removeItem(String itemId) async {
    await _client.from('shopping_list_items').delete().eq('id', itemId);
  }

  static const _storeProductSelect =
      'id, product_id, raw_name, raw_category_path, package_price, regular_price, '
      'unit_price, unit_type, is_promo, image_url, source_url, '
      'stores(display_name, slug)';

  /// Каждая запись — товар (возможно, с предложениями из нескольких
  /// магазинов, если сматчен) + id строки списка (для удаления/количества).
  Future<List<(String itemId, WatchlistEntry entry)>> fetchItems() async {
    final userId = _userId;
    if (userId == null) return [];
    final listId = await _ensureDefaultListId();
    if (listId == null) return [];

    final itemRows = await _client
        .from('shopping_list_items')
        .select('id, product_id, store_product_id, quantity')
        .eq('list_id', listId)
        .order('created_at', ascending: false);

    final entries = <(String, WatchlistEntry)>[];
    for (final row in itemRows.cast<Map<String, dynamic>>()) {
      final itemId = row['id'] as String;
      final productId = row['product_id'] as String?;
      final storeProductId = row['store_product_id'] as String?;

      if (productId != null) {
        final offerRows = await _client
            .from('store_products')
            .select(_storeProductSelect)
            .eq('product_id', productId);
        final offers = offerRows.map(StoreProductRow.fromMap).toList();
        if (offers.isNotEmpty) {
          entries.add((itemId, WatchlistEntry(offers: offers, watchedAtPrice: null)));
        }
      } else if (storeProductId != null) {
        final offerRows = await _client
            .from('store_products')
            .select(_storeProductSelect)
            .eq('id', storeProductId)
            .limit(1);
        final offers = offerRows.map(StoreProductRow.fromMap).toList();
        if (offers.isNotEmpty) {
          entries.add((itemId, WatchlistEntry(offers: offers, watchedAtPrice: null)));
        }
      }
    }
    return entries;
  }
}
