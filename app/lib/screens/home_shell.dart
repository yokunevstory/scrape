import 'package:flutter/material.dart';

import 'basket_screen.dart';
import 'catalog_screen.dart';
import 'profile_screen.dart';
import 'promotions_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _basketKey = GlobalKey<BasketScreenState>();
  static const _basketTabIndex = 2;

  late final _screens = [
    const CatalogScreen(),
    const SearchScreen(),
    BasketScreen(key: _basketKey),
    const PromotionsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          // Вкладки живут в IndexedStack и не пересоздаются при переключении,
          // поэтому "Список" сам не узнает о товарах, добавленных корзиной
          // на других вкладках (каталог, поиск) — обновляем явно при заходе.
          if (value == _basketTabIndex) {
            _basketKey.currentState?.reload();
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: 'Каталог'),
          NavigationDestination(icon: Icon(Icons.compare_arrows), label: 'Поиск'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Список'),
          NavigationDestination(icon: Icon(Icons.local_offer_outlined), label: 'Акции'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Профиль'),
        ],
      ),
    );
  }
}
