import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/product_repository.dart';
import '../widgets/matched_product_card.dart';

/// Товары, гарантированно сопоставленные между Rimi и Maxima (Barbora) —
/// scraper/match_products.py, SPEC.md §8.2. В отличие от обычного поиска/
/// категорий, здесь показываются именно предложения ОДНОГО И ТОГО ЖЕ товара
/// из разных магазинов рядом, с посчитанной экономией. Сгруппировано по
/// категориям, как и обычный каталог.
class MatchedProductsScreen extends StatelessWidget {
  const MatchedProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ProductRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Сопоставленные товары')),
      body: FutureBuilder<List<MatchedProduct>>(
        future: repo.fetchMatchedProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Не удалось загрузить: ${snapshot.error}'),
              ),
            );
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Пока нет сопоставленных товаров — скрапер и сопоставление '
                  'ещё не проходили по всему ассортименту.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final byCategory = <String, List<MatchedProduct>>{};
          for (final p in products) {
            byCategory.putIfAbsent(p.topCategory ?? 'Другое', () => []).add(p);
          }
          final categories = byCategory.keys.toList()..sort();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              if (index == categories.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Товары сопоставлены автоматически по названию, бренду и '
                    'весу/объёму упаковки — в редких случаях сопоставление '
                    'может быть неточным. Цены собраны из открытых источников.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              }
              final category = categories[index];
              final items = byCategory[category]!;
              return _CategorySection(title: category, products: items);
            },
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.title, required this.products});

  final String title;
  final List<MatchedProduct> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            '$title (${products.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (final product in products) ...[
          MatchedProductCard(product: product),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
