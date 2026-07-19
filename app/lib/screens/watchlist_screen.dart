import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/watchlist_repository.dart';
import '../widgets/matched_product_card.dart';
import '../widgets/product_card.dart';

/// "Слежу за товаром/ценой" — список избранных товаров, чтобы при
/// открытии приложения сразу видеть, если на них появилась акция или упала
/// цена (без пуш-уведомлений — это отдельная задача на будущее). Если товар
/// сматчен между магазинами, показываются предложения из всех магазинов сразу.
class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = WatchlistRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Отслеживаемые товары')),
      body: FutureBuilder<List<WatchlistEntry>>(
        future: repo.fetchWatchlist(),
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
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Пока нет отслеживаемых товаров. Нажмите на значок '
                  'закладки на карточке товара, чтобы добавить его сюда — '
                  'здесь будет видно, если на него появится акция или упадёт цена.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              if (entry.offers.length > 1) {
                return MatchedProductCard(
                  product: MatchedProduct(
                    id: entry.offers.first.productId ?? entry.offers.first.id,
                    canonicalName: entry.offers.first.rawName,
                    brand: null,
                    offers: entry.offers,
                  ),
                  highlighted: entry.isHighlighted,
                );
              }
              return ProductCard(
                product: entry.offers.first,
                isCheapest: false,
                highlighted: entry.isHighlighted,
              );
            },
          );
        },
      ),
    );
  }
}
