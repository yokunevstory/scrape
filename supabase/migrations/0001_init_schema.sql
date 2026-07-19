-- Начальная схема приложения (операционная БД, Supabase проект №1).
-- Соответствует модели данных из SPEC.md §9. Долгосрочный архив цен (§9.1) —
-- отдельная БД/проект, схема которого лежит в archive/schema.sql, сюда не входит.

create extension if not exists "pgcrypto";

-- =========================================================================
-- Справочники: магазины и категории
-- =========================================================================

create table stores (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,              -- 'rimi', 'barbora'
  display_name text not null,             -- 'Rimi', 'Maxima (по данным Barbora)'
  country text not null default 'LV',
  website text,
  logo_url text,
  created_at timestamptz not null default now()
);

create table categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references categories(id) on delete cascade,
  slug text not null unique,
  name_lv text not null,
  name_ru text,
  name_en text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index idx_categories_parent on categories(parent_id);

-- =========================================================================
-- Товары: канонический товар + конкретное предложение в конкретном магазине
-- =========================================================================

create table products (
  id uuid primary key default gen_random_uuid(),
  ean text unique,                        -- штрихкод, если известен (см. SPEC §8.2)
  canonical_name text not null,
  brand text,
  category_id uuid references categories(id),
  unit_type text not null check (unit_type in ('kg', 'l', 'pcs')),
  unit_size numeric,                      -- напр. 0.5 (кг) для пачки 500г
  created_at timestamptz not null default now()
);

create index idx_products_category on products(category_id);
create index idx_products_brand on products(brand);

create table store_products (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products(id),  -- null, пока не сматчен между магазинами (§8.2)
  store_id uuid not null references stores(id),
  store_sku text not null,                  -- устойчивый ID/URL товара на сайте магазина
  raw_name text not null,
  raw_category_path text,                   -- категория как на сайте магазина (для §9.1)
  package_size text,                        -- как есть на сайте, напр. "500 g"
  package_price numeric not null,
  regular_price numeric,                    -- цена без скидки, если есть промо
  unit_price numeric,                       -- €/кг, €/л, €/шт — посчитано при скрапинге
  is_promo boolean not null default false,
  source_url text not null,                 -- прямая ссылка на страницу товара (атрибуция)
  scraped_at timestamptz not null default now(),
  unique (store_id, store_sku)
);

create index idx_store_products_product on store_products(product_id);
create index idx_store_products_store on store_products(store_id);

create table promotions (
  id uuid primary key default gen_random_uuid(),
  store_product_id uuid not null references store_products(id) on delete cascade,
  discount_price numeric not null,
  lowest_price_30d numeric,                 -- «30 dienu zemākā cena» с сайта Rimi, если есть
  valid_from date,
  valid_to date,
  source text,                              -- 'e-veikals' | 'buklets' и т.п.
  created_at timestamptz not null default now()
);

create index idx_promotions_store_product on promotions(store_product_id);

-- Краткая операционная история цены — для «было/стало» на карточке товара внутри
-- приложения. Не путать с долгосрочным архивом §9.1 (та база отдельная и бессрочная).
create table price_history (
  id uuid primary key default gen_random_uuid(),
  store_product_id uuid not null references store_products(id) on delete cascade,
  price numeric not null,
  observed_at timestamptz not null default now()
);

create index idx_price_history_store_product on price_history(store_product_id, observed_at);

-- =========================================================================
-- Пользователи и их данные
-- =========================================================================

-- Публичный профиль поверх auth.users (стандартный паттерн Supabase — не хранить
-- лишние поля прямо в auth.users).
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table shopping_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Мой список',
  created_at timestamptz not null default now()
);

create table shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references shopping_lists(id) on delete cascade,
  product_id uuid references products(id),
  custom_name text,                         -- если товар не найден в каталоге
  quantity numeric not null default 1,
  created_at timestamptz not null default now()
);

create index idx_shopping_list_items_list on shopping_list_items(list_id);

create table favorite_stores (
  user_id uuid not null references auth.users(id) on delete cascade,
  store_id uuid not null references stores(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, store_id)
);

-- Журнал согласий (GDPR, см. legal/DATA_PROCESSING_CONSENT.md §4)
create table user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  consent_type text not null,               -- 'account_data' | 'personalized_ads'
  granted boolean not null,
  policy_version text not null,
  created_at timestamptz not null default now()
);

create index idx_user_consents_user on user_consents(user_id);

-- Автосоздание профиля при регистрации пользователя.
create function handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- =========================================================================
-- Row Level Security
-- =========================================================================

-- Каталог, цены, магазины — публичное чтение всем (в т.ч. анонимным пользователям
-- до регистрации), запись только через service role (скрапер использует service key,
-- который обходит RLS, — из клиентского приложения писать сюда нельзя).
alter table stores enable row level security;
alter table categories enable row level security;
alter table products enable row level security;
alter table store_products enable row level security;
alter table promotions enable row level security;
alter table price_history enable row level security;

create policy "public read stores" on stores for select using (true);
create policy "public read categories" on categories for select using (true);
create policy "public read products" on products for select using (true);
create policy "public read store_products" on store_products for select using (true);
create policy "public read promotions" on promotions for select using (true);
create policy "public read price_history" on price_history for select using (true);

-- Пользовательские данные — доступ только владельцу.
alter table profiles enable row level security;
alter table shopping_lists enable row level security;
alter table shopping_list_items enable row level security;
alter table favorite_stores enable row level security;
alter table user_consents enable row level security;

create policy "own profile" on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "own shopping lists" on shopping_lists
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own shopping list items" on shopping_list_items
  for all using (
    exists (
      select 1 from shopping_lists sl
      where sl.id = shopping_list_items.list_id and sl.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from shopping_lists sl
      where sl.id = shopping_list_items.list_id and sl.user_id = auth.uid()
    )
  );

create policy "own favorite stores" on favorite_stores
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own consents" on user_consents
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
