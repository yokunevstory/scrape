"""
Прототип скрапера для Barbora (barbora.lv) — источник данных по Maxima,
см. SPEC.md §8.0.

Открытие: несмотря на то, что Barbora — SPA (Next.js) с рендерингом на
клиенте, полный список товаров категории уже присутствует в обычном HTML-
ответе (без выполнения JS) внутри `<script>window.b_productList = [...]</script>`.
Значит скрапинг = обычный HTTP GET + regex/JSON-разбор, без headless-браузера.

Использование:
    python barbora_scraper.py --category-url "https://barbora.lv/piena-produkti-un-olas/piens/pasterizets-piens" --out out.jsonl
"""

from __future__ import annotations

import argparse
import json
import re
import time
from dataclasses import asdict
from urllib.parse import urljoin

import requests

from rimi_scraper import ScrapedProduct  # общая структура для обоих магазинов

BASE_URL = "https://barbora.lv"
CATEGORIES_API = "https://production-elb.barbora.lt/api/cache/v1/country/LV/categories"
CATEGORIES_API_PARAMS = {"languageId": "a1113543-fb34-45c8-ad94-7a1d823cef57", "shopcode": ""}
USER_AGENT = "PriceCompareLV-research/0.1 (+https://github.com/; contact via app owner)"
REQUEST_DELAY_SECONDS = 1.0

_PRODUCT_LIST_RE = re.compile(r"window\.b_productList\s*=\s*(\[.*?\]);", re.DOTALL)
_PAGE_LINK_RE = re.compile(r"[?&]page=(\d+)")


def _session() -> requests.Session:
    s = requests.Session()
    s.headers.update({"User-Agent": USER_AGENT})
    return s


def fetch_category_tree(session: requests.Session) -> list[dict]:
    resp = session.get(CATEGORIES_API, params=CATEGORIES_API_PARAMS, timeout=20)
    resp.raise_for_status()
    return resp.json()


def iter_leaf_category_urls(categories: list[dict]):
    for cat in categories:
        children = cat.get("children") or []
        if not children:
            yield urljoin(BASE_URL + "/", cat["fullUrl"])
        else:
            yield from iter_leaf_category_urls(children)


def _parse_product(raw: dict) -> ScrapedProduct:
    promotion = raw.get("promotion")
    return ScrapedProduct(
        store_slug="barbora",
        store_sku=str(raw["id"]),
        raw_name=raw.get("title", ""),
        # Путь названий категории (не внутренний код) — чтобы можно было
        # сопоставлять категории с Rimi по названию, см. rimi_scraper.py
        # build_category_name_index().
        category_code=raw.get("category_name_full_path") or raw.get("category_path_url"),
        brand=raw.get("brand_name"),
        package_price=raw["price"],
        regular_price=raw.get("retail_price") if promotion else None,
        unit_price=raw.get("comparative_unit_price"),
        unit_type=(raw.get("comparative_unit") or "").rstrip("."),
        is_promo=bool(promotion),
        lowest_price_30d=None,  # не найдено в этом источнике данных, см. заметку в SPEC
        source_url=urljoin(BASE_URL + "/produkti/", raw.get("Url", "")),
        image_url=raw.get("big_image") or raw.get("image"),
    )


def _extract_products(html: str) -> list[ScrapedProduct]:
    match = _PRODUCT_LIST_RE.search(html)
    if not match:
        return []
    raw_products = json.loads(match.group(1))
    return [_parse_product(p) for p in raw_products]


def scrape_category(session: requests.Session, category_url: str) -> list[ScrapedProduct]:
    resp = session.get(category_url, timeout=20)
    resp.raise_for_status()
    products = _extract_products(resp.text)

    max_page = 1
    for m in _PAGE_LINK_RE.finditer(resp.text):
        max_page = max(max_page, int(m.group(1)))

    for page in range(2, max_page + 1):
        time.sleep(REQUEST_DELAY_SECONDS)
        resp = session.get(category_url, params={"page": page}, timeout=20)
        resp.raise_for_status()
        products.extend(_extract_products(resp.text))

    return products


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--category-url")
    parser.add_argument("--all-categories", action="store_true")
    parser.add_argument("--limit-categories", type=int, default=None)
    parser.add_argument("--out", default="barbora_products.jsonl")
    args = parser.parse_args()

    session = _session()

    if args.all_categories:
        tree = fetch_category_tree(session)
        urls = list(iter_leaf_category_urls(tree))
        if args.limit_categories:
            urls = urls[: args.limit_categories]
    elif args.category_url:
        urls = [args.category_url]
    else:
        parser.error("Укажите --category-url или --all-categories")
        return

    total = 0
    with open(args.out, "w", encoding="utf-8") as f:
        for i, url in enumerate(urls, 1):
            print(f"[{i}/{len(urls)}] {url}")
            try:
                products = scrape_category(session, url)
            except requests.RequestException as e:
                print(f"  ошибка запроса: {e}")
                continue
            for p in products:
                f.write(json.dumps(asdict(p), ensure_ascii=False) + "\n")
            total += len(products)
            print(f"  найдено товаров: {len(products)}")
            time.sleep(REQUEST_DELAY_SECONDS)

    print(f"\nВсего сохранено товаров: {total} -> {args.out}")


if __name__ == "__main__":
    main()
