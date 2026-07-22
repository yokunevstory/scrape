"""
Первая версия сопоставления одного и того же товара между Rimi и Barbora
(SPEC.md §8.2). EAN/штрихкод ни один из магазинов не отдаёт в открытых
данных, поэтому используем fuzzy-сопоставление: похожесть названия (после
нормализации) + близкий вес/объём упаковки, в пределах одной верхнеуровневой
категории (чтобы не сравнивать вообще всё со всем).

Это НЕ окончательное решение задачи, а начальный проход — часть найденных
совпадений могут быть ошибочными, часть реальных совпадений не найдутся
(разное написание бренда, разная фасовка и т.п.). Результат стоит проверить
глазами перед тем как полагаться на него в проде.

Использование:
    python match_products.py --env-file .env --threshold 0.55
"""

from __future__ import annotations

import argparse
import difflib
import re

import requests

from supabase_writer import SupabaseConfig, _headers, _request_with_retry

_SIZE_TOKEN_RE = re.compile(
    r"\b\d+[.,]?\d*\s*(kg|g|ml|l|gab\.?|proc\.?|%)\b", re.IGNORECASE
)
_NON_WORD_RE = re.compile(r"[^\w\s]", re.UNICODE)


def normalize_name(name: str, strip_words: set[str] | None = None) -> str:
    name = name.lower()
    name = _SIZE_TOKEN_RE.sub(" ", name)
    name = _NON_WORD_RE.sub(" ", name)
    words = name.split()
    if strip_words:
        words = [w for w in words if w not in strip_words]
    return " ".join(words)


# Общие слова категории/описания, которые не могут быть брендом — оба
# магазина пишут название в формате «<категория> <БРЕНД> <вкус/описание>
# <вес>», поэтому первое слово с заглавной буквы, которого нет в этом списке,
# и есть бренд-кандидат. Это резервный вариант на случай, если сам магазин
# не отдаёт бренд в структурированном виде (у Rimi так почти всегда).
_GENERIC_WORDS = {
    "biezpiena", "biezpiens", "biezp", "sieriņš", "sieriņi", "sier",
    "kefīrs", "kefīra", "piens", "pieniņš", "rūgušpiens", "paniņas",
    "dzērieni", "dzēriens", "skābais", "saldais", "krējums", "margarīns",
    "sviests", "ūdens", "gāzēts", "negāzēts", "makaroni", "maize",
    "maizītes", "uzkodas", "des", "gaļa", "cūkgaļa", "liellopa",
    "kulinārija", "pastas", "picas", "saldējums", "un", "ar", "bez", "no",
    "vai", "garšu", "garšas", "pildījums", "glazēts", "glazēti", "svaigi",
    "cepta", "cepts", "laktozes", "lakt", "avota", "dabīgais", "minerālūdens",
}

# В отличие от _GENERIC_WORDS (используется только для угадывания бренда),
# этот список — слова, которые можно убрать перед сравнением похожести
# названий, не потеряв смысл. Категорийные слова (piens/kefīrs/krējums и
# т.п.) сюда НЕ входят: это разные типы товара, кефир не должен совпадать
# с молоком только потому, что оба — "молочный продукт" (реальный баг,
# найденный в первом прогоне).
_FILLER_WORDS = {"un", "ar", "bez", "no", "vai", "garšu", "garšas", "laktozes", "lakt"}


def guess_brand(raw_name: str) -> str | None:
    """Резервное извлечение бренда из текста названия, если магазин не
    отдал его отдельным полем (см. комментарий у _GENERIC_WORDS)."""
    words = re.findall(r"[A-Za-zĀ-ž]+", raw_name)
    for word in words:
        if word[0].isupper() and word.lower() not in _GENERIC_WORDS and len(word) > 2:
            return word
    return None


def carbonation_conflicts(name_a: str, name_b: str) -> bool:
    """"negāzēts" содержит "gāzēts" как подстроку, поэтому обычное сравнение
    похожести не отличает газированную воду от негазированной — нашли на
    реальных данных (Rimi/Barbora, категория "Dzērieni"). Проверяем отдельно,
    как целое слово."""
    words_a = set(re.findall(r"\w+", name_a.lower()))
    words_b = set(re.findall(r"\w+", name_b.lower()))
    a_gas = "gāzēts" in words_a
    a_no_gas = "negāzēts" in words_a
    b_gas = "gāzēts" in words_b
    b_no_gas = "negāzēts" in words_b
    return (a_gas and b_no_gas) or (a_no_gas and b_gas)


_PROTEIN_GROUPS: list[set[str]] = [
    {"cūkgaļa", "cūkgaļas", "cūkas", "cūka"},
    {"liellopa", "liellopu", "liellops", "teļa", "teļš"},
    {"vistas", "vista"},
    {"tītara", "tītars"},
    {"pīles", "pīle"},
    {"lasis", "laša", "lašu"},
    {"siļķe", "siļķes"},
    {"tuncis", "tunča"},
]


def protein_conflicts(name_a: str, name_b: str) -> bool:
    """Разные виды мяса/рыбы с похожей общей частью названия ("... fileja
    kg") иначе выглядят как один товар — нашли на реальных данных: лосось
    ("Atlantijas laša fileja kg") сматчился с говядиной ("Liellopa fileja
    kg") только по общим словам "fileja kg", ratio 0.75. Если у обеих
    сторон есть явный признак вида мяса/рыбы и они из разных групп —
    считаем конфликтом, даже если остальной текст совпадает."""
    words_a = set(re.findall(r"\w+", name_a.lower()))
    words_b = set(re.findall(r"\w+", name_b.lower()))
    groups_a = {i for i, g in enumerate(_PROTEIN_GROUPS) if g & words_a}
    groups_b = {i for i, g in enumerate(_PROTEIN_GROUPS) if g & words_b}
    if not groups_a or not groups_b:
        return False
    return groups_a.isdisjoint(groups_b)


_PERCENT_RE = re.compile(r"(\d+[.,]?\d*)\s*%")


def fat_percent_conflicts(name_a: str, name_b: str) -> bool:
    """Сметана/творог/молоко одного бренда и объёма часто выпускаются в
    нескольких вариантах жирности (12% vs 25% и т.п.) — это разные товары,
    но обычная похожесть текста их не отличает, если остальные слова
    совпадают (нашли на реальных данных: "Baltais 12%" вместо "BALTAIS
    25%" получили похожесть 0.94). Сравниваем явно указанные проценты."""
    pcts_a = {float(m.replace(",", ".")) for m in _PERCENT_RE.findall(name_a)}
    pcts_b = {float(m.replace(",", ".")) for m in _PERCENT_RE.findall(name_b)}
    if not pcts_a or not pcts_b:
        return False
    return pcts_a.isdisjoint(pcts_b)


def brands_conflict(brand_a: str | None, brand_b: str | None) -> bool:
    """True, если у ОБЕИХ сторон указан бренд и они явно разные — тогда это
    не один и тот же товар, независимо от похожести названия (см. обсуждение
    в чате: "Alma" и "POLS" с одинаковым вкусом — разные бренды)."""
    if not brand_a or not brand_b:
        return False  # нет данных с одной из сторон — не блокируем по бренду
    a, b = brand_a.strip().lower(), brand_b.strip().lower()
    return a != b and a not in b and b not in a


def compute_size(item: dict) -> float | None:
    unit_price = item.get("unit_price")
    unit_type = item.get("unit_type")
    if not unit_price or unit_type == "gab":
        return None
    return item["package_price"] / unit_price


def has_conflict(a: dict, b: dict, size_tolerance: float) -> bool:
    """True — пара точно НЕ один и тот же товар (конфликт бренда/газации/
    жирности/вида мяса-рыбы или размера упаковки), независимо от похожести
    названий. Отдельно от расчёта похожести — раньше конфликт и "просто
    непохоже" оба возвращали 0.0 одной функцией, из-за чего сравнение
    товара сразу с НЕСКОЛЬКИМИ представителями группы (см. main(), Фаза A)
    могло взять похожесть с представителем, который просто не упомянул
    жирность в названии, и пропустить реальный конфликт с другим
    представителем той же группы, где жирность указана."""
    brand_a = a.get("brand") or guess_brand(a["raw_name"])
    brand_b = b.get("brand") or guess_brand(b["raw_name"])
    if brands_conflict(brand_a, brand_b):
        return True
    if carbonation_conflicts(a["raw_name"], b["raw_name"]):
        return True
    if fat_percent_conflicts(a["raw_name"], b["raw_name"]):
        return True
    if protein_conflicts(a["raw_name"], b["raw_name"]):
        return True
    size_a, size_b = compute_size(a), compute_size(b)
    if size_a and size_b:
        diff = abs(size_a - size_b) / max(size_a, size_b)
        if diff > size_tolerance:
            return True
    return False


def name_similarity(a: dict, b: dict) -> float:
    """Похожесть названий (0..1) БЕЗ проверки конфликтов — вызывать только
    после has_conflict() == False. Убираем бренд из названий перед
    сравнением — иначе одинаковый бренд + разный вкус ("Kārums ar
    magonēm" vs "KĀRUMS vaniļas") может набрать высокую похожесть только
    за счёт общих слов бренда и категории, а не вкуса."""
    brand_a = a.get("brand") or guess_brand(a["raw_name"])
    brand_b = b.get("brand") or guess_brand(b["raw_name"])
    strip_words = _FILLER_WORDS | {w.lower() for w in (brand_a, brand_b) if w}
    name_a = normalize_name(a["raw_name"], strip_words)
    name_b = normalize_name(b["raw_name"], strip_words)
    return difflib.SequenceMatcher(None, name_a, name_b).ratio()


def match_ratio(a: dict, b: dict, size_tolerance: float) -> float:
    """0.0 при конфликте, иначе — похожесть названий (0..1). Общая проверка
    для сравнения любых двух товаров из РАЗНЫХ магазинов."""
    if has_conflict(a, b, size_tolerance):
        return 0.0
    return name_similarity(a, b)


class UnionFind:
    """Для сопоставления сразу N магазинов: если A (Rimi) похож на B
    (Barbora), а B похож на C (LaTS), все трое должны стать ОДНИМ
    каноническим товаром, а не двумя отдельными парами."""

    def __init__(self, ids):
        self._parent = {i: i for i in ids}

    def find(self, x):
        while self._parent[x] != x:
            self._parent[x] = self._parent[self._parent[x]]
            x = self._parent[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self._parent[ra] = rb


def fetch_all_store_products(cfg: SupabaseConfig) -> list[dict]:
    """Постранично тянет ВСЕ строки (раньше был жёсткий limit=5000 — при
    полном скрапинге всех рубрик, а не небольшой выборки, это перестало
    покрывать таблицу целиком и давало 0 совпадений: в первые 5000 строк
    попадали в основном товары одного магазина)."""
    page_size = 1000
    rows: list[dict] = []
    offset = 0
    while True:
        resp = _request_with_retry(
            "get", f"{cfg.app_url}/rest/v1/store_products",
            params={
                "select": "id,raw_name,raw_category_path,package_price,"
                          "unit_price,unit_type,brand,product_id,stores(slug)",
                "limit": str(page_size),
                "offset": str(offset),
                "order": "id",
            },
            headers=_headers(cfg.app_service_key),
            timeout=60,
        )
        resp.raise_for_status()
        page = resp.json()
        rows.extend(page)
        if len(page) < page_size:
            break
        offset += page_size
    for r in rows:
        r["store_slug"] = (r.get("stores") or {}).get("slug")
    return rows


_PRODUCTS_UNIT_TYPE_MAP = {"gab": "pcs", "kg": "kg", "l": "l"}


def create_canonical_product(cfg: SupabaseConfig, name: str, brand: str | None,
                              unit_type: str | None, unit_size: float | None) -> str:
    # products.unit_type ограничена check-констрейнтом ('kg','l','pcs'), а
    # store_products использует латышское сокращение 'gab' (штука) — без
    # перевода вставка падала с 400 для любого поштучного товара (много
    # мяса/готовых блюд после полного скрапинга — раньше не всплывало,
    # т.к. сматченные товары были почти только молочные, kg/l).
    resp = _request_with_retry(
        "post", f"{cfg.app_url}/rest/v1/products",
        json={
            "canonical_name": name,
            "brand": brand,
            "unit_type": _PRODUCTS_UNIT_TYPE_MAP.get(unit_type, "pcs"),
            "unit_size": unit_size,
        },
        headers=_headers(cfg.app_service_key, prefer="return=representation"),
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json()[0]["id"]


def link_store_product(cfg: SupabaseConfig, store_product_id: str, product_id: str) -> None:
    resp = _request_with_retry(
        "patch", f"{cfg.app_url}/rest/v1/store_products",
        params={"id": f"eq.{store_product_id}"},
        json={"product_id": product_id},
        headers=_headers(cfg.app_service_key, prefer="return=minimal"),
        timeout=20,
    )
    resp.raise_for_status()


def greedy_match_pairs(items_a: list[dict], items_b: list[dict],
                       threshold: float, size_tolerance: float) -> list[tuple[dict, dict, float]]:
    """Для каждого товара из items_a ищем самый похожий ЕЩЁ НЕ занятый товар
    из items_b (жадно, один-к-одному) — та же логика, что раньше была
    единственной парой Rimi/Barbora, теперь переиспользуется для любой пары
    магазинов (Rimi/Barbora, Rimi/LaTS, Barbora/LaTS)."""
    used_b_ids: set[str] = set()
    pairs = []
    for a in items_a:
        best, best_ratio = None, 0.0
        for b in items_b:
            if b["id"] in used_b_ids:
                continue
            ratio = match_ratio(a, b, size_tolerance)
            if ratio > best_ratio:
                best_ratio, best = ratio, b
        if best and best_ratio >= threshold:
            used_b_ids.add(best["id"])
            pairs.append((a, best, best_ratio))
    return pairs


def _pick(items: list[dict], key: str):
    for item in items:
        value = item.get(key)
        if value:
            return value
    return None


def _pick_brand(items: list[dict]) -> str | None:
    for item in items:
        brand = item.get("brand") or guess_brand(item["raw_name"])
        if brand:
            return brand
    return None


def _pick_size(items: list[dict]) -> float | None:
    for item in items:
        size = compute_size(item)
        if size:
            return size
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", default=".env")
    parser.add_argument("--threshold", type=float, default=0.55,
                         help="Минимальная похожесть названий (0..1)")
    parser.add_argument("--size-tolerance", type=float, default=0.15,
                         help="Допустимое расхождение веса/объёма (доля)")
    parser.add_argument("--dry-run", action="store_true",
                         help="Только показать найденные пары, не писать в БД")
    args = parser.parse_args()

    cfg = SupabaseConfig.from_env_file(args.env_file)
    rows = fetch_all_store_products(cfg)

    matched_rows = [r for r in rows if r.get("product_id")]
    unmatched = [r for r in rows if not r.get("product_id")]

    existing_groups: dict[str, list[dict]] = {}
    for r in matched_rows:
        existing_groups.setdefault(r["product_id"], []).append(r)

    # --- Фаза A: сначала пробуем приложить несопоставленные товары к УЖЕ
    # существующим сматченным группам (например Rimi+Barbora уже сматчены
    # раньше — добавляем сюда такой же товар из LaTS), а не плодить новую
    # отдельную пару для третьего магазина.
    attach_plan: list[tuple[dict, str, float]] = []
    attached_ids: set[str] = set()
    for item in unmatched:
        best_product_id, best_ratio = None, 0.0
        for product_id, members in existing_groups.items():
            if any(m["store_slug"] == item["store_slug"] for m in members):
                continue  # этот магазин уже представлен в группе
            # Конфликт хотя бы с ОДНИМ участником группы — вето на всю
            # группу целиком, а не просто "не считаем этого участника":
            # иначе похожесть с представителем, который не упомянул,
            # например, жирность в названии, могла бы перекрыть реальный
            # конфликт с другим представителем той же группы.
            if any(has_conflict(item, m, args.size_tolerance) for m in members):
                continue
            ratio = max(name_similarity(item, m) for m in members)
            if ratio > best_ratio:
                best_ratio, best_product_id = ratio, product_id
        if best_product_id and best_ratio >= args.threshold:
            attach_plan.append((item, best_product_id, best_ratio))
            attached_ids.add(item["id"])

    remaining = [r for r in unmatched if r["id"] not in attached_ids]

    # --- Фаза B: среди оставшихся ищем новые совпадения парами магазинов
    # (жадно, как раньше), затем через Union-Find объединяем пары в группы —
    # так товар, сматченный и с Rimi, и с Barbora, попадёт в одну общую
    # группу из трёх, а не в две несвязанные пары.
    by_store: dict[str, list[dict]] = {}
    for r in remaining:
        by_store.setdefault(r["store_slug"], []).append(r)
    store_slugs = sorted(by_store)

    uf = UnionFind(r["id"] for r in remaining)

    for i, slug_a in enumerate(store_slugs):
        for slug_b in store_slugs[i + 1:]:
            for a, b, ratio in greedy_match_pairs(
                by_store[slug_a], by_store[slug_b], args.threshold, args.size_tolerance
            ):
                uf.union(a["id"], b["id"])

    groups: dict[str, list[dict]] = {}
    for r in remaining:
        groups.setdefault(uf.find(r["id"]), []).append(r)
    candidate_groups = [g for g in groups.values() if len({m["store_slug"] for m in g}) >= 2]

    # Union-Find объединяет транзитивно: если A совпал с B, а B — с C, все
    # трое попадают в одну группу, даже если A и C напрямую никогда не
    # сравнивались и на самом деле конфликтуют (напр. A и B похожи, у B и C
    # тоже что-то общее, а у A и C — разная жирность). Перепроверяем ВСЕ
    # пары внутри готовой группы и отбрасываем группу целиком при конфликте
    # — реже, но правильнее, чем оставить сомнительное трёхстороннее
    # совпадение.
    new_groups = []
    rejected_groups = []
    for group in candidate_groups:
        conflict_found = any(
            has_conflict(group[i], group[j], args.size_tolerance)
            for i in range(len(group))
            for j in range(i + 1, len(group))
        )
        (rejected_groups if conflict_found else new_groups).append(group)

    with open("match_report.txt", "w", encoding="utf-8") as f:
        f.write(f"Присоединено к существующим товарам: {len(attach_plan)}\n")
        f.write(f"Новых сопоставленных групп: {len(new_groups)}\n")
        f.write(f"Отклонено групп (конфликт внутри после Union-Find): {len(rejected_groups)}\n\n")
        for item, product_id, ratio in attach_plan:
            existing_names = "; ".join(f"{m['store_slug']}: {m['raw_name']}"
                                       for m in existing_groups[product_id])
            f.write(
                f"[{ratio:.2f}] + {item['store_slug']}: {item['raw_name']} "
                f"({item['package_price']} EUR) -> [{existing_names}]\n"
            )
        f.write("\n")
        for group in new_groups:
            f.write("Новая группа:\n")
            for m in sorted(group, key=lambda x: x["store_slug"]):
                f.write(f"  {m['store_slug']:8s} {m['raw_name']} ({m['package_price']} EUR)\n")
            f.write("\n")
        if rejected_groups:
            f.write("--- Отклонённые группы (конфликт между непосредственно не сравненной парой) ---\n\n")
            for group in rejected_groups:
                f.write("Отклонена:\n")
                for m in sorted(group, key=lambda x: x["store_slug"]):
                    f.write(f"  {m['store_slug']:8s} {m['raw_name']} ({m['package_price']} EUR)\n")
                f.write("\n")

    if args.dry_run:
        print(f"Dry run: присоединено {len(attach_plan)}, новых групп {len(new_groups)} "
              f"— см. match_report.txt")
        return

    committed = 0
    failed = 0

    for item, product_id, ratio in attach_plan:
        try:
            link_store_product(cfg, item["id"], product_id)
            committed += 1
        except Exception as exc:
            # Одна проблемная запись не должна обрывать остальные сотни.
            print(f"  пропущено (attach {item['raw_name']!r}): {exc}")
            failed += 1

    for group in new_groups:
        try:
            brand = _pick_brand(group)
            unit_type = _pick(group, "unit_type")
            size = _pick_size(group)
            name = group[0]["raw_name"]
            product_id = create_canonical_product(cfg, name, brand, unit_type, size)
            for m in group:
                link_store_product(cfg, m["id"], product_id)
            committed += 1
        except Exception as exc:
            names = "; ".join(m["raw_name"] for m in group)
            print(f"  пропущено (новая группа {names}): {exc}")
            failed += 1

    print(f"Записано: {committed}, пропущено: {failed}. Отчёт — match_report.txt")


if __name__ == "__main__":
    main()
