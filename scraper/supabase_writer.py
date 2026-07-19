"""
Запись результатов скрапинга в Supabase — основную БД приложения (SPEC.md §9)
и отдельную долгосрочную архивную БД (SPEC.md §9.1).

Использует service_role ключ (обходит RLS) — поэтому .env с ключами НИКОГДА
не должен попадать в git (см. .gitignore: scraper/.env).
"""

from __future__ import annotations

import datetime as dt
from dataclasses import dataclass

import requests

from rimi_scraper import ScrapedProduct


@dataclass
class SupabaseConfig:
    app_url: str
    app_service_key: str
    archive_url: str
    archive_service_key: str

    @classmethod
    def from_env_file(cls, path: str = ".env") -> "SupabaseConfig":
        values: dict[str, str] = {}
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                key, _, value = line.partition("=")
                values[key] = value
        return cls(
            app_url=values["SUPABASE_APP_URL"],
            app_service_key=values["SUPABASE_APP_SERVICE_KEY"],
            archive_url=values["SUPABASE_ARCHIVE_URL"],
            archive_service_key=values["SUPABASE_ARCHIVE_SERVICE_KEY"],
        )


def _headers(service_key: str, prefer: str | None = None) -> dict:
    h = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
    }
    if prefer:
        h["Prefer"] = prefer
    return h


def get_or_create_store(cfg: SupabaseConfig, slug: str, display_name: str) -> str:
    """Возвращает id строки stores по slug, создавая её при первом запуске."""
    base = f"{cfg.app_url}/rest/v1/stores"
    resp = requests.get(
        base, params={"slug": f"eq.{slug}", "select": "id"},
        headers=_headers(cfg.app_service_key), timeout=20,
    )
    resp.raise_for_status()
    rows = resp.json()
    if rows:
        return rows[0]["id"]

    resp = requests.post(
        base,
        json={"slug": slug, "display_name": display_name},
        headers=_headers(cfg.app_service_key, prefer="return=representation"),
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json()[0]["id"]


def upsert_store_products(cfg: SupabaseConfig, store_id: str,
                           products: list[ScrapedProduct]) -> dict[str, str]:
    """Пишет/обновляет строки store_products (upsert по store_id+store_sku),
    возвращает {store_sku: store_product_id}."""
    if not products:
        return {}

    rows = [
        {
            "store_id": store_id,
            "store_sku": p.store_sku,
            "raw_name": p.raw_name,
            "raw_category_path": p.category_code,
            "package_price": p.package_price,
            "regular_price": p.regular_price,
            "unit_price": p.unit_price,
            "unit_type": p.unit_type,
            "brand": p.brand,
            "is_promo": p.is_promo,
            "source_url": p.source_url,
            "image_url": p.image_url,
        }
        for p in products
    ]

    resp = requests.post(
        f"{cfg.app_url}/rest/v1/store_products",
        params={"on_conflict": "store_id,store_sku"},
        json=rows,
        headers=_headers(
            cfg.app_service_key,
            prefer="resolution=merge-duplicates,return=representation",
        ),
        timeout=60,
    )
    resp.raise_for_status()
    return {row["store_sku"]: row["id"] for row in resp.json()}


def insert_price_history(cfg: SupabaseConfig, store_product_ids: dict[str, str],
                          products: list[ScrapedProduct]) -> None:
    rows = [
        {
            "store_product_id": store_product_ids[p.store_sku],
            "price": p.package_price,
        }
        for p in products
        if p.store_sku in store_product_ids
    ]
    if not rows:
        return
    resp = requests.post(
        f"{cfg.app_url}/rest/v1/price_history",
        json=rows,
        headers=_headers(cfg.app_service_key, prefer="return=minimal"),
        timeout=60,
    )
    resp.raise_for_status()


def insert_promotions(cfg: SupabaseConfig, store_product_ids: dict[str, str],
                       products: list[ScrapedProduct]) -> None:
    """Простая вставка без дедупликации — MVP. При повторном скрапинге в тот
    же день возможны дублирующиеся строки; ужесточить (unique constraint по
    store_product_id+valid_from дню) можно позже, не блокирует прототип."""
    rows = [
        {
            "store_product_id": store_product_ids[p.store_sku],
            "discount_price": p.package_price,
            "lowest_price_30d": p.lowest_price_30d,
            "source": "e-veikals",
        }
        for p in products
        if p.is_promo and p.store_sku in store_product_ids
    ]
    if not rows:
        return
    resp = requests.post(
        f"{cfg.app_url}/rest/v1/promotions",
        json=rows,
        headers=_headers(cfg.app_service_key, prefer="return=minimal"),
        timeout=60,
    )
    resp.raise_for_status()


def record_price_observations(cfg: SupabaseConfig, products: list[ScrapedProduct]) -> None:
    """Долгосрочный архив (§9.1): SCD-2 — новая строка пишется только при
    изменении цены, иначе текущее наблюдение остаётся открытым (valid_to=null)."""
    base = f"{cfg.archive_url}/rest/v1/price_observations"
    now = dt.datetime.now(dt.timezone.utc).isoformat()

    for p in products:
        resp = requests.get(
            base,
            params={
                "store_slug": f"eq.{p.store_slug}",
                "raw_product_key": f"eq.{p.store_sku}",
                "valid_to": "is.null",
                "select": "id,price",
                "limit": "1",
            },
            headers=_headers(cfg.archive_service_key),
            timeout=20,
        )
        resp.raise_for_status()
        current = resp.json()

        if current and float(current[0]["price"]) == float(p.package_price):
            continue  # цена не изменилась — новую запись не создаём

        if current:
            requests.patch(
                base,
                params={"id": f"eq.{current[0]['id']}"},
                json={"valid_to": now},
                headers=_headers(cfg.archive_service_key, prefer="return=minimal"),
                timeout=20,
            ).raise_for_status()

        requests.post(
            base,
            json={
                "store_slug": p.store_slug,
                "raw_product_key": p.store_sku,
                "category_path": p.category_code,
                "raw_name": p.raw_name,
                "brand": p.brand,
                "price": p.package_price,
                "unit_price": p.unit_price,
                "is_promo": p.is_promo,
            },
            headers=_headers(cfg.archive_service_key, prefer="return=minimal"),
            timeout=20,
        ).raise_for_status()


def write_products(cfg: SupabaseConfig, store_slug: str, store_display_name: str,
                    products: list[ScrapedProduct]) -> None:
    """Полный цикл записи для одной партии товаров одного магазина."""
    if not products:
        return
    store_id = get_or_create_store(cfg, store_slug, store_display_name)
    store_product_ids = upsert_store_products(cfg, store_id, products)
    insert_price_history(cfg, store_product_ids, products)
    insert_promotions(cfg, store_product_ids, products)
    record_price_observations(cfg, products)
