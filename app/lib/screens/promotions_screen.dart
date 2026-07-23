import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/product_repository.dart';
import '../l10n/gen/app_localizations.dart';
import '../widgets/ad_banner.dart';
import '../widgets/collapsible_category_section.dart';
import '../widgets/product_card.dart';

/// Все текущие акции сразу из всех магазинов (is_promo, store_products) —
/// раньше был мокап с тремя фиксированными позициями (SPEC.md §9), теперь
/// реальные данные, сгруппированные по категориям так же, как каталог и
/// "Сопоставленные товары" — см. запрос пользователя "собери акции в одно
/// место, разбей по категориям".
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  final _repo = ProductRepository();
  late final Future<List<StoreProductRow>> _future = _repo.fetchPromotions();

  /// По умолчанию все рубрики свёрнуты — см. тот же паттерн в
  /// MatchedProductsScreen (CollapsibleCategorySection).
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.promotionsTitle)),
      body: FutureBuilder<List<StoreProductRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.loadErrorGeneric('${snapshot.error}')),
              ),
            );
          }
          final promos = snapshot.data ?? [];
          if (promos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.promotionsEmpty, textAlign: TextAlign.center),
              ),
            );
          }

          final byCategory = <String, List<StoreProductRow>>{};
          for (final p in promos) {
            byCategory.putIfAbsent(p.topCategory ?? t.categoryOther, () => []).add(p);
          }
          // Внутри категории — самые выгодные скидки сначала.
          for (final items in byCategory.values) {
            items.sort((a, b) => (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0));
          }
          final categories = byCategory.keys.toList()..sort();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length + 2,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Center(child: AdBanner());
              }
              if (index == categories.length + 1) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    t.promotionsDisclaimer,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              }
              final category = categories[index - 1];
              final items = byCategory[category]!;
              return CollapsibleCategorySection<StoreProductRow>(
                title: category,
                items: items,
                expanded: _expanded.contains(category),
                onToggle: () => setState(() {
                  if (!_expanded.add(category)) _expanded.remove(category);
                }),
                itemBuilder: (context, product) =>
                    ProductCard(product: product, isCheapest: false),
              );
            },
          );
        },
      ),
    );
  }
}
