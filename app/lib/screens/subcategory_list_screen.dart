import 'package:flutter/material.dart';

import '../data/top_categories.dart';
import '../l10n/gen/app_localizations.dart';
import 'category_products_screen.dart';

class SubcategoryListScreen extends StatelessWidget {
  const SubcategoryListScreen({super.key, required this.category});

  final TopCategory category;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(categoryLabel(t, category.nameKey))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: category.subcategories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final sub = category.subcategories[index];
          final subName = categoryLabel(t, sub.nameKey);
          return Card(
            child: ListTile(
              title: Text(subName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryProductsScreen(
                    title: subName,
                    matchPatterns: sub.useTopFilter
                        ? [category.patternGroup, sub.patternGroup]
                        : [sub.patternGroup],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
