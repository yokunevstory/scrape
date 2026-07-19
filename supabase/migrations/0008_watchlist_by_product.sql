-- "Следим за одним и тем же товаром во всех магазинах" — если товар сматчен
-- между Rimi и Barbora (products.id, см. scraper/match_products.py), нужно
-- отслеживать канонический товар целиком, а не одно конкретное предложение
-- одного магазина. Если товар ещё не сматчен — отслеживаем как раньше,
-- конкретное предложение (store_product_id).
alter table watched_products add column if not exists product_id uuid references products(id) on delete cascade;
alter table watched_products alter column store_product_id drop not null;
alter table watched_products add column if not exists watched_at_price numeric;

-- Хотя бы одна из целей слежения должна быть указана.
alter table watched_products drop constraint if exists watched_products_target_check;
alter table watched_products add constraint watched_products_target_check
  check (product_id is not null or store_product_id is not null);

-- Отдельный товар можно добавить в слежение только один раз на пользователя
-- (обычный unique(user_id, store_product_id) уже это делает для конкретных
-- предложений; здесь — то же самое для канонического товара).
create unique index if not exists watched_products_user_product_uidx
  on watched_products(user_id, product_id) where product_id is not null;
