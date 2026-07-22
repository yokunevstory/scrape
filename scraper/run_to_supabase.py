"""
Скрапинг (Rimi, Barbora или LaTS) -> запись в Supabase (основная БД + архив).
Универсальный раннер для всех магазинов. См. SPEC.md §8, §9.1, §16.

Использование:
    python run_to_supabase.py --store rimi --category-url "https://www.rimi.lv/e-veikals/lv/produkti/piena-produkti-un-olas/c/SH-11"
    python run_to_supabase.py --store barbora --category-url "https://barbora.lv/piena-produkti-un-olas/piens/pasterizets-piens"
    python run_to_supabase.py --store lats --category-url "https://e-latts.lv/biezpiens.21.g"
    python run_to_supabase.py --store barbora --all-categories --limit-categories 5
"""

from __future__ import annotations

import argparse
import time

import barbora_scraper
import lats_scraper
import rimi_scraper
from supabase_writer import SupabaseConfig, write_products


def _rimi_scrape_category(session, url, category_index):
    return rimi_scraper.scrape_category(session, url, category_index=category_index)


STORES = {
    "rimi": {
        "slug": "rimi",
        "display_name": "Rimi",
        "session": rimi_scraper._session,
        "fetch_category_tree": rimi_scraper.fetch_category_tree,
        "iter_leaf_category_urls": rimi_scraper.iter_leaf_category_urls,
        "scrape_category": _rimi_scrape_category,
        "needs_category_index": True,
    },
    "barbora": {
        "slug": "barbora",
        "display_name": "Maxima",
        "session": barbora_scraper._session,
        "fetch_category_tree": barbora_scraper.fetch_category_tree,
        "iter_leaf_category_urls": barbora_scraper.iter_leaf_category_urls,
        "scrape_category": lambda session, url, category_index: barbora_scraper.scrape_category(session, url),
        "needs_category_index": False,
    },
    "lats": {
        "slug": "lats",
        "display_name": "LaTS",
        "session": lats_scraper._session,
        "fetch_category_tree": lats_scraper.fetch_category_tree,
        "iter_leaf_category_urls": lats_scraper.iter_leaf_category_urls,
        "scrape_category": lambda session, url, category_index: lats_scraper.scrape_category(session, url),
        "needs_category_index": False,
    },
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--store", choices=STORES.keys(), required=True)
    parser.add_argument("--category-url")
    parser.add_argument("--all-categories", action="store_true")
    parser.add_argument("--limit-categories", type=int, default=None)
    parser.add_argument("--env-file", default=".env")
    args = parser.parse_args()

    store = STORES[args.store]
    cfg = SupabaseConfig.from_env_file(args.env_file)
    session = store["session"]()

    tree = store["fetch_category_tree"](session)
    category_index = rimi_scraper.build_category_name_index(tree) if store["needs_category_index"] else None

    if args.all_categories:
        urls = list(store["iter_leaf_category_urls"](tree))
        if args.limit_categories:
            urls = urls[: args.limit_categories]
    elif args.category_url:
        urls = [args.category_url]
    else:
        parser.error("Укажите --category-url или --all-categories")
        return

    total = 0
    failed_urls: list[str] = []
    for i, url in enumerate(urls, 1):
        print(f"[{i}/{len(urls)}] {url}")
        try:
            products = store["scrape_category"](session, url, category_index)
            write_products(cfg, store["slug"], store["display_name"], products)
        except Exception as exc:
            # Одна упавшая категория (например, временная 500 от Supabase,
            # см. supabase_writer._request_with_retry) не должна обрывать
            # многочасовой прогон по всем рубрикам — логируем и идём дальше,
            # неудачные адреса можно повторить отдельным прогоном.
            print(f"  ОШИБКА, пропускаю категорию: {exc}")
            failed_urls.append(url)
            continue
        total += len(products)
        print(f"  записано товаров: {len(products)}")
        time.sleep(1.0)

    print(f"\nВсего записано в Supabase: {total}")
    if failed_urls:
        report_path = f"failed_categories_{args.store}.txt"
        with open(report_path, "w", encoding="utf-8") as f:
            f.write("\n".join(failed_urls))
        print(f"Не удалось обработать {len(failed_urls)} категорий — см. {report_path}")


if __name__ == "__main__":
    main()
