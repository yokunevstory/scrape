import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/product_repository.dart';
import '../widgets/product_results_list.dart';

/// Поиск товаров по названию across обоих магазинов (Rimi + Barbora) —
/// ядро ценности приложения: сразу видно, где дешевле.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery ?? '');
  final _repo = ProductRepository();
  Future<List<StoreProductRow>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _runSearch(widget.initialQuery!);
    }
  }

  void _runSearch(String query) {
    setState(() {
      _query = query;
      _future = _repo.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery == null,
          decoration: const InputDecoration(
            hintText: 'Найти товар, например «кетчуп»',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _runSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _runSearch(_controller.text),
          ),
        ],
      ),
      body: _future == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Введите название товара, например «кетчуп» или «piens» — '
                  'покажем предложения из всех подключённых магазинов, '
                  'отсортированные по цене за единицу.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ProductResultsList(
              future: _future!,
              emptyText: 'Ничего не нашлось по запросу «$_query». '
                  'Возможно, скрапер ещё не проходил по этим товарам.',
            ),
    );
  }
}
