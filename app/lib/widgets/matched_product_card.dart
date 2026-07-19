import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'add_to_list_button.dart';

/// Карточка одного и того же товара с предложениями из разных магазинов
/// рядом друг с другом — сопоставление из scraper/match_products.py
/// (SPEC.md §8.2), не приблизительный поиск по категории.
class MatchedProductCard extends StatelessWidget {
  const MatchedProductCard({super.key, required this.product, this.highlighted = false});

  final MatchedProduct product;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cheapestId = product.cheapest?.id;
    final savings = product.savings;

    return Card(
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.deal, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.canonicalName,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (product.offers.isNotEmpty)
                  AddToListButton(product: product.offers.first),
              ],
            ),
            const SizedBox(height: 8),
            for (final offer in product.offers) ...[
              _OfferRow(offer: offer, isCheapest: offer.id == cheapestId),
              const SizedBox(height: 6),
            ],
            if (savings != null) ...[
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.savingsContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Экономия ${savings.toStringAsFixed(2)} €, если выбрать '
                  '${product.cheapest!.storeDisplayName}',
                  style: TextStyle(color: colors.savings, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.isCheapest});

  final StoreProductRow offer;
  final bool isCheapest;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 40,
            child: offer.imageUrl != null
                ? Image.network(
                    offer.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  )
                : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${offer.storeDisplayName} · ${offer.attribution}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          '${offer.packagePrice.toStringAsFixed(2)} €',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isCheapest ? colors.savings : Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}
