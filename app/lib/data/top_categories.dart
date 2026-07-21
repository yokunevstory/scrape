/// Категории и субкатегории — сопоставление по подстроке читаемого пути
/// названий (raw_category_path), не точная таксономия (см. SPEC.md §8.0/§8.2:
/// у Rimi и Barbora категории называются немного по-разному). Подстроки для
/// субкатегорий взяты из реально собранных данных, чтобы тапы точно
/// показывали товары, а не пустой экран.
class SubCategory {
  const SubCategory(this.displayName, this.matchPattern,
      {this.useTopFilter = false, this.orPatterns = const []});
  final String displayName;
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
  const TopCategory(this.displayName, this.matchPattern, this.icon,
      {this.subcategories = const [], this.orPatterns = const []});

  final String displayName;
  final String matchPattern;
  final String icon;
  final List<String> orPatterns;

  /// Если пусто — тап по категории сразу открывает список товаров.
  final List<SubCategory> subcategories;

  List<String> get patternGroup => [matchPattern, ...orPatterns];
}

const topCategories = [
  TopCategory('Молочные продукты', 'Piena produkt', '🥛', subcategories: [
    SubCategory('Молоко', '/Piens/'),
    SubCategory('Кефир, ряженка', 'Kefīrs'),
    SubCategory('Творог', 'Biezpien'),
    SubCategory('Сметана, сливки', 'krējum'),
    SubCategory('Масло, маргарин', 'Sviests'),
  ]),
  TopCategory('Мясо, рыба', 'Gaļa', '🥩', subcategories: [
    SubCategory('Свинина', 'Cūkgaļa'),
    SubCategory('Говядина', 'Liellopa'),
    // Обычные "zivis"/"kulinārij" не годятся — эти слова есть в самом
    // названии родительской категории ("Gaļa, zivis un gatavā kulinārija"),
    // поэтому такой паттерн совпадал бы вообще со всем в разделе (нашли на
    // реальных данных: свинина попадала в "Готовые блюда"). Берём точные
    // названия подразделов. orPatterns — потому что Rimi и Barbora называют
    // те же разделы по-разному ("jūrasveltes" слитно vs "jūras veltes" через
    // пробел, "Pārstrādātās zivis" vs "Zivju produkti") — без альтернативных
    // вариантов рыба у одного из магазинов не находилась вообще.
    SubCategory('Рыба свежая', 'jūrasveltes', orPatterns: ['Svaigās zivis un jūras veltes']),
    SubCategory(
      'Рыба, переработанная и консервы',
      'Pārstrādātās zivis',
      orPatterns: ['jūras produkti un ikri', 'Zivju produkti'],
    ),
  ]),
  TopCategory('Овощи, фрукты', 'Augļi un dārzeņi', '🥦', subcategories: [
    SubCategory('Фрукты, ягоды', '/Augļi'),
    SubCategory('Овощи', '/Dārzeņi'),
  ]),
  TopCategory('Хлеб, выпечка', 'onditorej', '🍞'),
  // "/Gatavā kulinārija/" (со слэшами) — а не просто "kulinārij" — потому
  // что просто "kulinārij" совпадает и с родительской категорией "Gaļa,
  // zivis UN GATAVĀ KULINĀRIJA" целиком (без слэша перед ней), из-за чего
  // сюда попадала вообще вся свинина/рыба. Слэши гарантируют, что это
  // именно отдельный раздел "Gatavā kulinārija", а не часть чужого названия.
  // orPatterns — Barbora называет этот же раздел просто "Kulinārija" (без
  // "Gatavā"), а свой суши/сэндвич-бренд Rimi "Mani Gardumi gatavā kulinārija"
  // не попадает под первый паттерн (нет "/" перед "gatavā").
  TopCategory(
    'Готовые блюда',
    '/Gatavā kulinārija/',
    '🍱',
    orPatterns: ['/Kulinārija/', 'Gardumi gatavā kulinārija'],
  ),
  TopCategory('Бакалея', 'Bakaleja', '🍝', subcategories: [
    SubCategory('Макароны', 'Makaroni'),
    SubCategory('Снеки', 'Uzkodas'),
  ]),
  TopCategory('Напитки', 'Dzērien', '🥤', subcategories: [
    SubCategory('Вода', 'Ūdens'),
  ]),
  TopCategory('Заморозка', 'Sald', '🧊', subcategories: [
    SubCategory('Мороженое', 'Saldējums'),
    SubCategory('Замороженные овощи', 'Saldēti dārzeņi'),
  ]),
  TopCategory('Детские товары', 'bērn', '🍼', subcategories: [
    SubCategory('Подгузники', 'Autiņbiksīt'),
    SubCategory('Детское питание, напитки', 'dzērien', useTopFilter: true),
  ]),
];
