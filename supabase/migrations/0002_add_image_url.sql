-- Добавляет картинку товара (берётся из открытых данных магазина при
-- скрапинге, см. SPEC.md — раздел про изображения товаров).
alter table store_products add column if not exists image_url text;
