-- "Список" переделан: раньше позиции были свободным текстом (нужен был
-- поиск по каждому названию при открытии экрана — медленно и непонятно).
-- Теперь список работает так же, как "отслеживаемые товары" — добавляем
-- конкретный товар с карточки (значок корзины), а не текст.
alter table shopping_list_items add column if not exists store_product_id uuid references store_products(id) on delete cascade;

alter table shopping_list_items drop constraint if exists shopping_list_items_target_check;
alter table shopping_list_items add constraint shopping_list_items_target_check
  check (product_id is not null or store_product_id is not null or custom_name is not null);

create unique index if not exists shopping_list_items_list_product_uidx
  on shopping_list_items(list_id, product_id) where product_id is not null;
create unique index if not exists shopping_list_items_list_store_product_uidx
  on shopping_list_items(list_id, store_product_id) where store_product_id is not null;
