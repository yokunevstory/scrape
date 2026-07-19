-- Схема для ОТДЕЛЬНОГО Supabase-проекта — долгосрочный архив истории цен
-- (SPEC.md §9.1). НЕ выполнять в основном проекте приложения (см.
-- supabase/migrations/0001_init_schema.sql) — это сознательно другая база,
-- с другим жизненным циклом (бессрочное хранение, не привязано к пользователям).

create extension if not exists "pgcrypto";

-- Append-only лог наблюдений цены. Новая строка пишется только при изменении
-- цены (SCD-2: valid_from/valid_to), а не при каждом прогоне скрапинга —
-- иначе объём за годы станет неподъёмным.
create table price_observations (
  id uuid primary key default gen_random_uuid(),
  store_slug text not null,               -- 'rimi' | 'barbora' — без FK на другую БД
  raw_product_key text not null,          -- SKU/URL товара на сайте магазина
  category_path text,                     -- категория как на сайте магазина
  raw_name text not null,
  brand text,
  package_size text,
  price numeric not null,
  unit_price numeric,
  is_promo boolean not null default false,
  valid_from timestamptz not null default now(),
  valid_to timestamptz,                   -- null = текущая цена (ещё не сменилась)
  created_at timestamptz not null default now()
);

create index idx_price_observations_key on price_observations(store_slug, raw_product_key);
create index idx_price_observations_current on price_observations(store_slug, raw_product_key)
  where valid_to is null;
create index idx_price_observations_category on price_observations(category_path);

-- Эта база не хранит персональные данные пользователей — GDPR-требования
-- (см. legal/PRIVACY_POLICY.md) на неё не распространяются. RLS можно не
-- включать, так как доступ к этому проекту имеет только сам скрапер/автор
-- (через service key), приложение конечных пользователей сюда не обращается.
