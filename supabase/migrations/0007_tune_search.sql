-- Уточнение поиска (0005_fuzzy_search.sql):
-- 1) Порог похожести 0.2 был слишком низким — запрос "biezpiens" находил
--    обычный "piens" (много общих триграмм в суффиксе). Подняли до 0.4.
-- 2) Добавили product_id в результат — нужен для "слежу за товаром во всех
--    магазинах" (если товар сматчен между Rimi и Barbora, кнопка "следить"
--    должна отслеживать канонический товар, а не одно конкретное предложение).
-- Нельзя просто "create or replace" — меняется состав колонок результата
-- (добавился product_id), а Postgres такое реплейс-обновление не разрешает.
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
  where sp.raw_name ilike '%' || search_query || '%'
     or similarity(sp.raw_name, search_query) > 0.4
  order by
    case when sp.raw_name ilike '%' || search_query || '%' then 0 else 1 end,
    similarity(sp.raw_name, search_query) desc,
    sp.unit_price asc nulls last
  limit result_limit;
$$;

grant execute on function search_products(text, int) to anon, authenticated;
