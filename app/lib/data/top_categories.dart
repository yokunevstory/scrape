import '../l10n/gen/app_localizations.dart';

/// Категории и субкатегории — сопоставление по подстроке читаемого пути
/// названий (raw_category_path), не точная таксономия (см. SPEC.md §8.0/§8.2:
/// у Rimi и Barbora категории называются немного по-разному). Подстроки для
/// субкатегорий взяты из реально собранных данных, чтобы тапы точно
/// показывали товары, а не пустой экран.
///
/// [nameKey] — не текст для показа, а идентификатор для categoryLabel() (см.
/// ниже) — реальный текст берётся из AppLocalizations и зависит от текущего
/// языка интерфейса, поэтому здесь он не может быть просто строкой.
class SubCategory {
  const SubCategory(this.nameKey, this.matchPattern,
      {this.useTopFilter = false, this.orPatterns = const []});
  final String nameKey;
  final String matchPattern;

  /// true — фильтровать и по паттерну подкатегории, И по паттерну
  /// родительской категории одновременно. Нужно только когда паттерн
  /// подкатегории сам по себе слишком общий (например, "dzērien" совпадает
  /// и с обычными напитками) — в остальных случаях паттерн подкатегории уже
  /// достаточно точный сам по себе, а лишний AND может сломать совпадение,
  /// если у Rimi/Barbora родительская категория называется по-разному
  /// (см. §8.0/§8.2 — "Bakaleja" vs "Iepakotā pārtika").
  final bool useTopFilter;

  /// Альтернативные варианты паттерна (через ИЛИ) — нужно, когда Rimi и
  /// Barbora называют один и тот же раздел по-разному настолько, что общей
  /// подстроки нет (напр. "jūrasveltes" слитно у Rimi vs "jūras veltes" через
  /// пробел у Barbora). matchPattern + orPatterns вместе — это набор
  /// вариантов, из которых достаточно совпадения любого одного.
  final List<String> orPatterns;

  List<String> get patternGroup => [matchPattern, ...orPatterns];
}

class TopCategory {
  const TopCategory(this.nameKey, this.matchPattern, this.icon,
      {this.subcategories = const [], this.orPatterns = const []});

  final String nameKey;
  final String matchPattern;
  final String icon;
  final List<String> orPatterns;

  /// Если пусто — тап по категории сразу открывает список товаров.
  final List<SubCategory> subcategories;

  List<String> get patternGroup => [matchPattern, ...orPatterns];
}

/// Резолвит nameKey в текст на текущем языке интерфейса — единое место для
/// категорий и подкатегорий (у обеих nameKey — это просто ключи из одного и
/// того же набора catXxx в ARB, см. lib/l10n/app_ru.arb).
String categoryLabel(AppLocalizations t, String nameKey) {
  switch (nameKey) {
    case 'dairy':
      return t.catDairy;
    case 'dairyMilk':
      return t.catDairyMilk;
    case 'dairyKefir':
      return t.catDairyKefir;
    case 'dairyCottage':
      return t.catDairyCottage;
    case 'dairyCream':
      return t.catDairyCream;
    case 'dairyButter':
      return t.catDairyButter;
    case 'meatFish':
      return t.catMeatFish;
    case 'meatPork':
      return t.catMeatPork;
    case 'meatBeef':
      return t.catMeatBeef;
    case 'meatFishFresh':
      return t.catMeatFishFresh;
    case 'meatFishProcessed':
      return t.catMeatFishProcessed;
    case 'produce':
      return t.catProduce;
    case 'produceFruit':
      return t.catProduceFruit;
    case 'produceVeg':
      return t.catProduceVeg;
    case 'bakery':
      return t.catBakery;
    case 'readyMeals':
      return t.catReadyMeals;
    case 'grocery':
      return t.catGrocery;
    case 'groceryPasta':
      return t.catGroceryPasta;
    case 'grocerySnacks':
      return t.catGrocerySnacks;
    case 'drinks':
      return t.catDrinks;
    case 'drinksWater':
      return t.catDrinksWater;
    case 'frozen':
      return t.catFrozen;
    case 'frozenIceCream':
      return t.catFrozenIceCream;
    case 'frozenVeg':
      return t.catFrozenVeg;
    case 'kids':
      return t.catKids;
    case 'kidsDiapers':
      return t.catKidsDiapers;
    case 'kidsFood':
      return t.catKidsFood;
  }
  return nameKey;
}

const topCategories = [
  TopCategory('dairy', 'Piena produkt', '🥛', subcategories: [
    SubCategory('dairyMilk', '/Piens/'),
    SubCategory('dairyKefir', 'Kefīrs'),
    SubCategory('dairyCottage', 'Biezpien'),
    SubCategory('dairyCream', 'krējum'),
    SubCategory('dairyButter', 'Sviests'),
  ]),
  TopCategory('meatFish', 'Gaļa', '🥩', subcategories: [
    SubCategory('meatPork', 'Cūkgaļa'),
    SubCategory('meatBeef', 'Liellopa'),
    // Обычные "zivis"/"kulinārij" не годятся — эти слова есть в самом
    // названии родительской категории ("Gaļa, zivis un gatavā kulinārija"),
    // поэтому такой паттерн совпадал бы вообще со всем в разделе (нашли на
    // реальных данных: свинина попадала в "Готовые блюда"). Берём точные
    // названия подразделов. orPatterns — потому что Rimi и Barbora называют
    // те же разделы по-разному ("jūrasveltes" слитно vs "jūras veltes" через
    // пробел, "Pārstrādātās zivis" vs "Zivju produkti") — без альтернативных
    // вариантов рыба у одного из магазинов не находилась вообще.
    SubCategory('meatFishFresh', 'jūrasveltes', orPatterns: ['Svaigās zivis un jūras veltes']),
    SubCategory(
      'meatFishProcessed',
      'Pārstrādātās zivis',
      orPatterns: ['jūras produkti un ikri', 'Zivju produkti'],
    ),
  ]),
  TopCategory('produce', 'Augļi un dārzeņi', '🥦', subcategories: [
    SubCategory('produceFruit', '/Augļi'),
    SubCategory('produceVeg', '/Dārzeņi'),
  ]),
  TopCategory('bakery', 'onditorej', '🍞'),
  // "/Gatavā kulinārija/" (со слэшами) — а не просто "kulinārij" — потому
  // что просто "kulinārij" совпадает и с родительской категорией "Gaļa,
  // zivis UN GATAVĀ KULINĀRIJA" целиком (без слэша перед ней), из-за чего
  // сюда попадала вообще вся свинина/рыба. Слэши гарантируют, что это
  // именно отдельный раздел "Gatavā kulinārija", а не часть чужого названия.
  // orPatterns — Barbora называет этот же раздел просто "Kulinārija" (без
  // "Gatavā"), а свой суши/сэндвич-бренд Rimi "Mani Gardumi gatavā kulinārija"
  // не попадает под первый паттерн (нет "/" перед "gatavā").
  TopCategory(
    'readyMeals',
    '/Gatavā kulinārija/',
    '🍱',
    orPatterns: ['/Kulinārija/', 'Gardumi gatavā kulinārija'],
  ),
  TopCategory('grocery', 'Bakaleja', '🍝', subcategories: [
    SubCategory('groceryPasta', 'Makaroni'),
    SubCategory('grocerySnacks', 'Uzkodas'),
  ]),
  TopCategory('drinks', 'Dzērien', '🥤', subcategories: [
    SubCategory('drinksWater', 'Ūdens'),
  ]),
  TopCategory('frozen', 'Sald', '🧊', subcategories: [
    SubCategory('frozenIceCream', 'Saldējums'),
    SubCategory('frozenVeg', 'Saldēti dārzeņi'),
  ]),
  TopCategory('kids', 'bērn', '🍼', subcategories: [
    SubCategory('kidsDiapers', 'Autiņbiksīt'),
    SubCategory('kidsFood', 'dzērien', useTopFilter: true),
  ]),
];
