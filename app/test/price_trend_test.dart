import 'package:flutter_test/flutter_test.dart';

import 'package:app/data/models.dart';

StoreProductRow _row({required double packagePrice, double? priceWeekAgo}) {
  return StoreProductRow(
    id: 'p1',
    productId: null,
    storeDisplayName: 'Rimi',
    storeSlug: 'rimi',
    rawName: 'Piens',
    categoryPath: null,
    packagePrice: packagePrice,
    regularPrice: null,
    unitPrice: null,
    unitType: null,
    isPromo: false,
    imageUrl: null,
    sourceUrl: '',
    priceWeekAgo: priceWeekAgo,
  );
}

void main() {
  test('priceTrend is none when priceWeekAgo is not loaded yet', () {
    expect(_row(packagePrice: 1.99).priceTrend, PriceTrend.none);
  });

  test('priceTrend is down when the price dropped since a week ago', () {
    expect(_row(packagePrice: 1.79, priceWeekAgo: 1.99).priceTrend, PriceTrend.down);
  });

  test('priceTrend is up when the price rose since a week ago', () {
    expect(_row(packagePrice: 2.19, priceWeekAgo: 1.99).priceTrend, PriceTrend.up);
  });

  test('priceTrend is none when the price is unchanged', () {
    expect(_row(packagePrice: 1.99, priceWeekAgo: 1.99).priceTrend, PriceTrend.none);
  });

  test('copyWithPriceWeekAgo preserves the rest of the row', () {
    final original = _row(packagePrice: 1.99);
    final withTrend = original.copyWithPriceWeekAgo(2.49);

    expect(withTrend.priceWeekAgo, 2.49);
    expect(withTrend.priceTrend, PriceTrend.down);
    expect(withTrend.id, original.id);
    expect(withTrend.packagePrice, original.packagePrice);
  });
}
