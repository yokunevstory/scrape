import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/product_repository.dart';
import '../l10n/gen/app_localizations.dart';
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
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery == null,
          decoration: InputDecoration(
            hintText: t.searchHint,
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
                  t.searchEmptyHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ProductResultsList(
              future: _future!,
              emptyText: t.searchNoResults(_query),
            ),
    );
  }
}
