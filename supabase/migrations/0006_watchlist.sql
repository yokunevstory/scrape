-- Список отслеживаемых товаров (SPEC.md — "слежу за товаром/ценой, чтобы
-- ловить акции на избранные товары"). Без пуш-уведомлений (это отдельная,
-- более поздняя задача, см. SPEC.md §5 "не входит в MVP") — пользователь
-- открывает список и сразу видит, есть ли сейчас акция на отслеживаемые
-- товары.
create table watched_products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  store_product_id uuid not null references store_products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, store_product_id)
);

alter table watched_products enable row level security;

create policy "own watched products" on watched_products
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
