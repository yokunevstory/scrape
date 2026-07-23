import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.promotionsTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: mockPromos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final promo = mockPromos[index];
          final attribution =
              t.attributionFormat(promo.storeSlug == 'barbora' ? 'Barbora' : promo.store);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.deal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '-${promo.discountPercent}%',
                      style: TextStyle(
                        color: colors.onDeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(promo.name,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          '${promo.store} · $attribution',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.lowestPrice30d(promo.lowestPrice30d.toStringAsFixed(2)),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${promo.regularPrice.toStringAsFixed(2)} €',
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${promo.promoPrice.toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.savings,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
