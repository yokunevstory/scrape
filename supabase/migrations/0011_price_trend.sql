-- Индикатор изменения цены за последнюю неделю (маленькая стрелка на
-- карточке товара — обсуждение в чате 2026-07-28). Каждый прогон скрапера
-- пишет новую строку в price_history независимо от того, изменилась цена
-- или нет (см. scraper/supabase_writer.py: insert_price_history), поэтому
-- сравнивать нужно не с "предыдущей строкой", а с последней ценой, которая
-- была известна не позже 6 дней назад — это и есть "цена неделю назад".
--
-- distinct on берёт для каждого store_product_id только одну (самую свежую
-- среди тех, что старше 6 дней) строку — без этого сравнение "потекло" бы
-- при ежедневном скрапинге без изменения цены.
create or replace view store_product_price_trend as
select distinct on (store_product_id)
  store_product_id,
  price as price_week_ago
from price_history
where observed_at <= now() - interval '6 days'
order by store_product_id, observed_at desc;

grant select on store_product_price_trend to anon, authenticated;
