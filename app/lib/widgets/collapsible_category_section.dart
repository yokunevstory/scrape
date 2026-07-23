import 'package:flutter/material.dart';

/// Свёрнутая по умолчанию секция-категория со списком элементов — общий
/// паттерн для экранов "Сопоставленные товары" и "Акции": когда категорий
/// много, а часть из них неинтересна пользователю (например, алкоголь),
/// свёрнутые заголовки не мешают пролистывать до нужной.
class CollapsibleCategorySection<T> extends StatelessWidget {
  const CollapsibleCategorySection({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
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
                      '$title (${items.length})',
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
                  for (final item in items) ...[
                    itemBuilder(context, item),
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
