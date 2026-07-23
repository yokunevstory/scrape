import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import 'add_to_list_button.dart';
import 'watch_button.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.isCheapest,
    this.highlighted = false,
    this.onAddToListChanged,
  });

  final StoreProductRow product;
  final bool isCheapest;
  /// Вызывается после добавления/удаления товара из списка покупок через
  /// кнопку-корзину на карточке (см. AddToListButton.onChanged).
  final VoidCallback? onAddToListChanged;
  /// Рамка-выделение — акция или упавшая цена на отслеживаемый товар
  /// (см. WatchlistEntry.isHighlighted). В будущем сюда же добавится
  /// пуш-уведомление.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppLocalizations.of(context)!;
    final sizeLabel = product.packageSizeLabel(t);

    return Card(
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.deal, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _placeholder(context),
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : _placeholder(context),
                      )
                    : _placeholder(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.rawName,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sizeLabel != null
                        ? '${product.storeDisplayName} · ${product.attribution(t)} · '
                            '$sizeLabel'
                        : '${product.storeDisplayName} · ${product.attribution(t)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (isCheapest)
                        _Badge(
                          text: t.badgeCheapestPerUnit,
                          background: colors.savingsContainer,
                          foreground: colors.savings,
                        ),
                      if (product.isPromo)
                        _Badge(
                          text: t.badgePromo,
                          background: colors.deal,
                          foreground: colors.onDeal,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WatchButton(product: product),
                const SizedBox(height: 4),
                AddToListButton(product: product, onChanged: onAddToListChanged),
              ],
            ),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (product.regularPrice != null)
                  Text(
                    '${product.regularPrice!.toStringAsFixed(2)} €',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  '${product.packagePrice.toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCheapest
                            ? colors.savings
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                if (product.unitPrice != null)
                  Text(
                    '${product.unitPrice!.toStringAsFixed(2)} €/${product.unitLabel(t)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.background, required this.foreground});

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}
