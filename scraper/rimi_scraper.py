"""
Прототип скрапера для Rimi (rimi.lv/e-veikals) — см. SPEC.md §8.0/§8.1.

Источник открытый (страницы категорий интернет-магазина, разрешено robots.txt,
см. SPEC.md §8.0). Скрипт только читает публичные страницы, не логинится и не
обращается к личному кабинету/корзине.

Использование (пока без записи в БД — только локальный файл для проверки):
    python rimi_scraper.py --category-url "https://www.rimi.lv/e-veikals/lv/produkti/piena-produkti-un-olas/c/SH-11" --out out.jsonl
"""

from __future__ import annotations

import argparse
import json
import re
import time
from dataclasses import asdict, dataclass
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://www.rimi.lv"
CATEGORY_TREE_API = f"{BASE_URL}/e-veikals/api/v1/content/category-tree?locale=lv"
USER_AGENT = "PriceCompareLV-research/0.1 (+https://github.com/; contact via app owner)"
REQUEST_DELAY_SECONDS = 1.0  # не перегружать сайт частыми запросами


@dataclass
class ScrapedProduct:
    store_slug: str
    store_sku: str
    raw_name: str
    category_code: str | None
    brand: str | None
    package_price: float
    regular_price: float | None
    unit_price: float | None
    unit_type: str | None
    is_promo: bool
    lowest_price_30d: float | None
    source_url: str
    image_url: str | None


def _session() -> requests.Session:
    s = requests.Session()
    s.headers.update({"User-Agent": USER_AGENT})
    return s


def fetch_category_tree(session: requests.Session) -> list[dict]:
    """Возвращает дерево категорий Rimi (готовая иерархия, см. SPEC.md §8.0)."""
    resp = session.get(CATEGORY_TREE_API, timeout=20)
    resp.raise_for_status()
    return resp.json()["categories"]


def iter_leaf_category_urls(categories: list[dict]):
    """Обходит дерево категорий и отдаёт полные URL только листовых категорий
    (у которых нет descendants) — именно на таких страницах лежат товары."""
    for cat in categories:
        descendants = cat.get("descendants") or []
        if not descendants:
            yield urljoin(BASE_URL, cat["url"])
        else:
            yield from iter_leaf_category_urls(descendants)


_CATEGORY_CODE_RE = re.compile(r"/c/([A-Za-z0-9-]+)$")


def build_category_name_index(categories: list[dict], _prefix: str = "") -> dict[str, str]:
    """Строит {код_категории_Rimi ('SH-x-y-z') -> читаемый путь названий
    ('Родитель/Ребёнок/...')}, чтобы можно было сопоставлять категории между
    магазинами по названию, а не по внутреннему коду (у каждого магазина он
    свой) — см. SPEC.md, обсуждение сопоставления категорий между Rimi и
    Barbora."""
    index: dict[str, str] = {}
    for cat in categories:
        name = cat["name"].strip()
        path = f"{_prefix}/{name}" if _prefix else name
        match = _CATEGORY_CODE_RE.search(cat.get("url", ""))
        if match:
            index[match.group(1)] = path
        descendants = cat.get("descendants") or []
        if descendants:
            index.update(build_category_name_index(descendants, path))
    return index


_PRICE_RE = re.compile(r"(\d+[.,]\d+)")


def _parse_price(text: str | None) -> float | None:
    if not text:
        return None
    match = _PRICE_RE.search(text.replace("\xa0", " "))
    if not match:
        return None
    return float(match.group(1).replace(",", "."))


def _parse_unit_price(text: str | None) -> tuple[float | None, str | None]:
    """"Cena par vienību: 11,94 €/kg" -> (11.94, 'kg')"""
    if not text:
        return None, None
    price = _parse_price(text)
    unit = None
    for candidate in ("kg", "l", "gab"):
        if f"/{candidate}" in text:
            unit = candidate
            break
    return price, unit


def parse_product_card(card, category_index: dict[str, str] | None = None) -> ScrapedProduct | None:
    product_code = card.get("data-product-code")
    if not product_code:
        return None

    gtm_raw = card.get("data-gtm-eec-product")
    gtm = json.loads(gtm_raw) if gtm_raw else {}
    category_code = gtm.get("category")
    category_path = (category_index or {}).get(category_code, category_code)

    name_el = card.select_one(".card__name")
    name = name_el.get_text(strip=True) if name_el else gtm.get("name")

    url_el = card.select_one("a.card__url")
    source_url = urljoin(BASE_URL, url_el["href"]) if url_el and url_el.get("href") else BASE_URL

    img_el = card.select_one(".card__image-wrapper img")
    image_url = img_el.get("data-src") or img_el.get("src") if img_el else None

    price_per_text = card.select_one(".card__price-per .sr-only")
    unit_price, unit_type = _parse_unit_price(
        price_per_text.get_text(strip=True) if price_per_text else None
    )

    old_price_text = card.select_one(".card__old-price .sr-only")
    regular_price = _parse_price(old_price_text.get_text(strip=True)) if old_price_text else None

    lowest_price_el = card.select_one(".lowest-price")
    lowest_price_30d = _parse_price(lowest_price_el.get_text(strip=True)) if lowest_price_el else None

    package_price = gtm.get("price")
    if package_price is None:
        price_sr = card.select_one(".card__price .sr-only")
        package_price = _parse_price(price_sr.get_text(strip=True)) if price_sr else None

    return ScrapedProduct(
        store_slug="rimi",
        store_sku=product_code,
        raw_name=name or "",
        category_code=category_path,
        brand=gtm.get("brand"),
        package_price=package_price,
        regular_price=regular_price,
        unit_price=unit_price,
        unit_type=unit_type,
        is_promo=regular_price is not None,
        lowest_price_30d=lowest_price_30d,
        source_url=source_url,
        image_url=image_url,
    )


def scrape_category(session: requests.Session, category_url: str,
                     category_index: dict[str, str] | None = None) -> list[ScrapedProduct]:
    """Обходит все страницы категории (пагинация ?currentPage=N) и отдаёт
    список ScrapedProduct со всех страниц. category_index — соответствие
    кодов категорий Rimi читаемым путям названий (см. build_category_name_index),
    нужен, чтобы категории было можно сопоставлять с Barbora по названию."""
    products: list[ScrapedProduct] = []
    url = category_url

    while url:
        resp = session.get(url, timeout=20)
        resp.raise_for_status()
        soup = BeautifulSoup(resp.text, "lxml")

        cards = soup.select("div.js-product-container[data-product-code]")
        for card in cards:
            product = parse_product_card(card, category_index=category_index)
            if product:
                products.append(product)

        next_link = soup.select_one("nav.pagination a[rel='next']")
        if next_link and next_link.get("href"):
            url = urljoin(BASE_URL, next_link["href"])
            time.sleep(REQUEST_DELAY_SECONDS)
        else:
            url = None

    return products


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--category-url", help="URL одной категории для теста")
    parser.add_argument("--all-categories", action="store_true",
                         help="Обойти вообще все листовые категории из дерева Rimi")
    parser.add_argument("--out", default="rimi_products.jsonl")
    parser.add_argument("--limit-categories", type=int, default=None,
                         help="Ограничить число категорий (для быстрой проверки)")
    args = parser.parse_args()

    session = _session()
    tree = fetch_category_tree(session)
    category_index = build_category_name_index(tree)

    if args.all_categories:
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
                products = scrape_category(session, url, category_index=category_index)
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
