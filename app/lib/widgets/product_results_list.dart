import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'product_card.dart';

/// Список товаров с сортировкой (цена/цена за ед./вес-объём), индикатором
/// загрузки/ошибки и дисклеймером об открытых источниках (SPEC.md §5 п.8) —
/// переиспользуется и категориями, и поиском.
class ProductResultsList extends StatefulWidget {
  const ProductResultsList({super.key, required this.future, this.emptyText});

  final Future<List<StoreProductRow>> future;
  final String? emptyText;

  @override
  State<ProductResultsList> createState() => _ProductResultsListState();
}

class _ProductResultsListState extends State<ProductResultsList> {
  ProductSort _sort = ProductSort.unitPriceAsc;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return FutureBuilder<List<StoreProductRow>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t.loadErrorProducts('${snapshot.error}')),
            ),
          );
        }
        final products = <StoreProductRow>[...snapshot.data ?? []];
        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(widget.emptyText ?? t.defaultEmptyText),
            ),
          );
        }

        products.sort(_sort.comparator);

        final cheapestUnitPrice = products
            .where((p) => p.unitPrice != null)
            .map((p) => p.unitPrice!)
            .fold<double?>(null, (min, v) => min == null || v < min ? v : min);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ProductSort>(
                      initialValue: _sort,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t.sortLabel,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: ProductSort.values
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.label(t))))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == products.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        t.sourceDisclaimer,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    );
                  }
                  final product = products[index];
                  return ProductCard(
                    product: product,
                    isCheapest: product.unitPrice != null &&
                        cheapestUnitPrice != null &&
                        product.unitPrice == cheapestUnitPrice,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
