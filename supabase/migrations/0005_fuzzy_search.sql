-- Нечёткий поиск по названию товара (устойчивый к опечаткам, например
-- "bezpiens" вместо "biezpiens") — обычный ILIKE ищет только точные
-- подстроки и не находит такие опечатки. pg_trgm считает похожесть по
-- триграммам символов, что и нужно для устойчивого поиска.
create extension if not exists pg_trgm;

create index if not exists idx_store_products_raw_name_trgm
  on store_products using gin (raw_name gin_trgm_ops);

create or replace function search_products(search_query text, result_limit int default 200)
returns table (
  id uuid,
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
  select sp.id, sp.raw_name, sp.raw_category_path, sp.package_price, sp.regular_price,
         sp.unit_price, sp.unit_type, sp.is_promo, sp.image_url, sp.source_url,
         s.display_name as store_display_name, s.slug as store_slug
  from store_products sp
  join stores s on s.id = sp.store_id
  where sp.raw_name ilike '%' || search_query || '%'
     or similarity(sp.raw_name, search_query) > 0.2
  order by
    case when sp.raw_name ilike '%' || search_query || '%' then 0 else 1 end,
    similarity(sp.raw_name, search_query) desc,
    sp.unit_price asc nulls last
  limit result_limit;
$$;

-- Разрешаем вызов этой функции анонимным и авторизованным пользователям
-- (каталог товаров публичный, см. политики "public read" в 0001).
grant execute on function search_products(text, int) to anon, authenticated;
