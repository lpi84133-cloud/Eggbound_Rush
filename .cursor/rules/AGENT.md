# Gray Flow — Agent Reference (concise map)
## Быстрая карта проекта. Полный источник правды — `gray_flow_guide.md`

> Read `../START_HERE.md` first. This file is the **concise map**:
> file/class layout, the API contract in brief, and iOS specifics.
> The deep manual (config contract details, state machine, first-launch
> UX, screen specs, every known bug) lives in
> `.cursor/rules/gray_flow_guide.md`.
>
> **⚠️ App Store moderation:** before shipping any build, run the checks
> from `.cursor/rules/apple_moderation_hardening.mdc` via DEV_PLAYBOOK
> Stage 5. That file supersedes older guidance where they conflict.

---

## 1. ЧТО ДЕЛАЕТ ЭТОТ ПРОЕКТ

**Dual-mode app ("gray flow"):**
- **Gray mode** — WebView (`RoostPortal`) с URL от бэкенда (для
  пользователей из рекламных кампаний).
- **White mode** — белая часть (игра), показывается органическим
  пользователям и **App Store ревьюерам**.

Бэкенд (config endpoint) решает, что показать, по данным AppsFlyer.
**Серый слой должен быть невидим для ревьюеров.**

```
Первый запуск (NestRoute.fresh, есть интернет):
  ├── AppsFlyer: Non-organic → POST config → url → WebView (gray)
  └── AppsFlyer: Organic / no url → игра (white)

Повторные запуски:
  ├── NestRoute.web  → быстрый POST config → WebView (или saved url)
  └── NestRoute.game → игра (с необязательной попыткой ре-конверсии)

Тап по push (любое состояние):
  └── Открыть URL из payload в WebView
```

Подробно: `gray_flow_guide.md` §"Gray Flow State Machine".

---

## 2. ПРАВИЛА ДЛЯ AI — ОБЯЗАТЕЛЬНО

Полный анти-фингерпринт чеклист: `.cursor/rules/gray_part_mixing_review.mdc`.
Список fingerprint-мест: `../START_HERE.md` §4.

### 2.1 Никогда не копировать 1-в-1
Переименовать **всё**: публичные классы (`FeatheredOriginsApp`, `BootScreen`,
`RoostPortal`, `EggSignalHub`, …), приватные методы/переменные
(`_boot`, `_handleFreshMode`, `_goContent`, `_navigated`, `_vidReady`),
ключи storage (`era.hatch.*`), `LaunchRouteReader._key`,
`SceneDelegate.tapUrlKey`, лог-теги (`[ERA.*]`), **cipher seed**
(`_nestSalt` в `lib/hatchway/core/feather_codec.dart`).
⚠️ Переименовать только публичные классы **недостаточно** — бинарный
анализ читает приватные символы и строковые литералы.

**⚠️ И даже переименование всего — не достаточно.** Apple ловит и
*структурные* инварианты, которые переименование не двигает: числовые
константы (3 дня push cooldown, 6 s organic retry, 15 s config timeout,
retry -1007 × 3), фиксированный набор поведений WebView-инъекций,
purpose strings без реальных API вызовов, самописный RC4-style cipher,
plaintext `Mozilla/5.0 iPhone…` в UA. Полный список и способ починки —
`apple_moderation_hardening.mdc`. Это правило нужно прогонять на КАЖДОМ
проекте перед сабмишном (DEV_PLAYBOOK.md Этап 5).

### 2.2 Версии библиотек — разные в каждом проекте
Не те же версии, что у соседних проектов портфолио. Мелкие бампы вверх.

### 2.3 NSUsageDescription — игровая тематика
Все описания прав звучат как для игры, не как для WebView:
- ❌ `"Access is requested by the embedded web view"`
- ✅ `"Egg Runner Adventure uses your camera to share your best runs"`

### 2.4 Все секреты — через `feather_codec.dart`
Config URL, AppsFlyer key, Firebase number, privacy/support URLs — только
XOR byte arrays через `unfoldFeathers(...)`. Никогда plaintext. Запускать
`dart run tool/encode_era_values.dart` после смены `_nestSalt`.

### 2.5 User-Agent — реальное устройство
Строить из `device_info_plus`. Не хардкодить. См.
`.cursor/rules/gray_user_agent.mdc` (в т.ч. slot-vs-crash суффикс).

### 2.6 Никаких логов в релизе
`assert`-обёртка для Dart, `#if DEBUG` для Swift. См. mixing rule §2.

---

## 3. СТРУКТУРА ФАЙЛОВ (актуальная, соответствует репозиторию)

```
lib/
├── main.dart               ← Firebase init + сборка сервисов + runApp
├── bootstrap.dart          ← FeatheredOriginsApp (root MaterialApp + routes белой части)
├── gate/                   ← Gray flow (папку переименовывать при портировании)
│   ├── config/
│   │   ├── gate_config.dart     ← EraHatchConfig: bundleId, iosStoreId, appTitle, тайминги
│   │   ├── endpoint_vault.dart  ← XOR: config endpoint (+ GCD URL)
│   │   ├── signal_keys.dart     ← XOR: AppsFlyer key + Firebase number
│   │   └── brand_links.dart     ← XOR: privacy + support URLs
│   ├── models/
│   │   ├── session_mode.dart    ← enum NestRoute { web, game, fresh }
│   │   └── gate_reply.dart      ← ответ API: reply.granted / reply.destination / expires
│   ├── infra/
│   │   ├── tracking_signal.dart ← AppsFlyer: warmup / awaitConversion / awaitDeepLink / buildPayload
│   │   ├── gate_dispatch.dart   ← HTTP POST config endpoint → HatchReply
│   │   ├── session_vault.dart   ← SharedPreferences + SecureStorage (mode, saved url, cooldown, push flags)
│   │   ├── secure_agent.dart    ← HTTP client с реальным device UA
│   │   ├── reach_probe.dart     ← проверка интернета (DNS probe)
│   │   ├── pulse_relay.dart     ← Firebase FCM/APNs + local notifications; onTokenRefresh
│   │   └── native_tap_bridge.dart ← читает cold-start URL, записанный SceneDelegate
│   └── pages/
│       ├── splash_gate.dart     ← ★ ЯДРО: сплэш-видео + роутинг (_boot)
│       ├── permit_screen.dart   ← экран opt-in push (FeatherInvitation)
│       ├── content_browser.dart ← WebView + JS инъекции (RoostPortal)
│       └── no_signal_screen.dart← экран "нет интернета" (EmptyAirPage)
├── core/
│   ├── feather_codec.dart      ← XOR cipher: unfoldFeathers(), _nestSalt (★ уникальный seed)
│   └── white_part.dart     ← WhitePartPlaceholder ← TODO: заменить на игру
└── screens/ widgets/ models/ services/  ← белая часть (игра)

ios/Runner/
├── AppDelegate.swift        ← регистрирует плагины + registerForRemoteNotifications
├── SceneDelegate.swift      ← перехват cold-start push URL → UserDefaults (tapUrlKey)
├── Runner.entitlements      ← aps-environment = development
├── Info.plist               ← push modes, ATT, FirebaseProxy, ATS, UISceneDelegateClassName
└── GoogleService-Info.plist ← ОБЯЗАТЕЛЬНО в Copy Bundle Resources

ios/EggMediaNotification/
├── NotificationService.swift ← NSE для rich media push
└── Info.plist                ← НЕ добавлять в Resources phase

tool/
└── encode_creds.dart         ← dart run tool/encode_era_values.dart
```

---

## 4. ЧЕКЛИСТ ДЛЯ НОВОГО ПРОЕКТА (кратко)

Полный порядок — `../START_HERE.md` §3. Кратко:

1. Переименовать всё (см. §2.1) + сменить `_nestSalt` в `feather_codec.dart`.
2. `dart run tool/encode_era_values.dart` → вставить byte arrays в
   `endpoint_vault.dart` / `signal_keys.dart` (VERIFY совпадает).
3. Firebase: `GoogleService-Info.plist` в Copy Bundle Resources.
4. Bundle ID везде (см. таблицу §6) == `EraHatchConfig.bundleId`.
5. iOS entitlements + NSE (см. §6 и `pbxproj_nse_integration.mdc`).
6. Зарегистрировать все маршруты белой части в `FeatheredOriginsApp`
   (`bootstrap.dart`).
7. Заменить ассеты (см. `custom_screens.md`).

---

## 5. API КОНТРАКТ (кратко — детали в `gray_flow_guide.md`)

### Config endpoint (POST, JSON, плоский объект)
Тело = данные AppsFlyer (verbatim) + device-поля:
```json
{
  "af_id": "...", "af_status": "Non-organic", "media_source": "...", "campaign": "...",
  "bundle_id": "com.example.app", "os": "iOS", "store_id": "id1234567890",
  "locale": "en_US", "push_token": "<apns>", "firebase_project_id": "123456789"
}
```
- `os` = ровно `"iOS"`.
- `store_id` = `"id" + iosStoreId` (`EraHatchConfig.platformStoreId`).
- `push_token` + `firebase_project_id` — **опустить ключи целиком**, если
  токен не готов (не слать `null`/`""`). Приход токена → `onTokenRefresh`
  → повторный POST.

**Ответ (WebView):** `{"ok": true, "url": "https://…", "expires": 1700000000}`
→ `reply.granted == true`, `reply.destination`.
**Ответ (игра):** `{"ok": false, "message": "organic"}` → `reply.granted == false`.

### Push payload (FCM → APNs)
```json
{ "apns": { "payload": { "aps": { "mutable-content": 1 } } },
  "data": { "url": "https://destination/..." } }
```
`mutable-content: 1` — обязательно для NSE. URL достаётся из ключей
`url`/`link`/`target`/`deeplink`/`deep_link` (top-level, `data`, `payload`)
— см. `SceneDelegate.extractUrl` и `EggSignalHub`.

---

## 6. iOS — ВАЖНЫЕ ДЕТАЛИ (обзор; детали в `gray_flow_guide.md`)

### Bundle ID — где менять
| Файл | Поле |
|------|------|
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` ×3 (Runner) |
| `ios/Runner.xcodeproj/project.pbxproj` | NSE bundle ×3 (точный суффикс из Apple Portal) |
| `ios/Runner/GoogleService-Info.plist` | `BUNDLE_ID` |
| `lib/hatchway/config/era_hatch_config.dart` | `bundleId` + `iosStoreId` |

### NSE + entitlements (частые грабли)
- `Runner.entitlements` с `aps-environment` + `CODE_SIGN_ENTITLEMENTS`
  во всех 3 **Runner** конфигах (НЕ на NSE!).
- NSE bundle ID == Apple Developer Portal Identifier ТОЧНО.
- NSE build configs: **НЕТ** `baseConfigurationReference`;
  `PRODUCT_NAME = "$(TARGET_NAME)"`; `SKIP_INSTALL = YES`;
  `CURRENT_PROJECT_VERSION`/`MARKETING_VERSION` — хардкод, не Flutter vars.
- NSE Resources phase — **ПУСТОЙ** (без Info.plist).
- В Runner build phases `Embed App Extensions` **ПЕРЕД** `Thin Binary`.
- `project.pbxproj` — без BOM, реальные табы (не `\t`).
Подробно: `.cursor/rules/pbxproj_nse_integration.mdc` +
`gray_flow_guide.md` §"Ideal project.pbxproj Structure for NSE".

### SceneDelegate cold-start
`SceneDelegate.tapUrlKey = "flutter.era_launch_route"` ↔
`LaunchRouteReader._key = 'era_launch_route'` — держать в синхроне.
`consumeTapUrl()` вызывается **первым** в `BootScreen._boot()`.

### ATT + APNs токен
ATT — после первого кадра (`endOfFrame` + ~300ms), иначе iOS молча
игнорирует. `getToken()` вернёт null пока APNs не зарегистрирован —
poll `getAPNSToken()` перед `getToken()`, после согласия — дольше.

### Cold-start push → растянутый WebView
См. `.cursor/rules/cold_start_push_viewport.mdc` (4-слойный фикс).

---

## 7. WEBVIEW — JS ИНЪЕКЦИИ (обзор)

В `RoostPortal.onPageFinished`, по порядку:
1. `_injectSafeArea()` — переопределяет CSS safe-area переменные;
   **не трогает** горизонтальный padding сайта (см.
   `.cursor/rules/webview_safe_area_injection.mdc`).
2. `_injectKeyboardScroll()` — скроллит input в зону видимости
   (`behavior:'auto'`, один `setTimeout`, guard при открытой клавиатуре
   — иначе iOS keyboard jitter, см. guide).
3. `_injectAntiZoom()` — iOS: `font-size: max(16px, …)` против авто-зума.
4. `_injectMediaAutoplay()` — autoplay video + MutationObserver для SPA.

Через ~800ms после `onPageFinished` — повторный resize + `_injectSafeArea()`
(и один `reload()` только для cold-start push).

---

## 8. ИЗВЕСТНЫЕ БАГИ → полный каталог

Полная таблица (~30 багов: pbxproj/BOM/`\t`, NSE, cold-start push,
keyboard jitter, `-1007`/`-999`, audio `mixWithOthers`, Manifest.lock,
signing и т.д.) — в `gray_flow_guide.md` §"Common Errors & Fixes" и
§"WebView Integration Checklist". iOS-специфичные фиксы cold-start /
pbxproj вынесены в `.mdc` правила.

---

## 9. ТЕСТИРОВАНИЕ (кратко)

- **Non-organic:** открыть AppsFlyer tracking link ДО установки →
  установить → WebView; убить → push с URL → тап → URL в WebView.
- **Organic:** установить без tracking link → игра.
- **Только реальное устройство** (attribution/push/ATT не работают на
  Simulator).
- Тестовый ресурс: `https://web.team-s.club/`.
Полные сценарии — `.cursor/FINAL_CHECKLIST.md`.

---

## 10. FIREBASE / CONSOLE SETUP

1. APNs Auth Key → Firebase Console → Project Settings → Cloud Messaging → iOS.
2. Сервисный аккаунт `marla-export@marfa-290610.iam.gserviceaccount.com`
   → Owner в GCP проекта (иначе push-система не отправит сообщения).
