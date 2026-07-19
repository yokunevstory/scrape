-- Баг 1: добавление в список покупок (и слежение за сматченным товаром)
-- падало молча. upsert(..., onConflict: 'list_id,product_id') на клиенте
-- превращается в "INSERT ... ON CONFLICT (list_id, product_id) DO UPDATE",
-- БЕЗ предиката WHERE. Postgres не может использовать partial unique index
-- (у него есть WHERE product_id is not null) как арбитр для ON CONFLICT без
-- WHERE в самом ON CONFLICT — получалась ошибка "no unique or exclusion
-- constraint matching the ON CONFLICT specification", необработанная на
-- клиенте. Partial-условие было не нужно: обычный (не partial) unique index
-- и так разрешает сколько угодно строк с NULL — NULL не равен NULL для
-- уникальности. Убираем WHERE, оставляя обычный unique index.
drop index if exists shopping_list_items_list_product_uidx;
drop index if exists shopping_list_items_list_store_product_uidx;
create unique index shopping_list_items_list_product_uidx
  on shopping_list_items(list_id, product_id);
create unique index shopping_list_items_list_store_product_uidx
  on shopping_list_items(list_id, store_product_id);

-- Та же проблема была и у "слежу за товаром" для сматченных товаров
-- (product_id-путь) — store_product_id-путь работал, т.к. его unique
-- constraint остался с исходной таблицы 0006 и не был partial.
drop index if exists watched_products_user_product_uidx;
create unique index watched_products_user_product_uidx
  on watched_products(user_id, product_id);

-- Баг 2: поиск "karbonade" не находил "karbonāde" — искали ровно то, что
-- ввели, без учёта латышских диакритических знаков (ā, č, ē, ģ, ī, ķ, ļ, ņ,
-- š, ū, ž). unaccent приводит и запрос, и название к варианту без диакритики
-- перед сравнением (ā -> a и т.п.), так что раскладка клавиатуры/язык ввода
-- перестают быть проблемой.
create extension if not exists unaccent with schema public;

-- unaccent() помечена STABLE (может зависеть от текущего словаря), а
-- индексное выражение обязано быть IMMUTABLE — иначе "functions in index
-- expression must be marked IMMUTABLE" (сама ошибка, полученная при первой
-- попытке). Словарь "unaccent" не меняется в рантайме, поэтому оборачиваем
-- в свою функцию и просто помечаем её immutable — стандартный приём для
-- этой ситуации. Используем однопараметрический unaccent(text), который
-- extension создаёт сама (а не unaccent(regdictionary, text) с указанием
-- словаря по имени вручную — тот вариант падал с "function unaccent(unknown,
-- text) does not exist", т.к. литерал 'unaccent' не резолвился в regdictionary
-- через search_path).
create or replace function immutable_unaccent(text)
returns text
language sql
immutable
parallel safe
as $$
  select public.unaccent($1);
$$;

create index if not exists idx_store_products_raw_name_unaccent_trgm
  on store_products using gin (immutable_unaccent(raw_name) gin_trgm_ops);

drop function if exists search_products(text, int);

create function search_products(search_query text, result_limit int default 200)
returns table (
  id uuid,
  product_id uuid,
  raw_name text,
  raw_category_path text,
  package_price numeric,
  regular_price numeric,
  unit_price numeric,
  unit_type text,
  is_promo boolean,
  image_url text,
  source_url text,
  store_display_name text,
  store_slug text
)
language sql stable
as $$
  select sp.id, sp.product_id, sp.raw_name, sp.raw_category_path, sp.package_price,
         sp.regular_price, sp.unit_price, sp.unit_type, sp.is_promo, sp.image_url,
         sp.source_url, s.display_name as store_display_name, s.slug as store_slug
  from store_products sp
  join stores s on s.id = sp.store_id
  where immutable_unaccent(sp.raw_name) ilike '%' || immutable_unaccent(search_query) || '%'
     or similarity(immutable_unaccent(sp.raw_name), immutable_unaccent(search_query)) > 0.4
  order by
    case when immutable_unaccent(sp.raw_name) ilike '%' || immutable_unaccent(search_query) || '%'
      then 0 else 1 end,
    similarity(immutable_unaccent(sp.raw_name), immutable_unaccent(search_query)) desc,
    sp.unit_price asc nulls last
  limit result_limit;
$$;

grant execute on function search_products(text, int) to anon, authenticated;
