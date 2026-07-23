import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/shopping_list_repository.dart';
import '../l10n/gen/app_localizations.dart';

/// Кнопка «в список покупок» на карточке — тап добавляет/убирает товар из
/// списка (см. lib/screens/basket_screen.dart). Если товар сматчен между
/// магазинами — в список попадает канонический товар целиком, чтобы на
/// экране списка сразу было видно, где он дешевле.
class AddToListButton extends StatefulWidget {
  const AddToListButton({super.key, required this.product, this.onChanged});

  final StoreProductRow product;
  /// Вызывается после добавления/удаления — например, чтобы экран списка
  /// покупок сразу обновил отображаемые позиции.
  final VoidCallback? onChanged;

  @override
  State<AddToListButton> createState() => _AddToListButtonState();
}

class _AddToListButtonState extends State<AddToListButton> {
  final _repo = ShoppingListRepository();
  bool? _inList;

  @override
  void initState() {
    super.initState();
    _repo.contains(widget.product).then((v) {
      if (mounted) setState(() => _inList = v);
    });
  }

  Future<void> _toggle() async {
    final next = !(_inList ?? false);
    setState(() => _inList = next);
    if (next) {
      await _repo.addProduct(widget.product);
    } else {
      await _repo.removeProduct(widget.product);
    }
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_inList == null) {
      return const SizedBox(width: 32, height: 32);
    }
    final t = AppLocalizations.of(context)!;
    return IconButton(
      icon: Icon(_inList! ? Icons.shopping_cart : Icons.add_shopping_cart_outlined),
      color: _inList! ? Theme.of(context).colorScheme.primary : null,
      iconSize: 20,
      constraints: const BoxConstraints(),
      padding: EdgeInsets.zero,
      tooltip: _inList! ? t.tooltipRemoveFromList : t.tooltipAddToList,
      onPressed: _toggle,
    );
  }
}
