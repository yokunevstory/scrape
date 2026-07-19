class StoreProductRow {
  const StoreProductRow({
    required this.id,
    required this.productId,
    required this.storeDisplayName,
    required this.storeSlug,
    required this.rawName,
    required this.categoryPath,
    required this.packagePrice,
    required this.regularPrice,
    required this.unitPrice,
    required this.unitType,
    required this.isPromo,
    required this.imageUrl,
    required this.sourceUrl,
  });

  final String id;
  /// Ссылка на канонический товар (products.id), если этот товар сматчен
  /// с таким же в другом магазине (scraper/match_products.py) — null, если
  /// ещё не сматчен. Нужен, чтобы «следить» можно было за товаром во всех
  /// магазинах сразу, а не только за конкретным предложением одного магазина.
  final String? productId;
  final String storeDisplayName;
  final String storeSlug;
  final String rawName;
  final String? categoryPath;
  final double packagePrice;
  final double? regularPrice;
  final double? unitPrice;
  final String? unitType; // 'kg' | 'l' | 'gab'
  final bool isPromo;
  final String? imageUrl;
  final String sourceUrl;

  /// Атрибуция источника для отображения рядом с ценой — SPEC.md §8.0/§5.
  String get attribution =>
      storeSlug == 'barbora' ? 'по данным Barbora' : 'по данным $storeDisplayName';

  /// Читаемое обозначение единицы для «€/кг» и т.п. вместо общего «ед.».
  String get unitLabel {
    switch (unitType) {
      case 'kg':
        return 'кг';
      case 'l':
        return 'л';
      case 'gab':
        return 'шт';
      default:
        return 'ед.';
    }
  }

  /// Вес/объём упаковки, посчитанный из цены за упаковку и цены за единицу
  /// (а не распарсенный из текста названия — это надёжнее, см. обсуждение
  /// в чате: магазины уже сами считают unit_price по факту продажи).
  /// null, если unit_price отсутствует или равен нулю, либо unit_type — 'gab'
  /// (штучный товар без веса/объёма для сравнения).
  double? get packageSize {
    if (unitPrice == null || unitPrice == 0 || unitType == 'gab') return null;
    return packagePrice / unitPrice!;
  }

  /// Читаемое представление веса/объёма, напр. «180 г» или «1.5 л».
  String? get packageSizeLabel {
    final size = packageSize;
    if (size == null) return null;
    if (unitType == 'kg') {
      return size < 1 ? '${(size * 1000).round()} г' : '${size.toStringAsFixed(2)} кг';
    }
    if (unitType == 'l') {
      return size < 1 ? '${(size * 1000).round()} мл' : '${size.toStringAsFixed(2)} л';
    }
    return null;
  }

  factory StoreProductRow.fromMap(Map<String, dynamic> map) {
    final store = map['stores'] as Map<String, dynamic>?;
    return StoreProductRow(
      id: map['id'] as String,
      productId: map['product_id'] as String?,
      storeDisplayName: (store?['display_name'] as String?) ?? '—',
      storeSlug: (store?['slug'] as String?) ?? '',
      rawName: map['raw_name'] as String? ?? '',
      categoryPath: map['raw_category_path'] as String?,
      packagePrice: (map['package_price'] as num).toDouble(),
      regularPrice: (map['regular_price'] as num?)?.toDouble(),
      unitPrice: (map['unit_price'] as num?)?.toDouble(),
      unitType: map['unit_type'] as String?,
      isPromo: map['is_promo'] as bool? ?? false,
      imageUrl: map['image_url'] as String?,
      sourceUrl: map['source_url'] as String? ?? '',
    );
  }

  /// Результат RPC search_products (SPEC.md — нечёткий поиск, pg_trgm) —
  /// магазин там плоскими полями, а не вложенным объектом stores(...).
  factory StoreProductRow.fromRpcMap(Map<String, dynamic> map) {
    return StoreProductRow(
      id: map['id'] as String,
      productId: map['product_id'] as String?,
      storeDisplayName: (map['store_display_name'] as String?) ?? '—',
      storeSlug: (map['store_slug'] as String?) ?? '',
      rawName: map['raw_name'] as String? ?? '',
      categoryPath: map['raw_category_path'] as String?,
      packagePrice: (map['package_price'] as num).toDouble(),
      regularPrice: (map['regular_price'] as num?)?.toDouble(),
      unitPrice: (map['unit_price'] as num?)?.toDouble(),
      unitType: map['unit_type'] as String?,
      isPromo: map['is_promo'] as bool? ?? false,
      imageUrl: map['image_url'] as String?,
      sourceUrl: map['source_url'] as String? ?? '',
    );
  }
}

/// Один и тот же товар, сматченный между магазинами (SPEC.md §8.2,
/// scraper/match_products.py) — offers содержит предложения из разных
/// магазинов для одного канонического товара.
class MatchedProduct {
  const MatchedProduct({
    required this.id,
    required this.canonicalName,
    required this.brand,
    required this.offers,
  });

  final String id;
  final String canonicalName;
  final String? brand;
  final List<StoreProductRow> offers;

  /// Верхнеуровневая категория (первый сегмент пути) — берём с любого из
  /// предложений, чтобы сгруппировать сопоставленные товары так же, как
  /// обычный каталог (см. запрос пользователя — категории нужны и здесь).
  String? get topCategory {
    for (final o in offers) {
      final path = o.categoryPath;
      if (path != null && path.isNotEmpty) return path.split('/').first.trim();
    }
    return null;
  }

  StoreProductRow? get cheapest {
    if (offers.isEmpty) return null;
    return offers.reduce((a, b) => a.packagePrice <= b.packagePrice ? a : b);
  }

  StoreProductRow? get mostExpensive {
    if (offers.isEmpty) return null;
    return offers.reduce((a, b) => a.packagePrice >= b.packagePrice ? a : b);
  }

  /// Экономия при выборе самого дешёвого предложения вместо самого дорогого.
  double? get savings {
    final cheap = cheapest, exp = mostExpensive;
    if (cheap == null || exp == null || cheap.id == exp.id) return null;
    final diff = exp.packagePrice - cheap.packagePrice;
    return diff > 0 ? diff : null;
  }

  factory MatchedProduct.fromMap(Map<String, dynamic> map) {
    final offersRaw = (map['store_products'] as List?) ?? [];
    return MatchedProduct(
      id: map['id'] as String,
      canonicalName: map['canonical_name'] as String? ?? '',
      brand: map['brand'] as String?,
      offers: offersRaw
          .map((o) => StoreProductRow.fromMap(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Одна запись в списке отслеживания. Если товар сматчен между магазинами —
/// [offers] содержит предложения из ВСЕХ магазинов сразу (следим за товаром,
/// а не за одним конкретным предложением). Если нет — только одно.
class WatchlistEntry {
  const WatchlistEntry({required this.offers, required this.watchedAtPrice});

  final List<StoreProductRow> offers;
  /// Цена в момент постановки на слежение — только для несматченных товаров
  /// (одно предложение), чтобы обнаружить, что цена именно упала, а не
  /// просто отличается между магазинами.
  final double? watchedAtPrice;

  /// Показать рамку-выделение: сейчас акция на любое из предложений, либо
  /// (для несматченного товара) цена упала относительно момента постановки
  /// на слежение. В будущем — сюда же добавится пуш-уведомление.
  bool get isHighlighted {
    if (offers.any((o) => o.isPromo)) return true;
    if (offers.length == 1 && watchedAtPrice != null) {
      return offers.first.packagePrice < watchedAtPrice!;
    }
    return false;
  }
}

/// Итог сравнения списка покупок по магазинам (SPEC.md §6, сценарий Б).
/// Считается напрямую по уже известным предложениям каждой позиции списка
/// ([WatchlistEntry.offers]) — список хранит конкретные товары, а не
/// свободный текст, поэтому повторный поиск при открытии экрана не нужен.
class BasketSummary {
  const BasketSummary({
    required this.totalsByStore,
    required this.storeDisplayNames,
    required this.foundCountByStore,
    required this.splitTotal,
    required this.splitStoreCount,
    required this.totalItems,
  });

  /// Магазин -> сумма, если купить там всё, что нашлось (только по найденным
  /// позициям — если товара нет в магазине, он просто не участвует в сумме).
  final Map<String, double> totalsByStore;
  final Map<String, String> storeDisplayNames;
  /// Магазин -> сколько из позиций списка там нашлось.
  final Map<String, int> foundCountByStore;
  /// Сумма, если для каждой позиции выбирать самый дешёвый вариант вообще
  /// из любого магазина.
  final double splitTotal;
  final int splitStoreCount;
  final int totalItems;

  /// Магазин с минимальной суммой (из тех, где нашлось хотя бы что-то).
  MapEntry<String, double>? get bestSingleStore {
    if (totalsByStore.isEmpty) return null;
    return totalsByStore.entries.reduce((a, b) => a.value <= b.value ? a : b);
  }

  String storeDisplayName(String slug) => storeDisplayNames[slug] ?? slug;

  factory BasketSummary.fromEntries(List<WatchlistEntry> entries) {
    final totalsByStore = <String, double>{};
    final foundCountByStore = <String, int>{};
    final storeDisplayNames = <String, String>{};
    double splitTotal = 0;
    final splitStores = <String>{};

    final allStoreSlugs = <String>{};
    for (final e in entries) {
      for (final o in e.offers) {
        allStoreSlugs.add(o.storeSlug);
        storeDisplayNames[o.storeSlug] = o.storeDisplayName;
      }
    }

    for (final slug in allStoreSlugs) {
      double total = 0;
      int found = 0;
      for (final e in entries) {
        final inStore = e.offers.where((o) => o.storeSlug == slug).toList();
        if (inStore.isEmpty) continue;
        final cheapest = inStore.reduce((a, b) => a.packagePrice <= b.packagePrice ? a : b);
        total += cheapest.packagePrice;
        found++;
      }
      if (found > 0) {
        totalsByStore[slug] = total;
        foundCountByStore[slug] = found;
      }
    }

    for (final e in entries) {
      if (e.offers.isEmpty) continue;
      final cheapest = e.offers.reduce((a, b) => a.packagePrice <= b.packagePrice ? a : b);
      splitTotal += cheapest.packagePrice;
      splitStores.add(cheapest.storeSlug);
    }

    return BasketSummary(
      totalsByStore: totalsByStore,
      storeDisplayNames: storeDisplayNames,
      foundCountByStore: foundCountByStore,
      splitTotal: splitTotal,
      splitStoreCount: splitStores.length,
      totalItems: entries.length,
    );
  }
}

enum ProductSort {
  unitPriceAsc('Цена за ед. (сначала дешевле)'),
  packagePriceAsc('Цена за упаковку (сначала дешевле)'),
  packageSizeAsc('Вес/объём (сначала меньше)'),
  packageSizeDesc('Вес/объём (сначала больше)');

  const ProductSort(this.label);
  final String label;
}

extension ProductSortX on ProductSort {
  Comparator<StoreProductRow> get comparator {
    switch (this) {
      case ProductSort.unitPriceAsc:
        return (a, b) => _compareNullable(a.unitPrice, b.unitPrice);
      case ProductSort.packagePriceAsc:
        return (a, b) => a.packagePrice.compareTo(b.packagePrice);
      case ProductSort.packageSizeAsc:
        return (a, b) => _compareNullable(a.packageSize, b.packageSize);
      case ProductSort.packageSizeDesc:
        return (a, b) => _compareNullable(b.packageSize, a.packageSize);
    }
  }
}

int _compareNullable(double? a, double? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
