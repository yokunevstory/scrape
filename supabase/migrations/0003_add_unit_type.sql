-- Единица измерения цены за единицу (kg/l/gab) — нужна, чтобы понимать,
-- что означает unit_price, и чтобы можно было считать/сортировать по
-- реальному весу/объёму упаковки (package_price / unit_price).
alter table store_products add column if not exists unit_type text;
