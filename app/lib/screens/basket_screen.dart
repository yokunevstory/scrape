import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/product_repository.dart';
import '../data/shopping_list_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/matched_product_card.dart';
import '../widgets/product_card.dart';

/// Список покупок — работает как отслеживаемые товары: позиции добавляются
/// значком корзины прямо с карточки товара (где угодно в приложении), а
/// здесь сразу видно, где каждая позиция дешевле. Плюс поиск, похожий на
/// основной, чтобы добавлять товары не выходя с этого экрана, и общий итог
/// сравнения по магазинам (SPEC.md §6, сценарий Б).
class BasketScreen extends StatefulWidget {
  const BasketScreen({super.key});

  @override
  State<BasketScreen> createState() => BasketScreenState();
}

/// Публичный State (без ведущего "_") — чтобы HomeShell мог получить его
/// через GlobalKey и вызвать reload() при переключении на вкладку "Список".
/// Экраны нижней навигации живут в IndexedStack и не пересоздаются при
/// переключении вкладок, поэтому без этого список не увидит товары,
/// добавленные корзиной с других вкладок (каталог, поиск), пока сам не
/// пересоздастся (т.е. никогда).
class BasketScreenState extends State<BasketScreen> {
  final _listRepo = ShoppingListRepository();
  final _searchRepo = ProductRepository();
  final _searchController = TextEditingController();

  List<(String, WatchlistEntry)> _items = [];
  bool _loading = true;
  bool _showSplit = false;
  bool _searchExpanded = false;
  Future<List<StoreProductRow>>? _searchFuture;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    final items = await _listRepo.fetchItems();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _removeItem(String itemId) async {
    await _listRepo.removeItem(itemId);
    await reload();
  }

  /// Для режима "разбивка по магазинам" — какой магазин выгоднее для КАЖДОЙ
  /// позиции по отдельности (а не общий итог), сгруппировано по магазину.
  /// Чтобы в магазине можно было открыть список и увидеть только то, что
  /// нужно купить именно здесь, без альтернативной цены другого магазина.
  Map<String, List<(String itemId, StoreProductRow offer)>> _groupByCheapestStore() {
    final groups = <String, List<(String, StoreProductRow)>>{};
    for (final (itemId, entry) in _items) {
      if (entry.offers.isEmpty) continue;
      final cheapest = entry.offers.reduce((a, b) => a.packagePrice <= b.packagePrice ? a : b);
      groups.putIfAbsent(cheapest.storeSlug, () => []).add((itemId, cheapest));
    }
    return groups;
  }

  void _runSearch(String query) {
    if (query.trim().isEmpty) return;
    setState(() => _searchFuture = _searchRepo.search(query));
  }

  Widget _buildGroupedByStore(BuildContext context) {
    final groups = _groupByCheapestStore();
    final slugs = groups.keys.toList()
      ..sort((a, b) => groups[a]!.first.$2.storeDisplayName
          .compareTo(groups[b]!.first.$2.storeDisplayName));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: slugs.length,
      itemBuilder: (context, index) {
        final slug = slugs[index];
        final storeItems = groups[slug]!;
        final storeName = storeItems.first.$2.storeDisplayName;
        final subtotal = storeItems.fold<double>(0, (sum, e) => sum + e.$2.packagePrice);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$storeName (${storeItems.length})',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${subtotal.toStringAsFixed(2)} €',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(),
                  for (final (itemId, offer) in storeItems)
                    _StoreItemTile(offer: offer, onRemove: () => _removeItem(itemId)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final summary = BasketSummary.fromEntries(_items.map((e) => e.$2).toList());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Список покупок'),
        actions: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.close : Icons.search),
            tooltip: 'Добавить товар поиском',
            onPressed: () => setState(() {
              _searchExpanded = !_searchExpanded;
              if (!_searchExpanded) _searchFuture = null;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Найти товар, например «кетчуп»',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Найти',
                    onPressed: () => _runSearch(_searchController.text),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
              ),
            ),
            SizedBox(
              height: 260,
              child: _searchFuture == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Введите название товара и нажмите на значок корзины у '
                          'нужного результата — он сразу попадёт в список ниже.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : FutureBuilder<List<StoreProductRow>>(
                      future: _searchFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Ошибка поиска: ${snapshot.error}'));
                        }
                        final results = snapshot.data ?? [];
                        if (results.isEmpty) {
                          return const Center(child: Text('Ничего не нашлось.'));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => ProductCard(
                            product: results[index],
                            isCheapest: false,
                            onAddToListChanged: reload,
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Список пуст. Нажмите на значок корзины на карточке '
                            'товара (в поиске, категориях или здесь через лупу), '
                            'чтобы добавить его сюда.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _showSplit
                        ? _buildGroupedByStore(context)
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final (itemId, entry) = _items[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: entry.offers.length > 1
                                        ? MatchedProductCard(
                                            product: MatchedProduct(
                                              id: entry.offers.first.productId ??
                                                  entry.offers.first.id,
                                              canonicalName: entry.offers.first.rawName,
                                              brand: null,
                                              offers: entry.offers,
                                            ),
                                            highlighted: entry.isHighlighted,
                                          )
                                        : ProductCard(
                                            product: entry.offers.first,
                                            isCheapest: false,
                                            highlighted: entry.isHighlighted,
                                          ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Убрать из списка',
                                    onPressed: () => _removeItem(itemId),
                                  ),
                                ],
                              );
                            },
                          ),
          ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Builder(
                builder: (context) {
                  final best = summary.bestSingleStore;
                  if (best == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Ничего из списка не нашлось в текущих данных магазинов.',
                        ),
                      ),
                    );
                  }
                  final splitSavings = best.value - summary.splitTotal;

                  return Card(
                    color: colors.savingsContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_showSplit) ...[
                            Text(
                              'Дешевле всего купить всё в '
                              '${summary.storeDisplayName(best.key)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${summary.foundCountByStore[best.key]} из '
                              '${summary.totalItems} позиций найдено',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${best.value.toStringAsFixed(2)} €',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: colors.savings,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ] else ...[
                            Text(
                              'Разбивка по магазинам (${summary.splitStoreCount})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${summary.splitTotal.toStringAsFixed(2)} €',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: colors.savings,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (splitSavings > 0.01) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Экономия ещё ${splitSavings.toStringAsFixed(2)} € — '
                                'но ${summary.splitStoreCount} '
                                '${summary.splitStoreCount == 1 ? "магазин" : "магазина"} '
                                'вместо одного',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => setState(() => _showSplit = !_showSplit),
                            child: Text(
                              _showSplit
                                  ? 'Показать вариант «один магазин»'
                                  : 'А если по разным магазинам?',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Цены собраны из открытых источников и могут отличаться '
                            'от актуальной цены в конкретном магазине.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Компактная строка товара для группировки по магазинам — только имя и
/// цена именно в этом магазине, без сравнения с другим (в отличие от
/// ProductCard/MatchedProductCard) — по месту в магазине альтернативная
/// цена не нужна, нужен просто список того, что покупать здесь.
class _StoreItemTile extends StatelessWidget {
  const _StoreItemTile({required this.offer, required this.onRemove});

  final StoreProductRow offer;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
              offer.rawName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${offer.packagePrice.toStringAsFixed(2)} €',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 20,
            tooltip: 'Убрать из списка',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
