/// Заглушечные (моковые) данные для экрана акций — пока не заменены на
/// реальные (SPEC.md §9: promotions).
library;

class MockPromo {
  const MockPromo({
    required this.name,
    required this.store,
    required this.attribution,
    required this.promoPrice,
    required this.regularPrice,
    required this.lowestPrice30d,
    required this.discountPercent,
  });

  final String name;
  final String store;
  final String attribution;
  final double promoPrice;
  final double regularPrice;
  final double lowestPrice30d;
  final int discountPercent;
}

const mockPromos = [
  MockPromo(
    name: 'Sviests 82.5% 200g',
    store: 'Rimi',
    attribution: 'по данным Rimi',
    promoPrice: 1.29,
    regularPrice: 2.99,
    lowestPrice30d: 1.29,
    discountPercent: 57,
  ),
  MockPromo(
    name: 'Laša fileja, kg',
    store: 'Rimi',
    attribution: 'по данным Rimi',
    promoPrice: 12.99,
    regularPrice: 22.99,
    lowestPrice30d: 12.99,
    discountPercent: 43,
  ),
  MockPromo(
    name: 'Siers Tilzītes 43% kg',
    store: 'Maxima',
    attribution: 'по данным Barbora',
    promoPrice: 5.99,
    regularPrice: 8.99,
    lowestPrice30d: 5.99,
    discountPercent: 33,
  ),
];
