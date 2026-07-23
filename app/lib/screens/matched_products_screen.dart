import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/product_repository.dart';
import '../l10n/gen/app_localizations.dart';
import '../widgets/matched_product_card.dart';

/// Товары, гарантированно сопоставленные между Rimi и Maxima (Barbora) —
/// scraper/match_products.py, SPEC.md §8.2. В отличие от обычного поиска/
/// категорий, здесь показываются именно предложения ОДНОГО И ТОГО ЖЕ товара
/// из разных магазинов рядом, с посчитанной экономией. Сгруппировано по
/// категориям, как и обычный каталог.
class MatchedProductsScreen extends StatefulWidget {
  const MatchedProductsScreen({super.key});

  @override
  State<MatchedProductsScreen> createState() => _MatchedProductsScreenState();
}

class _MatchedProductsScreenState extends State<MatchedProductsScreen> {
  final _repo = ProductRepository();
  late final Future<List<MatchedProduct>> _future = _repo.fetchMatchedProducts();

  /// По умолчанию все рубрики свёрнуты — так неинтересная категория
  /// (например, алкоголь) не мешает пролистывать до нужной. Разворачивается
  /// только та, по которой явно тапнули.
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.matchedProductsTitle)),
      body: FutureBuilder<List<MatchedProduct>>(
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
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.matchedProductsEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final byCategory = <String, List<MatchedProduct>>{};
          for (final p in products) {
            byCategory.putIfAbsent(p.topCategory ?? t.categoryOther, () => []).add(p);
          }
          final categories = byCategory.keys.toList()..sort();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == categories.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    t.matchedProductsDisclaimer,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              }
              final category = categories[index];
              final items = byCategory[category]!;
              return _CategorySection(
                title: category,
                products: items,
                expanded: _expanded.contains(category),
                onToggle: () => setState(() {
                  if (!_expanded.add(category)) _expanded.remove(category);
                }),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.products,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final List<MatchedProduct> products;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title (${products.length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (final product in products) ...[
                    MatchedProductCard(product: product),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
