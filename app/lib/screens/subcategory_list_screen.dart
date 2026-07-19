import 'package:flutter/material.dart';

import '../data/top_categories.dart';
import 'category_products_screen.dart';

class SubcategoryListScreen extends StatelessWidget {
  const SubcategoryListScreen({super.key, required this.category});

  final TopCategory category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.displayName)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: category.subcategories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final sub = category.subcategories[index];
          return Card(
            child: ListTile(
              title: Text(sub.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryProductsScreen(
                    title: sub.displayName,
                    matchPatterns: sub.useTopFilter
                        ? [category.matchPattern, sub.matchPattern]
                        : [sub.matchPattern],
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
