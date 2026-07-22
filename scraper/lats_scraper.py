"""
Скрапер для LaTS (e-latts.lv) — SPEC.md §8/§16. В отличие от Elvi/Mego/Top!,
у LaTS есть полноценный интернет-магазин (похоже на PrestaShop) с постоянным
каталогом, а не только акционные позиции недели — сравнимо по масштабу с
Rimi (402 листовых категории против 589 у Rimi).

Дерево категорий зашито прямо в HTML главной страницы (.MainMenu) — никакого
отдельного API, как у Rimi, тут нет. Карточка товара на странице категории уже
содержит свой полный путь категории (.-oGroupPath), поэтому отдельный индекс
имён категорий (как build_category_name_index у Rimi) не нужен.

Использование:
    python lats_scraper.py --category-url "https://e-latts.lv/biezpiens.21.g" --out out.jsonl
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

BASE_URL = "https://e-latts.lv"
USER_AGENT = "PriceCompareLV-research/0.1 (+https://github.com/; contact via app owner)"
REQUEST_DELAY_SECONDS = 1.0


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
    """Дерево категорий (верхний/средний/листовой уровень) зашито прямо в
    навигацию главной страницы. Возвращает список листовых категорий вида
    {"url": ..., "path": "Топ/Средняя/Лист"} — path тут только для справки,
    у каждой карточки товара на странице категории есть свой .-oGroupPath."""
    resp = session.get(BASE_URL + "/", timeout=20)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    leaves: list[dict] = []
    menu = soup.select_one(".MainMenu")
    if not menu:
        return leaves

    for top_li in menu.select(":scope > .container > ul > li"):
        top_link = top_li.select_one(":scope > a")
        if not top_link:
            continue  # первый <li> меню — избранное/акции, не категория
        top_name = top_link.get_text(strip=True)
        drop = top_li.select_one(".MainMenu__drop")
        if not drop:
            continue
        for mid in drop.select(".MainMenu__drop-nameCat"):
            mid_a = mid.select_one("a")
            mid_name = mid_a.get_text(strip=True) if mid_a else ""
            drop_list = mid.find_next_sibling("div", class_="MainMenu__drop-list")
            if not drop_list:
                continue
            for leaf_a in drop_list.select(".MainMenu__drop-list-item a"):
                href = leaf_a.get("href")
                if not href:
                    continue
                leaf_name = leaf_a.get_text(strip=True)
                leaves.append({
                    "url": urljoin(BASE_URL, href),
                    "path": f"{top_name}/{mid_name}/{leaf_name}",
                })
    return leaves


def iter_leaf_category_urls(categories: list[dict]):
    for cat in categories:
        yield cat["url"]


_PRICE_RE = re.compile(r"(\d+[.,]\d+)")


def _parse_price(text: str | None) -> float | None:
    if not text:
        return None
    match = _PRICE_RE.search(text.replace("\xa0", " "))
    if not match:
        return None
    return float(match.group(1).replace(",", "."))


def _parse_unit_price(text: str | None) -> tuple[float | None, str | None]:
    """"€ 5.50 / Kg" -> (5.50, 'kg'); "€ 0.29 / gab" -> (0.29, 'gab')."""
    if not text:
        return None, None
    price = _parse_price(text)
    unit = None
    compact = text.lower().replace(" ", "").replace("\xa0", "")
    for candidate in ("kg", "l", "gab"):
        if f"/{candidate}" in compact:
            unit = candidate
            break
    return price, unit


def parse_product_card(card) -> ScrapedProduct | None:
    store_sku = card.get("-id")
    if not store_sku:
        return None

    title_el = card.select_one(".-oTitle")
    name = title_el.get_text(strip=True) if title_el else None
    source_url = (
        urljoin(BASE_URL, title_el["href"]) if title_el and title_el.get("href") else BASE_URL
    )

    brand_el = card.select_one(".-brand")
    brand = (brand_el.get_text(strip=True) or None) if brand_el else None

    group_path_el = card.select_one(".-oGroupPath")
    category_path = group_path_el.get_text(strip=True) if group_path_el else None

    price_el = card.select_one(".-oPrice")
    package_price = _parse_price(price_el.get("-price")) if price_el else None
    if package_price is None:
        return None

    old_price_el = card.select_one(".-oPrice .-eOld")
    regular_price = _parse_price(old_price_el.get_text(strip=True)) if old_price_el else None

    per_unit_el = card.select_one(".-oPrice .-ePerUnit")
    unit_price, unit_type = _parse_unit_price(
        per_unit_el.get_text(strip=True) if per_unit_el else None
    )

    img_el = card.select_one(".-oThumb img")
    image_url = urljoin(BASE_URL, img_el["src"]) if img_el and img_el.get("src") else None

    return ScrapedProduct(
        store_slug="lats",
        store_sku=store_sku,
        raw_name=name or "",
        category_code=category_path,
        brand=brand,
        package_price=package_price,
        regular_price=regular_price,
        unit_price=unit_price,
        unit_type=unit_type,
        is_promo=regular_price is not None,
        lowest_price_30d=None,
        source_url=source_url,
        image_url=image_url,
    )


def scrape_category(session: requests.Session, category_url: str, category_index=None
                     ) -> list[ScrapedProduct]:
    """Обходит все страницы категории (пагинация ?p=N, нумерация с нуля,
    базовый URL без параметра — уже страница 0). category_index не
    используется (оставлен для единообразия сигнатуры с run_to_supabase.py —
    у LaTS путь категории уже приходит с каждой карточкой товара)."""
    products: list[ScrapedProduct] = []
    seen_skus: set[str] = set()

    def _collect(html: str) -> None:
        soup = BeautifulSoup(html, "html.parser")
        for card in soup.select(".-oProduct"):
            product = parse_product_card(card)
            if product and product.store_sku not in seen_skus:
                seen_skus.add(product.store_sku)
                products.append(product)
        return soup

    resp = session.get(category_url, timeout=20)
    resp.raise_for_status()
    soup = _collect(resp.text)

    max_page = 0
    pager = soup.select_one(".product_listing_main_switcher_page_line")
    if pager:
        for a in pager.select("a[href]"):
            m = re.search(r"[?&]p=(\d+)", a["href"])
            if m:
                max_page = max(max_page, int(m.group(1)))

    for page in range(1, max_page + 1):
        time.sleep(REQUEST_DELAY_SECONDS)
        resp = session.get(f"{category_url}?p={page}", timeout=20)
        resp.raise_for_status()
        _collect(resp.text)

    return products


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--category-url", help="URL одной категории для теста")
    parser.add_argument("--all-categories", action="store_true",
                         help="Обойти вообще все листовые категории LaTS")
    parser.add_argument("--out", default="lats_products.jsonl")
    parser.add_argument("--limit-categories", type=int, default=None,
                         help="Ограничить число категорий (для быстрой проверки)")
    args = parser.parse_args()

    session = _session()
    tree = fetch_category_tree(session)

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
