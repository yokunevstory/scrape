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

from supabase_writer import SupabaseConfig, _headers

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


def top_category(path: str | None) -> str | None:
    if not path:
        return None
    return path.split("/")[0].strip()


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


def fetch_all_store_products(cfg: SupabaseConfig) -> list[dict]:
    resp = requests.get(
        f"{cfg.app_url}/rest/v1/store_products",
        params={
            "select": "id,raw_name,raw_category_path,package_price,"
                      "unit_price,unit_type,brand,product_id,stores(slug)",
            "limit": "5000",
        },
        headers=_headers(cfg.app_service_key),
        timeout=60,
    )
    resp.raise_for_status()
    rows = resp.json()
    for r in rows:
        r["store_slug"] = (r.get("stores") or {}).get("slug")
    return rows


def create_canonical_product(cfg: SupabaseConfig, name: str, brand: str | None,
                              unit_type: str | None, unit_size: float | None) -> str:
    resp = requests.post(
        f"{cfg.app_url}/rest/v1/products",
        json={
            "canonical_name": name,
            "brand": brand,
            "unit_type": unit_type or "gab",
            "unit_size": unit_size,
        },
        headers=_headers(cfg.app_service_key, prefer="return=representation"),
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json()[0]["id"]


def link_store_product(cfg: SupabaseConfig, store_product_id: str, product_id: str) -> None:
    resp = requests.patch(
        f"{cfg.app_url}/rest/v1/store_products",
        params={"id": f"eq.{store_product_id}"},
        json={"product_id": product_id},
        headers=_headers(cfg.app_service_key, prefer="return=minimal"),
        timeout=20,
    )
    resp.raise_for_status()


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
    unmatched = [r for r in rows if not r.get("product_id")]

    # Раньше сравнивали только внутри одной верхнеуровневой категории (по
    # точному тексту raw_category_path), чтобы не сверять вообще всё со
    # всем. Но у Rimi и Barbora названия категорий отличаются даже для одних
    # и тех же товаров (напр. "Gaļa, zivs un gatavā kulinārija" у Barbora
    # против "Gaļa, zivis un gatavā kulinārija" у Rimi, "Maize un
    # konditoreja" против "Maize un konditorejas izstrādājumi") — из-за
    # этого мясо, хлеб и детские товары вообще никогда не сравнивались
    # между магазинами. Сравниваем все несопоставленные товары сразу;
    # от ложных совпадений защищают бренд/размер/жирность/газация-гейты
    # и высокий порог похожести названия, а не совпадение категории.
    rimi_items = [r for r in unmatched if r["store_slug"] == "rimi"]
    barbora_items = [r for r in unmatched if r["store_slug"] == "barbora"]
    used_barbora_ids = set()

    matches = []
    for a in rimi_items:
        size_a = compute_size(a)
        brand_a = a.get("brand") or guess_brand(a["raw_name"])
        best, best_ratio = None, 0.0

        for b in barbora_items:
            if b["id"] in used_barbora_ids:
                continue
            brand_b = b.get("brand") or guess_brand(b["raw_name"])
            if brands_conflict(brand_a, brand_b):
                continue
            if carbonation_conflicts(a["raw_name"], b["raw_name"]):
                continue
            if fat_percent_conflicts(a["raw_name"], b["raw_name"]):
                continue
            size_b = compute_size(b)
            if size_a and size_b:
                diff = abs(size_a - size_b) / max(size_a, size_b)
                if diff > args.size_tolerance:
                    continue
            # Убираем бренд из названий перед сравнением похожести —
            # иначе одинаковый бренд + разный вкус ("Kārums ar magonēm"
            # vs "KĀRUMS vaniļas") может набрать высокую похожесть только
            # за счёт общих слов бренда и категории, а не вкуса.
            strip_words = _FILLER_WORDS | {w.lower() for w in (brand_a, brand_b) if w}
            name_a = normalize_name(a["raw_name"], strip_words)
            name_b = normalize_name(b["raw_name"], strip_words)
            ratio = difflib.SequenceMatcher(None, name_a, name_b).ratio()
            if ratio > best_ratio:
                best_ratio, best = ratio, b

        if best and best_ratio >= args.threshold:
            used_barbora_ids.add(best["id"])
            matches.append((top_category(a["raw_category_path"]), a, best, best_ratio))

    with open("match_report.txt", "w", encoding="utf-8") as f:
        f.write(f"Найдено совпадений: {len(matches)}\n\n")
        for category, a, b, ratio in matches:
            f.write(
                f"[{ratio:.2f}] {category}\n"
                f"  Rimi:    {a['raw_name']} ({a['package_price']} EUR)\n"
                f"  Barbora: {b['raw_name']} ({b['package_price']} EUR)\n\n"
            )

    if args.dry_run:
        print(f"Dry run: {len(matches)} matches, see match_report.txt")
        return

    for category, a, b, ratio in matches:
        unit_type = a.get("unit_type") or b.get("unit_type")
        size = compute_size(a) or compute_size(b)
        brand = a.get("brand") or b.get("brand") or guess_brand(a["raw_name"]) or guess_brand(b["raw_name"])
        product_id = create_canonical_product(cfg, a["raw_name"], brand, unit_type, size)
        link_store_product(cfg, a["id"], product_id)
        link_store_product(cfg, b["id"], product_id)

    print(f"Готово: {len(matches)} совпадений записано. Отчёт — match_report.txt")


if __name__ == "__main__":
    main()
