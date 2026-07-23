import 'package:flutter/material.dart';

import '../data/product_repository.dart';
import '../l10n/gen/app_localizations.dart';
import '../widgets/product_results_list.dart';

class CategoryProductsScreen extends StatelessWidget {
  const CategoryProductsScreen({
    super.key,
    required this.title,
    required this.matchPatterns,
  });

  final String title;
  final List<List<String>> matchPatterns;

  @override
  Widget build(BuildContext context) {
    final repo = ProductRepository();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ProductResultsList(
        future: repo.fetchByCategory(matchPatterns),
        emptyText: AppLocalizations.of(context)!.categoryEmptyText,
      ),
    );
  }
}
