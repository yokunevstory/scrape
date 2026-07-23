import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/watchlist_repository.dart';
import '../l10n/gen/app_localizations.dart';

/// Кнопка «слежу за товаром» на карточке — тап добавляет/убирает товар из
/// списка отслеживания (см. lib/screens/watchlist_screen.dart). Если товар
/// сматчен между магазинами — будет отслеживаться канонический товар целиком
/// (все предложения), а не только конкретное предложение этого магазина.
class WatchButton extends StatefulWidget {
  const WatchButton({super.key, required this.product});

  final StoreProductRow product;

  @override
  State<WatchButton> createState() => _WatchButtonState();
}

class _WatchButtonState extends State<WatchButton> {
  final _repo = WatchlistRepository();
  bool? _watched;

  @override
  void initState() {
    super.initState();
    _repo.isWatched(widget.product).then((v) {
      if (mounted) setState(() => _watched = v);
    });
  }

  Future<void> _toggle() async {
    final next = !(_watched ?? false);
    setState(() => _watched = next);
    if (next) {
      await _repo.addWatch(widget.product);
    } else {
      await _repo.removeWatch(widget.product);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_watched == null) {
      return const SizedBox(width: 32, height: 32);
    }
    final t = AppLocalizations.of(context)!;
    return IconButton(
      icon: Icon(_watched! ? Icons.bookmark : Icons.bookmark_border),
      color: _watched! ? Theme.of(context).colorScheme.primary : null,
      iconSize: 20,
      constraints: const BoxConstraints(),
      padding: EdgeInsets.zero,
      tooltip: _watched! ? t.tooltipRemoveFromWatch : t.tooltipAddToWatch,
      onPressed: _toggle,
    );
  }
}
