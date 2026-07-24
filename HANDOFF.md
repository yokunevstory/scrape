# HANDOFF — PriceCompare LV

Контекст для продолжения работы в новом окне/сессии. Дата: 2026-07-23.
Репозиторий: https://github.com/yokunevstory/scrape (ветка `main`, рабочее дерево чистое,
всё запушено — последний коммит `f11f637`).

## Что это за проект

Мобильное приложение (Flutter, Android-first) для сравнения цен на продукты между магазинами
Латвии, бэкенд — Supabase. Пользователь — info@yokunev.com, общается по-русски, интерфейс
приложения на русском, латышском и английском (переключается в профиле, `lib/l10n/app_ru.arb`/
`app_lv.arb`/`app_en.arb`).

**Название приложения выбрано: `Centik`.** Переименовано в коде: `lib/l10n/app_ru.arb`/`app_lv.arb`
(`appTitle`), Android `applicationId`/`namespace` (`lv.centik.app` в `android/app/build.gradle.kts`),
`android:label` в `AndroidManifest.xml`, `MainActivity.kt` перенесён в пакет `lv/centik/app`,
iOS `PRODUCT_BUNDLE_IDENTIFIER` (`ios/Runner.xcodeproj/project.pbxproj`) и `CFBundleDisplayName`
(`ios/Runner/Info.plist`), внутренний класс `PriceCompareApp` → `CentikApp` в `lib/main.dart`.
`pubspec.yaml` (`name: app`) не трогали — некритично. Иконка/сплэш оставлены как есть.
`flutter analyze` и `flutter build apk --debug` прошли чисто после переименования.
Старый `CartPilot` — занято, не использовать.

## Магазины — источники данных

1. **Rimi** (rimi.lv/e-veikals) — `scraper/rimi_scraper.py`, есть JSON category-tree API.
2. **Maxima** (данные с barbora.lv, maxima.lv блокирует краулеры) — `scraper/barbora_scraper.py`.
3. **LaTS** (e-latts.lv) — `scraper/lats_scraper.py`, добавлен позже, полноценный интернет-магазин
   (~402 категории), парсится через `html.parser` (НЕ lxml — lxml роняет атрибуты вида `-id`,
   `-price` с ведущим дефисом).

**Проверены и отклонены** (нет полноценного каталога, только акции недели или требуют OCR):
Lidl (lidl.lv — всего ~69 товарных страниц на весь сайт, буклеты — картинки), Elvi, Mego, Top!
(etop.lv — частично лучше, но тоже только акции). Другие сети Латвии, которые не проверяли:
Solo, Netto, Beta, Sky, Aibe, IKI.

Текущий объём данных (на момент последнего полного прогона): ~36 000+ store_products,
~1400 сматченных канонических товаров, ~7000 акционных позиций.

## Архитектура

- **Supabase**: два проекта — основной (app) и архивный (price history, SCD-2). Схема —
  `supabase/migrations/0001..0010_*.sql`, накатывается вручную пользователем через SQL Editor
  (я не имею туда прямого доступа, только через `scraper/.env` service-role ключи для REST).
- **Скраперы** (`scraper/`): `rimi_scraper.py`, `barbora_scraper.py`, `lats_scraper.py` —
  однотипный интерфейс (`_session()`, `fetch_category_tree()`, `iter_leaf_category_urls()`,
  `scrape_category()`), запускаются через общий `run_to_supabase.py --store {rimi,barbora,lats}`.
  `supabase_writer.py` — запись с ретраями на временные 5xx/сетевые ошибки
  (`_request_with_retry`), т.к. долгие прогоны иногда ловят transient-сбои Supabase.
- **Сопоставление товаров** (`scraper/match_products.py`) — теперь поддерживает N магазинов
  (не только Rimi/Barbora): Фаза A донабирает несопоставленные товары к уже существующим группам,
  Фаза B ищет новые группы через попарное сравнение + Union-Find для транзитивности, с
  пост-валидацией группы целиком (защита от того, что A~B и B~C сматчены, а A~C — конфликтуют).
  Есть гейты на конфликт бренда/газации/жирности/вида мяса-рыбы/размера упаковки.
- **Автоскрапинг**: `.github/workflows/scrape.yml` — ежедневно по расписанию гоняет все 3
  магазина + матчинг. 4 GitHub Secrets заведены (см. ниже). **2026-07-24: перестроен на
  параллельные matrix-джобы** (`scrape` по `[rimi, barbora, lats]` + отдельная `match`,
  которая стартует через `needs: scrape` и `if: ${{ !cancelled() }}`) — раньше все три магазина
  шли последовательно в одной джобе с `timeout-minutes: 180` на всё сразу, и как только
  суммарное время выросло (Rimi/Barbora сами стали дольше + добавился LaTS), джоба стабильно
  обрывалась на середине несколько дней подряд: по данным из Supabase на 2026-07-24 LaTS не
  обновлялся с 21.07, а матчинг не рос с 22.07 (застрял на ~1400/2953). Проверял через
  `https://api.github.com/repos/yokunevstory/scrape/actions/workflows/scrape.yml/runs` —
  репозиторий публичный, историю прогонов видно без токена (детальные логи шагов — нет,
  GitHub требует прав администратора репо). После фикса — не проверено вживую, что новый
  workflow укладывается в расписание; стоит посмотреть вкладку **Actions** через день-два.
  Отдельно: ручной перезапуск (`workflow_dispatch`) 24.07 в 15:56 — Rimi упал почти сразу
  (не таймаут, судя по времени), причину не выяснил (нет доступа к логам) — если повторится,
  смотреть в самом интерфейсе Actions.
- **Flutter-приложение** (`app/lib/`):
  - `screens/` — catalog (каталог+баннер), search, category_products, subcategory_list,
    matched_products (сворачиваемые категории), watchlist, basket (список покупок с поиском
    внутри и разбивкой по магазинам), promotions (реальные акции, не мок), profile (язык,
    реклама, аккаунт), sign_in, splash.
  - `data/` — `models.dart` (StoreProductRow, MatchedProduct, WatchlistEntry, BasketSummary),
    `product_repository.dart`, `shopping_list_repository.dart`, `watchlist_repository.dart`,
    `top_categories.dart` (категории каталога, ключи для локализации).
  - `l10n/` — `app_ru.arb`/`app_lv.arb`/`app_en.arb` (исходники, ru — template-файл в
    `l10n.yaml`), `gen/` (сгенерированное, в .gitignore, пересоздаётся `flutter gen-l10n`
    автоматически при `flutter pub get`/build/`flutter analyze`).
  - `app_settings/locale_controller.dart` — текущий язык, персистится в SharedPreferences.
  - `ads/` — AdMob (баннеры на catalog и promotions, **сейчас тестовые ID Google**, см. ниже).
  - `widgets/` — переиспользуемые: `product_card.dart`, `matched_product_card.dart`,
    `collapsible_category_section.dart`, `watch_button.dart`, `add_to_list_button.dart`,
    `ad_banner.dart`, `product_results_list.dart`.

## Что нужно от пользователя (не могу сделать сам)

Всё собрано в [`SETUP.md`](SETUP.md):
1. §1-2 — Supabase-проекты и миграции (предположительно уже сделано, приложение работает).
2. §5 — 4 GitHub Secrets для автоскрапинга (`SUPABASE_APP_URL`, `SUPABASE_APP_SERVICE_KEY`,
   `SUPABASE_ARCHIVE_URL`, `SUPABASE_ARCHIVE_SERVICE_KEY`) — **заведены** (подтверждено
   пользователем 2026-07-23). `gh` CLI в этой среде нет, но репозиторий публичный — историю
   прогонов workflow можно смотреть через `curl https://api.github.com/repos/yokunevstory/
   scrape/actions/workflows/scrape.yml/runs` без токена (детальные логи шагов — нет, там нужны
   права администратора репо). См. фикс таймаута выше.
3. §6 — AdMob-аккаунт (admob.google.com) → прислать App ID и Ad unit ID, я подставлю вместо
   тестовых в `AndroidManifest.xml` и `lib/ads/ad_config.dart`.

## Бэклог (SPEC.md §16)

- Push-уведомления об акциях/падении цены (сейчас только рамка на карточке при открытии).
- Другие магазины сверх Rimi/Maxima/LaTS (список кандидатов — см. выше).
- Финальное имя приложения (см. начало этого файла).

## Важные уроки / грабли (чтобы не наступать снова)

- **LaTS-скрапер**: используйте `BeautifulSoup(html, "html.parser")`, не `"lxml"` — lxml молча
  выбрасывает HTML-атрибуты с ведущим дефисом (`-id`, `-price`), это ломает парсинг карточек.
- **Supabase upsert + partial unique index** — `ON CONFLICT` от PostgREST не видит partial-индексы
  (с `WHERE`) как арбитра. Если нужен upsert по колонке, которая может быть NULL — обычный
  (не partial) unique index уже сам разрешает много NULL, WHERE не нужен.
- **pg_trgm/unaccent для поиска без гарумзиме** — `unaccent()` не IMMUTABLE, для индекса нужна
  своя IMMUTABLE-обёртка; вызывать однопараметрический `unaccent(text)`, а не двухпараметрический
  с ручным указанием словаря (падает "function unaccent(unknown, text) does not exist").
  Готовое решение — `supabase/migrations/0010_fix_add_to_list_and_accents.sql`.
  - Крупные прогоны скрапера/матчинга — **пагинировать** любую выборку из Supabase
    (`fetch_all_store_products` в match_products.py ловил баг: лимит по умолчанию 5000 строк
  при 36000+ товарах в базе давал 0 совпадений, т.к. в окно попадали товары в основном одного
  магазина).
- **IndexedStack (нижняя навигация)** — вкладки не пересоздаются при переключении, поэтому
  экран "Список" не узнавал о товарах, добавленных с других вкладок, пока не заведён
  принудительный `reload()` через `GlobalKey` в `home_shell.dart`.
- **Категории между магазинами** — Rimi/Barbora/LaTS называют одни и те же разделы по-разному
  (напр. "jūrasveltes" слитно vs "jūras veltes" через пробел, "Gatavā kulinārija" vs
  "Kulinārija") — везде, где паттерн один на всех магазинов, рискуете потерять один магазин
  целиком. Решение — `orPatterns` в `top_categories.dart` + `.or()`-фильтр в
  `product_repository.dart`.
- **Windows Git Bash + Python** — пути вида `/c/Users/...` не всегда понимает Windows-Python
  при передаче через `python -c "..."` heredoc; безопаснее использовать `Read`-тул для файлов
  из scratchpad, а не второй `python -c` с тем же путём.

## Как продолжать

Скрипты сборки/тестов — стандартные: `flutter analyze`, `flutter test`,
`flutter build apk --debug --dart-define-from-file=env/dev.json` из `app/`. Скраперы — из
`scraper/`, `.env` там уже есть (в .gitignore). Коммитить и пушить в `main` — обычная практика
в этой сессии (пользователь ожидает, что изменения сразу уходят в GitHub).
