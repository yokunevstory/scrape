# Google Play Console — данные для создания приложения

Готовые к вставке тексты и графика для заполнения Play Console, плюс список того, что
блокирует реальную публикацию и нужно от вас. Пакет: `lv.centik.app` (см. HANDOFF.md).

## Что реально блокирует публикацию (по порядку важности)

1. ~~Политика конфиденциальности не захостена.~~ **Решено (2026-07-27).** Захостил через GitHub
   Pages (`docs/`, включено через GitHub API — Settings → Pages: source = `main` / `/docs`):
   - Privacy Policy: **https://yokunevstory.github.io/scrape/privacy-policy/**
   - Account deletion: **https://yokunevstory.github.io/scrape/account-deletion/**

   Эти два URL — вставить в Play Console (App content → Privacy policy, и в Data safety →
   раздел про удаление данных). Ещё не пройдена юридическая проверка текста и остаётся пара
   мелких операционных плейсхолдеров (сроки ответа на запрос удаления — сейчас 10 рабочих
   дней / 30 дней, это уже осознанный выбор срока, не идентификация, оставил как разумные
   значения по умолчанию).
2. **В приложении нет доступа без входа.** `AuthGate` (`app/lib/auth/auth_gate.dart`) всегда
   показывает экран входа/регистрации, если нет сессии — гостевого просмотра каталога нет.
   Ревьюеру Google нужен рабочий тестовый аккаунт (email+пароль) в разделе **App content → App
   access**. Если в Supabase Auth включено подтверждение email — либо завести тестовый аккаунт
   с уже подтверждённым email вручную (через SQL Editor: `update auth.users set
   email_confirmed_at = now() where email = '...'`), либо временно выключить подтверждение для
   тестового пользователя — иначе ревьюер не пройдёт дальше экрана входа.
3. ~~Release-сборка подписывается debug-ключом.~~ **Решено (2026-07-27).** Сгенерировал
   реальный upload-key (`android/upload-keystore.jks`, гитигнорится), собрал
   `app-release.aab` (55.5 MB), проверил `keytool -printcert` — подписан новым ключом, не
   debug. Файл: `app/build/app/outputs/bundle/release/app-release.aab` — его нужно перетащить
   в форму загрузки на скриншоте выпуска. Подробности и как пересобрать — SETUP.md §9.
   **Важно:** сохраните резервную копию файла ключа и пароля (сообщён в чате отдельно) — без
   него нельзя будет публиковать обновления.
4. **Скриншоты телефона** — нужно минимум 2 (макс. 8), сам сгенерировать без реального
   Android-эмулятора/устройства с данными не могу — см. раздел «Графика» ниже.

Всё остальное ниже — готовые тексты, можно вставлять сразу.

## 1. Создание приложения (первый диалог в Play Console)

| Поле | Значение |
|---|---|
| App name | `Centik` |
| Default language | Latviešu (lv-LV) — основной рынок |
| App or game | App |
| Free or paid | Free |
| Declarations | Developer Program Policies и US export laws — подтвердить (стандартные чекбоксы) |

## 2. Store listing — тексты (заполнить отдельно для lv/ru/en — Play поддерживает мультиязычные листинги)

### 🇱🇻 Latviešu (lv-LV) — основной

**App name (≤30 симв., 26 факт.):** `Centik: cenu salīdzinājums`

**Short description (≤80 симв., 61 факт.):**
```
Salīdzini cenas Rimi, Maxima, LaTS — uzzini, kur pirkt lētāk.
```

**Full description (≤4000 симв., ~976 факт.):**
```
Centik palīdz ietaupīt naudu ikdienas iepirkumos, salīdzinot cenas trīs lielākajos Latvijas veikalu tīklos — Rimi, Maxima un LaTS — vienuviet.

KĀ TAS DARBOJAS
• Meklē jebkuru produktu vai pārlūko kategorijas — uzreiz redzi cenas visos pievienotajos veikalos.
• Salīdzini ne tikai cenu par iepakojumu, bet arī cenu par vienību (€/kg, €/l, €/gab.) — lai zinātu, kurš piedāvājums patiešām ir izdevīgāks.
• Izveido iepirkumu sarakstu un uzreiz uzzini, kurā veikalā visu sarakstu nopirkt lētāk — vai izdevīgāk sadalīt pirkumu starp vairākiem veikaliem.
• Pievieno produktus sekošanai un uzzini, kad tiem parādās akcija vai krītas cena.
• Pārlūko visas aktuālās akcijas no visiem veikaliem vienā sarakstā.

KĀPĒC CENTIK
• Dati par cenām tiek atjaunoti katru dienu.
• Lietotne pieejama latviešu, krievu un angļu valodā.
• Pilnībā bezmaksas.

Cenas tiek apkopotas no publiski pieejamām veikalu tīmekļa vietnēm un var atšķirties no aktuālās cenas konkrētajā veikalā uz konkrētu brīdi.
```

### 🇷🇺 Русский (ru-RU)

**App name (26 симв.):** `Centik: сравнение цен`

**Short description (63 симв.):**
```
Сравнивай цены Rimi, Maxima и LaTS — экономь на каждой покупке.
```

**Full description (~1022 симв.):**
```
Centik помогает экономить на повседневных покупках, сравнивая цены в трёх крупнейших сетях магазинов Латвии — Rimi, Maxima и LaTS — в одном приложении.

КАК ЭТО РАБОТАЕТ
• Ищите любой товар или листайте категории — сразу видите цены во всех подключённых магазинах.
• Сравнивайте не только цену за упаковку, но и цену за единицу измерения (€/кг, €/л, €/шт) — чтобы понимать, какое предложение действительно выгоднее.
• Составляйте список покупок и сразу узнавайте, в каком магазине выгоднее купить всё сразу — или что выгоднее разделить покупки между несколькими магазинами.
• Добавляйте товары в отслеживаемые и узнавайте, когда на них появляется акция или падает цена.
• Смотрите все актуальные акции всех магазинов в одном месте.

ПОЧЕМУ CENTIK
• Данные о ценах обновляются каждый день.
• Приложение доступно на латышском, русском и английском языках.
• Полностью бесплатно.

Цены собираются из открытых источников (сайты интернет-магазинов) и могут отличаться от актуальной цены в конкретном магазине на момент покупки.
```

### 🇬🇧 English (en-US)

**App name (24 chars):** `Centik: Price Comparison`

**Short description (61 chars):**
```
Compare prices at Rimi, Maxima and LaTS — save on every shop.
```

**Full description (~956 chars):**
```
Centik helps you save money on everyday shopping by comparing prices across Latvia's three biggest grocery chains — Rimi, Maxima, and LaTS — all in one app.

HOW IT WORKS
• Search for any product or browse categories — instantly see prices across every connected store.
• Compare not just the package price, but the price per unit (€/kg, €/L, €/pc) — so you know which deal is actually the better one.
• Build a shopping list and instantly see which store is cheapest for everything — or whether splitting your list across stores saves even more.
• Add products to your watchlist and get notified when a deal appears or the price drops.
• Browse every current deal from every connected store in one place.

WHY CENTIK
• Prices are refreshed daily.
• Available in Latvian, Russian, and English.
• Completely free.

Prices are collected from publicly available store websites and may differ from the current price in a specific store at the time of purchase.
```

## 3. Категория и контакты

| Поле | Значение |
|---|---|
| Category | Shopping (Iepirkšanās / Покупки) |
| Tags | 2-5 тегов из списка Play Console — ближайшие по смыслу: Shopping, Price comparison / Deals, Lifestyle (точный список тегов есть только внутри консоли, подставить максимально близкие) |
| Contact email | info@yokunev.com |
| Phone | — (необязательно) |
| Website | — (необязательно; если заведёте хостинг для Privacy Policy, тот же URL можно указать и как website) |

## 4. Графика

Сгенерировал и положил в [`store_listing/`](store_listing/) — в стиле приложения (тот же тил
`#0E696F`/навy `#0D1B38`, что и в `app/lib/theme/app_theme.dart` и иконке):

- [`icon_512.png`](store_listing/icon_512.png) — hi-res иконка 512×512, 32-bit PNG (ресайз из
  существующего `app/assets/icon/app_icon.png`, готова к загрузке как есть).
- [`feature_graphic_1024x500.png`](store_listing/feature_graphic_1024x500.png) — Feature
  Graphic 1024×500, сгенерировал сам (иконка + вордмарк + тэглайн на латышском). Это черновой
  вариант, можно доработать в дизайнере позже, но для первой подачи годится.

**Не хватает — скриншоты телефона (мин. 2, макс. 8, JPEG/PNG).** Сгенерировать без реального
запуска приложения на устройстве/эмуляторе с настоящими данными не могу — нужно либо снять
самому через `flutter run` на эмуляторе/телефоне (5-6 экранов: каталог, поиск, список покупок с
разбивкой по магазинам, акции, карточка сопоставленного товара), либо попросить меня помочь
через preview-эмулятор в следующей сессии, когда будет время это сделать вместе.

## 5. Content rating (анкета IARC)

Заполняется анкетой внутри консоли, ожидаемые честные ответы:

- Насилие, секс, ненормативная лексика, азартные игры, ужасы — **нет** ни в одной категории.
- **Алкоголь/табак/наркотики — вероятно, придётся ответить "да, упоминается/продаётся".**
  Каталог включает обычные товары магазинов, в том числе алкоголь (например, в данных уже
  встречается "Tekila JOSE CUERVO" и т.п. — см. проверку Supabase в HANDOFF.md). Это нормально
  для шопинг-приложения и не блокирует публикацию, но по итогу анкеты рейтинг будет не «Everyone»,
  а что-то вроде PEGI 12/16 в разных регионах — не пугайтесь, это ожидаемо.
- User-generated content — **нет** (нет отзывов/комментариев/чата, весь контент — цены от
  скраперов, не от пользователей).
- Использование геолокации устройства — **нет** (AndroidManifest запрашивает только
  `INTERNET`, доступа к геолокации нет).
- Обмен персональными данными между пользователями — **нет** (нет соцфункций, профилей других
  пользователей и т.п.).

## 6. Target audience & content

- Целевая аудитория: **18+ / общая аудитория, не ориентировано на детей.** Обоснование: есть
  аккаунты с email, показывается реклама (AdMob), в каталоге есть алкоголь — типичные признаки
  приложения не для детей. Не отмечать программу Designed for Families.
- Ads: **Yes** — приложение показывает рекламу (AdMob, `app/lib/ads/`).
- In-app purchases: **No** — сейчас нет платных функций.

## 7. Data safety

На основе `legal/PRIVACY_POLICY.md` и текущего кода:

| Тип данных | Собирается? | Цель | Передаётся третьим лицам? | Обязательно/опционально |
|---|---|---|---|---|
| Email адрес | Да | Создание и работа аккаунта | Нет | Обязательно (для использования приложения) |
| User ID | Да (Supabase auth UID) | Работа аккаунта | Нет | Обязательно |
| App activity → другой контент, создаваемый пользователем (списки покупок, избранное, отслеживаемые товары) | Да | Основная функциональность приложения | Нет | Обязательно |
| Device or other IDs → Advertising ID | Да (через Google AdMob) | Реклама | **Да, Google (AdMob)** | Опционально (персонализация рекламы — по согласию, см. §5 Privacy Policy) |

- Шифрование при передаче: **Да** (HTTPS/TLS, Supabase + Flutter networking).
- Пользователь может запросить удаление данных: **Да**, но честно — сейчас это email-процесс
  (`legal/ACCOUNT_DELETION_POLICY.md`), автоматическая Edge Function для in-app удаления ещё не
  подключена (см. `deleteAccountDialogContent` в `lib/l10n/app_ru.arb`). В форме Data Safety
  указывать реальный процесс (email-запрос с проверкой личности), а не «полностью
  автоматизировано в приложении» — иначе это будет неточная декларация.

## 8. App access (для ревьюеров Google)

Раздел **App content → App access**: выбрать «All or some functionality is restricted» и
указать инструкцию + тестовые учётные данные (email/пароль рабочего аккаунта), см. блокер №2
выше — без входа ревьюер не увидит вообще ничего в приложении.

## 9. Ads declaration

**Contains ads: Yes.** Отдельно от рейтинга — не забыть флажок в разделе App content, там же,
где и Content rating/Target audience.

---

*Составлено 2026-07-25. Обновить этот файл, если поменяются тексты локализации, магазины или
структура данных (Data safety должна отражать реальный код, см. `HANDOFF.md`).*
