import 'package:flutter/material.dart';

import '../data/top_categories.dart';
import '../theme/app_theme.dart';
import 'category_products_screen.dart';
import 'matched_products_screen.dart';
import 'search_screen.dart';
import 'subcategory_list_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchBar(
                hintText: 'Найти товар, например «кетчуп»',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
                onSubmitted: (query) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query)),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _MatchedProductsBanner(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = topCategories[index];
                  return _CategoryCard(category: category);
                },
                childCount: topCategories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});
  final TopCategory category;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => category.subcategories.isEmpty
                ? CategoryProductsScreen(
                    title: category.displayName,
                    matchPatterns: [category.matchPattern],
                  )
                : SubcategoryListScreen(category: category),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                category.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchedProductsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      color: colors.savingsContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MatchedProductsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.sync_alt, color: colors.savings),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сопоставленные товары',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: colors.savings, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Один и тот же товар в Rimi и Maxima — рядом',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.savings,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.savings),
            ],
          ),
        ),
      ),
    );
  }
}
