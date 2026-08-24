# Gray Flow — Full Integration Guide (iOS only)
## Single source of truth for building a gray-part Flutter app from a brief

Read `../START_HERE.md` first for the index, the fingerprint list and the
invariants. This document is the deep manual: the API contract, the state
machine, the setup manual and every known bug. Read top-to-bottom before
writing code; every section is a hard invariant unless it says otherwise.

> **File names in this guide match the actual repository** (`lib/hatchway/…`,
> `BootScreen`, `RoostPortal`, `EggSignalHub`, `LaunchRouteReader`,
> `feather_codec.dart`, `encode_era_values.dart`). When you rename things per
> project (you must — see the mixing rule), translate accordingly.
>
> **⚠️ Two structural notes for THIS template (the code is source of truth):**
> - The routing pipeline lives in **`HatchCoordinator.decide`** (this guide's
>   `BootScreen._boot`/`_handleFreshMode` state-machine narrative maps onto it).
>   `decide()` de-dupes concurrent calls but clears its cache on completion so
>   the offline Retry re-runs the whole pipeline.
> - Encoded creds are consolidated in **`hatchway/config/era_hatch_config.dart`**
>   (no separate `endpoint_vault`/`signal_keys`/`brand_links`).
> - **Before trusting any snippet below, cross-check `gray_flow_lessons.md`** —
>   it lists the spots where the original template misled and the corrected
>   behaviour that is already implemented here (WKWebView `isForMainFrame` null,
>   immediate offline, gate predicate w/o OneLink, AppCheck independence,
>   cold-start orientation, rotation reflow, zoom/tap/overscroll, GCD id, creds
>   verify, asset quality).

> **This template targets iOS only.** The push subsystem is APNs + a
> Notification Service Extension (NSE) + SceneDelegate cold-start capture
> + ATT. Do not add Android build config, manifests, notification
> channels, or Android-specific rules to this project.

---

## How to Use This Document (for AI agents)

You will typically receive one customer message with a brief + partial
credentials. Produce a complete, buildable Flutter project. Do it in this
order:

1. **Parse the brief against §"Inputs You Need Before Generating".** If a
   ★ input is missing (endpoint, AppsFlyer key, Firebase config, iOS App
   Store numeric id, privacy URL, cipher seed, slot-vs-crash theme), ask
   in one batched question. Do not scaffold placeholders that silently
   break.
2. **Diversify the fingerprint** (`../START_HERE.md` §4 +
   `gray_part_mixing_review.mdc`). Renaming public classes is NOT enough.
3. **Fill the config layer** (`gate_config.dart`, `brand_links.dart`,
   then encode via `tool/encode_era_values.dart` into `endpoint_vault.dart` /
   `signal_keys.dart`) with a fresh `_nestSalt` cipher seed.
4. **Wire the state machine** — all routing lives in
   `lib/screens/boot_screen.dart` (`BootScreen._boot()`). Do not
   scatter it across the tree.
5. **Wire iOS push** (NSE + entitlements + SceneDelegate) — the most
   error-prone step. See §"Setup Checklist" Step 7 +
   `pbxproj_nse_integration.mdc`.
6. **Build the shell screens** — `permit_screen.dart`,
   `no_signal_screen.dart`, `content_browser.dart` — per §"Screen Layout"
   and `custom_screens.md`.
7. **Register white-part routes** in `FeatheredOriginsApp` (`bootstrap.dart`).
8. **Apply every fix** from §"Common Errors & Fixes" and the `.mdc`
   rules proactively.
9. **Verify** with `FINAL_CHECKLIST.md` on a real device.

Companion rules, all in `.cursor/rules/`:

- `pbxproj_nse_integration.mdc` — NSE wiring bugs + verify script **[iOS]**
- `cold_start_push_viewport.mdc` — stretched-WebView 4-layer fix **[iOS]**
- `gray_part_mixing_review.mdc` — anti-fingerprint + App Store approval
- `webview_safe_area_injection.mdc` — safe-area CSS injection safety
- `gray_user_agent.mdc` — User-Agent contract (slot vs crash)
- `custom_screens.md` — screen background assets
- `clarity_analytics.mdc` — Microsoft Clarity funnel (OPTIONAL — add only if
  the user asks; if unsure, ask before adding analytics)

---

## What Is This Project?

A dual-mode Flutter app:

- **Gray mode (online):** full-screen WebView (`RoostPortal`) showing a
  URL from a remote backend. The app is a thin content shell.
- **White mode (offline):** a native game (fallback for organic /
  unattributed users; also what reviewers see).

The backend decides which mode each user sees based on their **AppsFlyer
attribution**. Paid (non-organic) users get the WebView; organic users
get the game. One binary, two experiences, decided at runtime.

**Why this architecture exists:** the game provides a legitimate store
listing with real content; the WebView delivers partner content to
targeted users only.

---

## Inputs You Need Before Generating

Refuse to scaffold without ★ items. Everything else has a safe default —
but ask if the brief looks incomplete.

### App identity
- ★ `bundleId` — e.g. `com.example.app` (→ `EraHatchConfig.bundleId`)
- ★ `appTitle` — human-readable name for the store
- ★ **iOS App Store numeric id** (`iosStoreId`, e.g. `6771216641`) — the
  manager needs it to issue the config endpoint; `store_id` is sent as
  `"id" + iosStoreId`.

### Backend
- ★ Config endpoint URL (from manager)
- GCD endpoint base URL (default `https://gcdsdk.appsflyer.com`)

### AppsFlyer
- ★ Dev Key
- ★ OneLink host / subdomain (dashboard → App Settings → OneLink)

### Firebase
- ★ `GoogleService-Info.plist` (in Runner's Copy Bundle Resources)
- ★ Firebase project number (→ `firebase_project_id`)
- Service account `marla-export@marfa-290610.iam.gserviceaccount.com`
  must be Owner in GCP (manager confirms)

### Legal
- ★ Privacy policy URL (public, permanent) + Support URL

### Obfuscation
- ★ Cipher seed — `_nestSalt` in `lib/hatchway/core/feather_codec.dart`, unique per
  project. Re-run `encode_creds.dart` after every change.

### Assets
- ★ Loading screen video (portrait + landscape) + progress-bar frames
- ★ Push-permission screen backgrounds (portrait + landscape)
- ★ No-signal screen backgrounds (portrait + landscape)
- App icon; game asset bundle (from white part)

### Theme flag
- ★ **Slot game or crash game?** Decides whether the User-Agent gets the
  `appid/…  appname/…` suffix — see `gray_user_agent.mdc`. Ask if
  ambiguous; guessing corrupts partner tracking.

---

## Why Stealth Matters

> **Read `apple_moderation_hardening.mdc` for the concrete markers Apple's
> scanner actually matches.** That file is the current source of truth
> after the HenYardSprint / StormBlitz post-mortem; the summary below is
> the high-level rationale.

App Store reviewers and automated scanners look for:
- Apps that are "just a WebView" with no real content
- Apps that behave differently during review vs. production
- Known affiliate / tracking domains and User-Agent signatures in the binary
- **Structural fingerprints** shared across submissions from one
  developer — not just names. The scanner clusters by numeric constants
  (`3 days`, `6 s`, `-1007 × 3`, `15 s`), by JS-injection behaviour sets,
  by purpose strings without matching API calls, and by a
  byte-array → decoder → `Uri.parse` → `WebViewController.loadRequest`
  data-flow graph — none of which move when you rename classes.

**If caught:** app removal, developer account ban, associated accounts
banned via the weak-edge account graph (shared TestFlight testers,
shared AppsFlyer dev key, shared CI IP).

**Defense (all required):**
1. Real game = real review content (reviewer / scanner sees the game).
2. All sensitive strings encoded — but use ordinary primitives, not a
   self-written KSA/PRGA cipher (see `apple_moderation_hardening.mdc` §3).
3. Attribution gate → only paid installs see the WebView; a reviewer's
   organic install shows the game.
4. Unique **structural** fingerprint per project — see
   `gray_part_mixing_review.mdc` §6 (numeric constants, JS behaviour
   set, cipher family) and `apple_moderation_hardening.mdc` §7. Renaming
   is not enough.
5. Real-device User-Agent on all requests (no Dart/Flutter fingerprint),
   assembled from encoded fragments — no plaintext `Mozilla/5.0 iPhone…`
   substring in the binary (`gray_user_agent.mdc` §1).
6. Info.plist declaration matches actual API use — camera/photos strings
   only when a white feature calls the matching API
   (`apple_moderation_hardening.mdc` §1).
7. `PrivacyInfo.xcprivacy` shipped and matches the plugins we use.
8. Post-release URL router hardened **without** a host allowlist —
   scheme-gate only, saved-URL expiry, one-shot push URL. Do not bake
   partner hosts into the binary (`apple_moderation_hardening.mdc` §6).

---

## Project Structure

```
lib/
├── main.dart               Entry: Firebase, services, runApp(FeatheredOriginsApp)
├── bootstrap.dart          FeatheredOriginsApp — root MaterialApp + white-part routes
├── gate/                   Gray flow (rename folder per project)
│   ├── config/
│   │   ├── gate_config.dart     ★ EraHatchConfig: bundleId, iosStoreId, appTitle, timings
│   │   ├── endpoint_vault.dart  ★ XOR: config endpoint (+ GCD URL)
│   │   ├── signal_keys.dart     ★ XOR: AppsFlyer key + Firebase number
│   │   └── brand_links.dart     Privacy + support URLs
│   ├── models/
│   │   ├── session_mode.dart    enum NestRoute { web, game, fresh }
│   │   └── gate_reply.dart      API response: granted / destination / expires
│   ├── infra/
│   │   ├── tracking_signal.dart AppsFlyer: warmup / awaitConversion / awaitDeepLink / buildPayload
│   │   ├── gate_dispatch.dart   HTTP POST config endpoint → HatchReply
│   │   ├── session_vault.dart   SharedPreferences + SecureStorage
│   │   ├── secure_agent.dart    HTTP client with real device User-Agent
│   │   ├── reach_probe.dart     Internet check (DNS probe)
│   │   ├── pulse_relay.dart     Firebase FCM/APNs + local notifications; onTokenRefresh
│   │   └── native_tap_bridge.dart  Reads cold-start URL written by SceneDelegate
│   └── pages/
│       ├── splash_gate.dart     ★ CORE: splash video + routing
│       ├── permit_screen.dart   Push opt-in promo (FeatherInvitation)
│       ├── content_browser.dart WebView shell + JS injections (RoostPortal)
│       └── no_signal_screen.dart No-internet screen (EmptyAirPage)
├── core/
│   ├── feather_codec.dart      unfoldFeathers() + _nestSalt  ★ change seed per project
│   └── white_part.dart     WhitePartPlaceholder ← replace with your game
└── screens/ widgets/ models/ services/   White part (the game)

tool/
└── encode_creds.dart       dart run tool/encode_era_values.dart

ios/Runner/
├── AppDelegate.swift        Registers plugins + registerForRemoteNotifications
├── SceneDelegate.swift      Captures cold-start push URL → UserDefaults
├── Runner.entitlements      aps-environment = development
├── Info.plist               push modes, ATT, FirebaseProxy, ATS, UISceneDelegateClassName
└── GoogleService-Info.plist ★ in Copy Bundle Resources

ios/EggMediaNotification/
├── NotificationService.swift NSE for rich-media push
└── Info.plist                Do NOT add to Resources phase
```

---

## Setup Checklist (new project from this template)

### Step 1 — Credentials + identity
Edit `lib/hatchway/config/era_hatch_config.dart`:
```dart
static const String iosStoreId = '1234567890';       // numeric App Store id
static const String bundleId   = 'com.yourco.yourapp';
static const String appTitle   = 'Your App Name';
```
`EraHatchConfig.platformStoreId` derives `id$iosStoreId`. Edit
`brand_links.dart` for privacy + support URLs.

### Step 2 — Encode secrets
Fill plaintext at the top of `tool/encode_era_values.dart` (config endpoint,
AppsFlyer dev key, Firebase project number, GCD URL, privacy, support),
then:
```bash
dart run tool/encode_era_values.dart
```
**⚠️ Always use `dart run`, never PowerShell foreach loops** — PowerShell
overflows 32-bit integers → wrong byte values → `FormatException:
Invalid HTTP header field value`.
Paste the arrays into `endpoint_vault.dart` + `signal_keys.dart`. The
VERIFY block printed by the tool must match the plaintext exactly.

### Step 3 — Change the cipher seed
Edit `_nestSalt` in `lib/hatchway/core/feather_codec.dart` (short unique ASCII, 6–15
bytes). Ideally also rotate the cipher *algorithm* per portfolio
(`gray_part_mixing_review.mdc` §1). **Re-run `encode_creds.dart` after
any seed/algorithm change.**

### Step 4 — Firebase config file
- `ios/Runner/GoogleService-Info.plist` → add to Runner's Copy Bundle
  Resources in `project.pbxproj` (see §"Ideal project.pbxproj").
It must match the bundle id. Add to `.gitignore` if the repo is public.

### Step 5 — Bundle IDs
| File | Field |
|------|-------|
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` ×3 (Runner) |
| `ios/Runner.xcodeproj/project.pbxproj` | NSE bundle ×3 (exact suffix from Apple Portal) |
| `ios/Runner/GoogleService-Info.plist` | `BUNDLE_ID` |
| `lib/hatchway/config/era_hatch_config.dart` | `bundleId` |

### Step 6 — White part (your game)
Replace `WhitePartPlaceholder` in `lib/white/white_placeholder.dart` with your
game's entry screen, and register **all** named routes in `FeatheredOriginsApp`
(`lib/app/app.dart`) — a missing route crashes the organic path.
`BootScreen._goGame()` navigates **directly** to the game's main screen,
NOT to a `LoadingScreen` (BootScreen already served as the loading UX —
see §"Common Errors" double-loading).

### Step 7 — iOS NSE (Notification Service Extension)
The NSE lets iOS attach rich-media images to push while the app is
backgrounded/killed. Without it, images only appear while the Dart
isolate is alive.

**7a — Swift + plist.** Create `ios/EggMediaNotification/NotificationService.swift`:
```swift
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(_ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
    guard let best = bestAttemptContent else { contentHandler(request.content); return }
    #if canImport(FirebaseMessaging)
    Messaging.serviceExtension().populateNotificationContent(best, withContentHandler: contentHandler)
    #else
    contentHandler(best)
    #endif
  }

  override func serviceExtensionTimeWillExpire() {
    if let h = contentHandler, let b = bestAttemptContent { h(b) }
  }
}
```
`ios/EggMediaNotification/Info.plist` — standard app-extension plist with
`NSExtensionPointIdentifier = com.apple.usernotifications.service` and
`NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).NotificationService`.

**7b — Podfile.** Outside the Runner target block, pin the SAME Firebase
version as Runner:
```ruby
target 'NotificationService' do
  use_frameworks!
  platform :ios, '15.0'
  pod 'Firebase/Messaging', '12.14.0'   # match firebase_core resolved version
end
```

**7c — project.pbxproj.** The most error-prone step. Follow §"Ideal
project.pbxproj Structure for NSE" below and
`pbxproj_nse_integration.mdc`. Critical points: NSE PBXGroup inside the
PBXGroup section; `CODE_SIGN_ENTITLEMENTS` on **Runner** (×3), never NSE;
NSE has NO `baseConfigurationReference`; NSE Resources phase empty; single
`dependencies` block on Runner; `Embed App Extensions` before
`Thin Binary`; saved without BOM, real tabs.

**7d — pod install.**
```bash
cd ios && pod install     # must print NO base-configuration warnings
open Runner.xcworkspace    # ALWAYS the workspace, never .xcodeproj
```

### Step 8 — Entitlements
Create `ios/Runner/Runner.entitlements` with `aps-environment =
development` (Xcode switches to `production` on Archive), and add
`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` to all three Runner
build configs.

---

## Gray Flow State Machine

`BootScreen._boot()` is the whole routing brain. `NestVault.readMode()`
returns one of `NestRoute.{ fresh, web, game }`.

```
── HIGHEST PRIORITY (all modes) ──────────────────────────────
LaunchRouteReader.consumeTapUrl()  [iOS cold-start push]
  └── non-empty → writeMode(web) → clear one-shot → dispatch attribution
      in BACKGROUND → RoostPortal(url)   ← return immediately

NestRoute.fresh (FIRST LAUNCH)
  ├── No internet → EmptyAirPage (retry → BootScreen restart)
  └── Has internet
        ├── pulse.bootstrap()  (APNs/FCM token warmup)
        ├── signal.warmup() → awaitConversion() + awaitDeepLink()
        │     ⚠️ af_status=="Organic" → wait, retry via GCD API
        ├── signal.buildPayload(locale, pushToken)
        ├── dispatch.send(body) → HatchReply
        ├── granted + destination → writeMode(web)  → RoostPortal
        └── else                  → writeMode(game) → game

NestRoute.web (RETURNING, WAS WEBVIEW)
  ├── No internet → EmptyAirPage
  ├── one-shot URL in vault → RoostPortal(url)   ← highest priority
  ├── read savedUrl in parallel with warmup
  ├── awaitConversion(5s) + awaitDeepLink() → buildPayload → dispatch.send
  ├── granted + destination → RoostPortal(new url)
  └── else + savedUrl       → RoostPortal(savedUrl)   (last-known-good)
        └── no savedUrl → EmptyAirPage

NestRoute.game (RETURNING, WAS GAME)
  ├── No internet → game
  └── Has internet → _tryRecoverWebMode()  (re-conversion)
        ├── granted + destination → writeMode(web) → RoostPortal
        └── else                  → game
```

**Key insight:** unlike a pure one-way gate, `NestRoute.game` users
CAN be re-converted to `web` on later launches if the backend starts
returning a URL. This is intentional (`_tryRecoverWebMode`). But a
first-launch network failure must NEVER commit `game` — keep the install
in `fresh` so a later online launch can still reach the WebView.

---

## First-Launch UX Contract (OneLink + Offline Install)

Hard invariant for the *very first* launch after installing via a OneLink
(paid attribution present, but the device may have no connectivity yet).
Failing any bullet is a QA-blocking bug.

### Canonical scenario (reproducible on every build)
1. User taps the OneLink on the target device.
2. **Wi-Fi / mobile data is OFF** before the install completes.
3. User installs and opens the app.
4. → App shows the **No-Signal screen promptly** — no Flutter branding,
   no black screen hang while a network call times out.
5. User turns connectivity ON and taps **Retry**.
6. → App re-enters the loading splash, runs the full pipeline
   (network → attribution → config), and routes to the WebView. No game
   screen appears at any point (attribution is Non-organic).

### Implementation rules
- **Connectivity gate runs before heavy attribution work.** `BootScreen`
  checks `AirwayProbe.isOnline()` early; if offline, go to `EmptyAirPage`
  rather than awaiting a hanging network call.
- **Retry restarts the full pipeline.** `EmptyAirPage.retryBuilder`
  rebuilds a fresh `BootScreen` — the pipeline is idempotent by design;
  do not patch state in place.
- **Mode stays `fresh` throughout.** Because no config response arrived,
  the mode is not committed to `web`/`game`. Only a *successful* response
  with no URL commits `game`.
- **No game fallback on offline boot.** Do not preload the game on the
  offline path — the moment internet returns and the fetch succeeds we go
  to `RoostPortal`, not the game.

---

## Config Request Contract (AUTHORITATIVE)

Every rule below is a hard invariant. Mirror it exactly in
`gate_dispatch.dart` and `tracking_signal.dart`.

### 1. Endpoint
| Field | Value |
|---|---|
| URL | From manager, XOR-encoded in `endpoint_vault.dart` |
| Method | `POST` |
| Headers | `Content-Type: application/json`, `Accept: application/json` |
| Timeout | 15 s |

Never hard-code the endpoint at a call site — always deref through
`EraHatchConfig.configEndpoint`.

### 2. Request body — merge order
One flat JSON object merged from three sources; first-write-wins on
collision (`putIfAbsent`), then device-side fields overwrite:

| Priority | Source | Rule |
|---|---|---|
| 1 | `onInstallConversionData` (install attribution) | write all keys as-is |
| 2 | `onAppOpenAttribution` (returning-user) | putIfAbsent |
| 3 | `onDeepLinking` (UDL) | putIfAbsent |
| 4 | Device-side fields (§3) | overwrite |

**Hard rules:**
- ❌ NEVER filter, rename, drop or mutate any AppsFlyer key/value — the
  parameter list varies per install source; pass it through unchanged.
- ❌ Do not JSON-nest — one flat object.
- ✅ Log the final body in debug only (see §11).

### 3. Device-side fields (added last, always overwrite)
| Key | Type | Source | Notes |
|---|---|---|---|
| `af_id` | string | AppsFlyer UID | |
| `bundle_id` | string | `EraHatchConfig.bundleId` | |
| `os` | string | `"iOS"` | case-sensitive, exactly this |
| `store_id` | string | `EraHatchConfig.platformStoreId` | `"id"+iosStoreId` |
| `locale` | string | device locale, RFC 3066 | `en`, `en_US`, `ru`, `pt_BR` — don't lowercase/strip region |
| `push_token` | string | APNs / Firebase token | **Omit key entirely if not ready — §5** |
| `firebase_project_id` | string | Firebase project number | **Omit key entirely if not ready — §5** |
| `sub_id_10` | string | IDFA (iOS, only if ATT granted) | omit if ATT denied/unknown |

Never send `push_token: ""` or `null` — omit the key. The backend
distinguishes "no push subsystem" from "empty token" and mis-routes on a
leaked sentinel.

### 4. UDL / deep-link fields (from `onDeepLinking`)
Merge everything the SDK delivers (`putIfAbsent`). Possible extras:
`campaign_id, campaign, media_source, timestamp, match_type,
deep_link_value, deep_link_sub1..N, is_deferred, click_http_referrer,
af_sub1..5`. The SDK's list is authoritative — pass through whatever it
delivers.

### 5. Push token not ready
On iOS the token is `null` until APNs registers (§Push). If unavailable,
send the request **without both** `push_token` and `firebase_project_id`.
Recovery is event-driven, not polled:
1. Register `pulse.onTokenRefresh = _onTokenRefresh` at startup
   (`BootScreen._boot` does this).
2. When it fires, **immediately re-POST** the full body with the token.
3. Persist the resulting `url` / `expires`.

### 6. Response — success (HTTP 200)
```json
{ "ok": true, "url": "https://link.example/...", "expires": 1689002181 }
```
→ `reply.granted == true`, `reply.destination = url`.
- Load `url` into the WebView **unchanged** — no rewriting, no domain
  substitution, no scheme upgrade.
- `expires` — Unix seconds; persist with the URL. On returning launches,
  a still-valid saved URL is loaded without a network call.

### 7. Response — failure
HTTP ≠ 200, or `{ "ok": false, ... }`, or socket/DNS/timeout → NEGATIVE
answer to "show the WebView?" → `reply.granted == false`.

### 8. Behaviour contract on failure
- **First install, never fetched a URL:** commit `NestRoute.game` (via
  `NestVault`), show the game. Do NOT keep retrying — extra requests
  are visible to scanners. Reinstall is the only reset. (Re-conversion on
  a later launch through `_tryRecoverWebMode` is allowed if the backend
  starts returning a URL.)
- **Returning launch with a valid saved URL:** if `expires` not passed,
  load `savedUrl` without a network call. If passed, refetch: success →
  overwrite + load new; failure → **still load `savedUrl`** (never fall to
  game, never blank). A pending push URL wins over both.

### 9. Backend test-environment quirks
- On the default test backend a `url` is returned **only** when
  `af_status == "Non-organic"`. Organic → `{ok:false}` is correct — not a
  client bug; do not add fallback logic.
- End-to-end push tests require **all** device-side fields present
  (`af_id, bundle_id, os, store_id, locale, push_token,
  firebase_project_id`) — a missing field means the backend can't target
  the device and pushes silently never arrive. Log the body and verify
  before opening a QA ticket.

### 10. QA logging (debug only)
Wrap every log so it is stripped from release (see mixing rule §2). Emit:
`onInstallConversionData`, `onDeepLinking`, `GCD retry data`,
`[dispatch] Request body`, `[dispatch] Response`. Never log in release —
those strings become fingerprints.

---

## AppsFlyer: Organic False-Positive Fix

AppsFlyer sometimes fires `onInstallConversionData` with `af_status:
"Organic"` even for paid installs (first-run SDK timing). Detection:
`payload['af_status'] == 'Organic'`. Fix in `tracking_signal.dart`: wait
`EraHatchConfig.organicRetrySeconds` (6 s), then re-query attribution via the
GCD API and use the last good data:
```
GET https://gcdsdk.appsflyer.com/install_data/v4.0/{bundleId}?device_id={uid}
Authorization: Bearer {appsFlyerDevKey}
```

---

## Push Notifications

iOS push is APNs + Firebase (as the sender) + an NSE for rich media +
SceneDelegate for cold-start taps. `pulse_relay.dart` (`EggSignalHub`) owns
messaging + local notifications; `native_tap_bridge.dart` reads the
cold-start URL.

### Permission flow (per TZ)
1. Show `FeatherInvitation` **before** `RoostPortal` on first entry into
   gray mode (`BootScreen._goContent` gates on `vault.needsPushPrompt()` +
   `pulse.shouldOfferConsent()`).
2. Accept → `pulse.askPermission()` → system dialog.
3. Skip → set a cooldown (`EraHatchConfig.pushCooldownSeconds`, 3 days) via
   `vault.writeInviteCooldown(...)`; show again after it lapses.
4. System-denied → never show again (persist an os-denied flag).

### ATT dialog timing
Show ATT **after the first frame** — iOS silently drops the request if the
app is not `active`:
```dart
await WidgetsBinding.instance.endOfFrame;
await Future.delayed(const Duration(milliseconds: 300));
await AppTrackingTransparency.requestTrackingAuthorization();
```

### APNs token delay (CRITICAL)
`FirebaseMessaging.instance.getToken()` returns `null` on iOS before APNs
registers (~0.5–2.5 s). Poll `getAPNSToken()` first:
```dart
for (var i = 1; i <= 5; i++) {
  final apns = await messaging.getAPNSToken();
  if (apns != null && apns.isNotEmpty) break;
  await Future.delayed(const Duration(milliseconds: 500));
}
```
After the user grants permission in `FeatherInvitation`, the delay is longer —
use a longer retry loop (e.g. 14 × 700 ms) before re-POSTing the config
with the fresh token (`onTokenReady` callback wires this in `BootScreen`).

### Cold-start push tap (killed app)
When the app is **killed** and a push is tapped, iOS delivers the tap
through `SceneDelegate.scene(_:willConnectTo:options:)`, NOT Firebase's
swizzled path — `getInitialMessage()` returns nil (flutterfire#8896).
- `SceneDelegate.swift` extracts the URL from `userInfo` (keys `url`,
  `link`, `target`, `deeplink`, `deep_link`, plus nested `data`/`payload`)
  and writes it to UserDefaults under `tapUrlKey =
  "flutter.era_launch_route"`.
- `LaunchRouteReader.consumeTapUrl()` reads it via SharedPreferences (the
  `flutter.` prefix bridges UserDefaults ↔ SharedPreferences) and clears
  it.
- **`BootScreen._boot()` calls `consumeTapUrl()` FIRST**, before push
  bootstrap / network / attribution. See §Common Errors "cold-start push".
- The two keys (`SceneDelegate.tapUrlKey` and `LaunchRouteReader._key`) must
  stay in sync, including the `flutter.` prefix.
- `Info.plist` must declare `UISceneDelegateClassName =
  $(PRODUCT_MODULE_NAME).SceneDelegate`.

### Foreground presentation
Let the system present the banner via
`setForegroundNotificationPresentationOptions(alert:true, badge:true,
sound:true)`. Do NOT also show a `flutter_local_notifications` banner for
the same message — it would duplicate.

### Cold-start push → stretched WebView
A killed-app push tap can render the WebView stretched (viewport measured
before immersive mode settles). Apply the mandatory 4-layer fix in
`RoostPortal` — see `cold_start_push_viewport.mdc`.

---

## Screen Layout

### BootScreen (Loading) — video + 3-state bar
This template's loading screen is a **looping muted background video**
(`assets/Loading/Vertical_Loading_Screen.mp4` /
`Horizontal_Loading_Screen.mp4`) with a **3-state progress-bar image**
swapped as the boot advances (`_BarStep.empty → midway → done`, assets
`Loading_Bar_Empty/Half/Full.webp`). Keep this video + discrete-frame
approach (not an animated 0→100 % bar).

Contract:
- Video fills the screen (`BoxFit.cover`, `FittedBox`), muted, looping;
  orientation-aware asset chosen in `didChangeDependencies`.
- The bar image fades in only once the video is ready (`_vidReady`) —
  never render the bar over a black frame.
- `_bar` advances to `done` at the moment routing decides the next screen
  (the bar reaching "full" maps to real boot completion — do not park it
  at "full" and hang).
- Bar width: portrait ≈ `width * 0.70` (clamp ≤ 340), landscape ≈
  `height * 0.35` (clamp ≤ 160); bottom-anchored, centered.
- Non-interactive; back button does nothing; single video controller
  bound to State so rotation does not restart it.

### FeatherInvitation (push opt-in)
Full-screen orientation-aware background (see `custom_screens.md`);
Accept + Skip buttons overlaid at the bottom.
- **Skip must be a real, visible button** (same gradient family as
  Accept, ≥ 44 dp tap target, same radius) — never a low-contrast text
  link. Visual weight of Accept > Skip comes from size/position, not
  opacity.
- Button labels: `height: 1.0` + `CrossAxisAlignment.center` (no baseline
  drift). Verify both orientations.
- Accept → `pulse.askPermission()`; Skip → cooldown; both then forward to
  `RoostPortal`.

### EmptyAirPage (no internet)
Orientation-aware background + a single Retry button.
- Retry rebuilds a fresh `BootScreen` (`retryBuilder`), re-running the
  whole pipeline.
- Retry width: portrait ≈ 70 % (clamp 220–380), landscape ≈ 35 %; must
  not cover the artwork illustration; guard against double-tap.
- Must appear promptly on `ConnectivityResult.none` — no long DNS probe
  first (see `custom_screens.md`).

---

## WebView JS Injections (RoostPortal)

Call inside `onPageFinished`, in this order:

1. **`_injectSafeArea()`** — override the site's safe-area CSS variables;
   patch `viewport-fit`. **Never** zero the site's own `padding-left/right`
   or root-element margins — that squashes responsive layouts. See
   `webview_safe_area_injection.mdc`.
2. **`_injectKeyboardScroll()`** — scroll a focused input into view when
   the keyboard opens. Use `scrollIntoView({behavior:'auto', block:'nearest'})`
   and a **single** `setTimeout(..., 350)`; guard the safe-area patcher
   with `kbOpen()` so it never runs while the keyboard animates (both are
   required — see iOS keyboard jitter below).
3. **`_injectAntiZoom()`** — iOS auto-zooms a focused `<input>` with
   `font-size < 16px`: `input,textarea,select{font-size:max(16px,1em)!important;}`.
4. **`_injectMediaAutoplay()`** — force inline autoplay for `<video>` +
   a `MutationObserver` for SPA-added videos; also set
   `mediaTypesRequiringUserAction: {}` and `allowsInlineMediaPlayback:
   true` on `WebKitWebViewControllerCreationParams`.

~800 ms after `onPageFinished`, dispatch a `resize` event + re-run
`_injectSafeArea()` (and, only on cold-start push, a single `reload()`).

### iOS keyboard jitter — two independent triggers (both must be fixed)
**Symptom:** the keyboard visibly jumps when focusing an input in
WKWebView; "reinstalling fixes it" (timing-dependent).

- **Trigger 1 — smooth scroll during keyboard animation.**
  `scrollIntoView({behavior:'smooth'})` (or scheduling it 3× at
  250/500/800 ms) runs a second animator concurrently with the keyboard →
  compositor fight → jump. Use `behavior:'auto'` + a single
  `setTimeout(focusRoll, 350)`.
- **Trigger 2 — viewport patch while keyboard is open.** A
  `setInterval(apply, 2500)` that mutates `meta[name="viewport"]` forces
  WKWebView to recompute safe-area insets mid-animation. Guard `apply()`:
  ```javascript
  function kbOpen(){ return window.visualViewport &&
    window.visualViewport.height < window.innerHeight * 0.75; }
  function apply(){ if (kbOpen()) return; /* patch */ }
  ```
  Slightly increase SPA route-change delays (e.g. 150 ms / 600 ms) so the
  patch never fires during a keyboard-dismiss transition.

---

## iOS-Specific Notes: Info.plist keys + reviewer justifications

> **⚠️ Read `apple_moderation_hardening.mdc` §1–§2 before editing this
> section.** Every purpose string here has to have a matching API call in
> the binary — Apple's static analyzer diffs the two sets and rejects
> mismatches without ever running the app.

```xml
<!-- Push background delivery -->
<key>UIBackgroundModes</key>
<array><string>remote-notification</string></array>
<!-- Add "fetch" or "processing" ONLY if a real white-part feature
     justifies it — an unjustified background mode is a review red flag
     (see gray_part_mixing_review.mdc §3 and §6c). -->

<!-- Firebase swizzling for cold-start push routing -->
<key>FirebaseAppDelegateProxyEnabled</key><true/>

<!-- AppsFlyer ATT — game-themed copy -->
<key>NSUserTrackingUsageDescription</key>
<string>Your data is used to personalize your experience and offers.</string>

<!-- WKWebView loads partner web content (may be HTTP) -->
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsArbitraryLoadsInWebContent</key><true/></dict>
<!-- Applies to WKWebView only, NOT URLSession; app networking stays HTTPS. -->

<!-- ⚠️ Include ONLY if the white part actually calls the matching API
     (image_picker / AVCaptureDevice / PHPhotoLibrary). WebView
     <input type="file"> alone is NOT a real use — the OS presents the
     sheet but no symbol appears in the binary. If you keep these keys,
     add a visible avatar/camera feature to the game AND word the string
     around that feature. Otherwise REMOVE the keys — Apple's scanner
     rejects declarations without matching API calls (2.3.1). -->
<!--
<key>NSPhotoLibraryUsageDescription</key><string>… game-themed real feature …</string>
<key>NSCameraUsageDescription</key><string>… game-themed real feature …</string>
-->

<!-- Scene delegate for cold-start push -->
<key>UISceneDelegateClassName</key><string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>

<!-- ⚠️ LSApplicationQueriesSchemes — NEVER include `http` or `https`.
     Those schemes are opened via canOpenURL without registration, and
     their presence is a well-known partner-template copy-paste
     artefact (see apple_moderation_hardening.mdc §1). Keep only
     schemes we actually hand off to (tel, mailto, and specific
     external apps). -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tel</string>
    <string>mailto</string>
</array>

<!-- Encryption exemption — see apple_moderation_hardening.mdc §3. Set to
     `false` ONLY after the custom KSA/PRGA stream cipher in
     feather_codec.dart is replaced. If the KSA/PRGA loop still ships,
     set to `true` and answer "using only exempt encryption" in App
     Store Connect. -->
<key>ITSAppUsesNonExemptEncryption</key><false/>
```

Only keep `NSMicrophone…` / background `fetch` if a real white feature
uses them — otherwise remove (`gray_part_mixing_review.mdc` §3, §6c).

### PrivacyInfo.xcprivacy — mandatory

We use `device_info_plus`, `flutter_secure_storage`, `shared_preferences`
and `webview_flutter`, every one of which is on Apple's Required Reason
API list. **Without a matching `ios/Runner/PrivacyInfo.xcprivacy` in
Runner's Copy Bundle Resources phase, the submission is auto-rejected.**

Minimum shape (verify against the manifests the plugins actually ship):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- NEVER leave this array empty while NSPrivacyTracking is true —
         that is ITMS-91064 (auto-reject), and `plutil -lint` still passes.
         Never list the config endpoint or partner host here either: iOS
         fails requests to declared tracking domains when ATT is denied.
         Full rationale: apple_moderation_hardening.mdc §2a. -->
    <key>NSPrivacyTracking</key><true/>
    <key>NSPrivacyTrackingDomains</key>
    <array>
        <string>att.attr.appsflyersdk.com</string>
        <string>att.launches.appsflyersdk.com</string>
        <string>att.conversions.appsflyersdk.com</string>
        <string>att.dlsdk.appsflyersdk.com</string>
    </array>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <!-- Truthful union of what AppsFlyer + Firebase collect. -->
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>CA92.1</string></array>
        </dict>
        <!-- Add the entries required by every plugin's own manifest. -->
    </array>
</dict>
</plist>
```

**Verification:**
```bash
plutil -lint ios/Runner/PrivacyInfo.xcprivacy
```
must pass — but a lint pass is NOT sufficient. Also run
`apple_moderation_hardening.mdc` §9.5a, which is the only check that catches
the `NSPrivacyTracking = true` + empty-domains reject.
`ios/Runner.xcodeproj/project.pbxproj` must include a
`PBXFileReference` + `PBXBuildFile` for the manifest AND list it in
Runner's Resources phase (same shape as `GoogleService-Info.plist`).

---

## Obfuscation & Anti-Detection

> **⚠️ Read `apple_moderation_hardening.mdc` §3 before extending this
> section.** The self-written RC4-style stream cipher shipped in previous
> template revisions is now flagged as a smoking-gun signature — the
> `byte array → cipher loop → Uri.parse → WebViewController.loadRequest`
> graph is what Apple's scanner matches. Do NOT ship it unmodified.

1. **Encoded secrets** — endpoint, AppsFlyer key, Firebase number, and
   every UA fragment (including the `Mozilla/5.0 (iPhone…` scaffolding).
   Do NOT encode public URLs (privacy policy, support) — encrypting a URL
   that is public in App Store Connect only proves you have decoder
   infrastructure.
2. **Cipher family** — the template ships a KSA/PRGA loop
   (`feather_codec.dart`). Replace it before shipping (see
   `apple_moderation_hardening.mdc` §3). Preferred: `base64Decode` + a
   single-pass XOR against a device-derived key. Rotate the algorithm
   per portfolio slot — never ship two apps with the same cipher family
   (`gray_part_mixing_review.mdc` §1, §6e).
3. **Real device User-Agent** — built from `device_info_plus`; identical
   on HTTP client + WebView; no `Dart`/`Flutter`/`CFNetwork`/`Darwin`/
   package-name tokens; no plaintext `Mozilla/5.0` substring in the
   binary. See `gray_user_agent.mdc`.
4. **Generic class/method/variable names** — no `Casino*`, `Betting*`,
   `Gambling*`. Rotate them per project (`gray_part_mixing_review.mdc`).
5. **Structural diversification** — rotate the numeric constants and the
   JS injection behaviour set per project
   (`gray_part_mixing_review.mdc` §6 and `apple_moderation_hardening.mdc`
   §7). Renaming is not enough.
6. **Firebase App Check** — `deviceCheck` (release), `debug` provider in
   debug builds.
7. **Secure storage** — content URLs in `flutter_secure_storage`
   (Keychain on iOS), not plain prefs.
8. **No release logs** — assert-wrapped Dart logger, `#if DEBUG` Swift.
9. **No host allowlist for WebView URLs** — do not gate config / push /
   saved URLs on a hardcoded host-suffix list. The partner host may change
   via config after release. Keep scheme-gating + saved-URL expiry instead
   (`apple_moderation_hardening.mdc` §6).

Per-project uniqueness (cipher algorithm, JS injection bodies, probe host,
UA fallback, storage prefix, NSE UUIDs, dependency versions, backend
domain) is mandatory — see `gray_part_mixing_review.mdc`.

---

## Common Errors & Fixes

| Symptom | Cause | Fix |
|---|---|---|
| `FormatException: Invalid HTTP header field value` | PowerShell truncated ints on encode | `dart run tool/encode_era_values.dart` |
| `Could not find route "/menu"` | White routes not registered | Register all in `FeatheredOriginsApp` (`bootstrap.dart`) |
| `Could not locate configuration file: GoogleService-Info.plist` | Not in Copy Bundle Resources | Add PBXFileReference + PBXBuildFile + Runner Resources phase + Runner group |
| `no valid "aps-environment" entitlement` / FCM token null | Missing entitlements or on wrong target | `Runner.entitlements` + `CODE_SIGN_ENTITLEMENTS` on all 3 **Runner** configs (NOT NSE) |
| NSE bundle ID mismatch / not signed | pbxproj ≠ Apple Portal identifier | Use the EXACT suffix from Apple Developer Portal in all 3 NSE configs |
| `Multiple commands produce … Info.plist` (NSE) | Info.plist in NSE Resources phase | NSE Resources phase must be EMPTY (`INFOPLIST_FILE` handles it) |
| `Multiple commands produce … .appex` | Two `dependencies` blocks on Runner | Keep exactly ONE `dependencies` block |
| `Multiple commands produce … .appex` (empty name) | `PRODUCT_NAME = ""` in NSE configs | `PRODUCT_NAME = "$(TARGET_NAME)"` |
| `Cycle inside Runner; building` | Embed App Extensions after Thin Binary | Move Embed App Extensions BEFORE Thin Binary |
| CocoaPods "already has custom config" (NSE) | `baseConfigurationReference` on NSE | Remove it — CocoaPods sets it |
| Cold-start push → menu instead of URL | `consumeTapUrl()` not called first | Call it FIRST in `_boot()`, before network/push/attribution |
| WebView stretched after cold-start push tap | Viewport measured before immersive settled | 4-layer fix — `cold_start_push_viewport.mdc` |
| iOS keyboard jitter | `behavior:'smooth'` + viewport patch during keyboard | `behavior:'auto'` + single `setTimeout` + `kbOpen()` guard |
| Video doesn't autoplay | `_injectMediaAutoplay()` missing / creation params | Inject + set `allowsInlineMediaPlayback` + empty `mediaTypesRequiringUserAction` |
| Double loading screen | `_goGame()` → LoadingScreen | Navigate directly to the game's main screen |
| APNs / FCM token null on iOS | `getToken()` before APNs registered | Poll `getAPNSToken()` first (+ longer loop after consent) |
| WebView blank + `-1007` in logs | Affiliate redirect chain exceeds WKWebView limit | Retry with last main-frame URL up to 3× (track in `onNavigationRequest`); reset on `onPageFinished` |
| `-999 NSURLErrorCancelled` → offline screen | `loadRequest()` cancels the in-flight nav on retry | `onWebResourceError`: `if (err.errorCode == -999) return;` |
| iOS audio assertion `mixWithOthers` | `ambient` + `mixWithOthers` invalid | `options: const {}` — ambient already mixes |
| `FirebaseException: permissions request already running` | concurrent `requestPermission()` | boolean guard in `EggSignalHub` |
| `[core/duplicate-app]` | `Firebase.initializeApp()` called twice | call ONLY in `main()` |
| `pod install` `\xEF` (BOM) | Git on Windows added UTF-8 BOM | `.gitattributes: *.pbxproj binary`; strip BOM before write |
| `pod install` invalid `"\"` (literal `\t`) | Windows script wrote escaped tabs | Replace `\t` with real tabs before write |
| `sandbox is not in sync` (CI) | Manifest.lock stale after warm pod cache | `install! 'cocoapods', :disable_input_output_paths => true` |
| `Signing requires a development team` (local) | Opened `.xcodeproj` not `.xcworkspace` | Open the workspace; ensure `DEVELOPMENT_TEAM` in all 3 Runner configs |
| `CODE_SIGN_IDENTITY iPhone Distribution` (local) | Distribution cert in pbxproj | Use `"iPhone Developer"` locally |

### project.pbxproj corruption after Windows edits (3 errors in sequence)
When `project.pbxproj` is edited on Windows and built on macOS:
1. **`Array missing ',' between objects`** — full `= {isa = …}` object
   definitions were pasted inside a `children = (…)` array. Children hold
   ONLY `UUID /* name */,` references; full definitions live only in the
   PBXFileReference section.
2. **`Invalid character "\"`** — literal `\t` instead of real tabs.
   Replace before saving.
3. **`Invalid character "\xEF"` (line 1)** — a UTF-8 BOM. The file must
   start exactly with `// !$*UTF8*$!` (bytes `2F 2F 20 21`). Strip the BOM.
Always write with a BOM-free encoder and preserve tabs. See
`pbxproj_nse_integration.mdc` for a verification script.

---

## Ideal project.pbxproj Structure for NSE Integration

Canonical, verified-working structure. Replace `NSE_*` UUID placeholders
with your own random 24-char hex (`secrets.token_hex(12).upper()` — no
predictable `AA0000…` pattern; see `gray_part_mixing_review.mdc`). Save
without a UTF-8 BOM, with real tabs.

### 1. PBXBuildFile
```
NSE_SWIFT_BUILD_FILE /* NotificationService.swift in Sources */ = {isa = PBXBuildFile; fileRef = NSE_SWIFT_FILE_REF; };
GOOGLE_PLIST_BUILD   /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = GOOGLE_PLIST_FILE_REF; };
EMBED_EXT_BUILD_FILE /* NotificationService.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = NSE_APPEX_FILE_REF; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
```

### 2. PBXContainerItemProxy
```
NSE_PROXY /* PBXContainerItemProxy */ = {
  isa = PBXContainerItemProxy;
  containerPortal = 97C146E61CF9000F007C117D /* Project object */;
  proxyType = 1;
  remoteGlobalIDString = NSE_TARGET;
  remoteInfo = NotificationService;
};
```

### 3. PBXCopyFilesBuildPhase — Embed App Extensions (dstSubfolderSpec = 13)
```
EMBED_EXT_PHASE /* Embed App Extensions */ = {
  isa = PBXCopyFilesBuildPhase;
  buildActionMask = 2147483647;
  dstPath = "";
  dstSubfolderSpec = 13;      ← MUST be 13 (not 10)
  files = ( EMBED_EXT_BUILD_FILE /* NotificationService.appex */, );
  name = "Embed App Extensions";
  runOnlyForDeploymentPostprocessing = 0;
};
```

### 4. PBXFileReference (in the PBXFileReference section ONLY)
```
NSE_SWIFT_FILE_REF   = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = "<group>"; };
NSE_PLIST_FILE_REF   = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
NSE_APPEX_FILE_REF   = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = NotificationService.appex; sourceTree = BUILT_PRODUCTS_DIR; };
GOOGLE_PLIST_FILE_REF= {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };
```

### 5. PBXGroup (children hold ONLY `UUID /* name */,` references)
```
97C146F01CF9000F007C117D /* Runner */ = { isa = PBXGroup; children = (
  … existing …, GOOGLE_PLIST_FILE_REF /* GoogleService-Info.plist */,
  ENTITLEMENTS_FILE_REF /* Runner.entitlements */, 7884…672 /* SceneDelegate.swift */,
); path = Runner; sourceTree = "<group>"; };
NSE_GROUP /* NotificationService */ = { isa = PBXGroup; children = (
  NSE_SWIFT_FILE_REF /* NotificationService.swift */, NSE_PLIST_FILE_REF /* Info.plist */,
); path = NotificationService; sourceTree = "<group>"; };
```
The NSE group MUST live inside `/* Begin PBXGroup section */` and be a
child of the main group.

### 6. PBXNativeTarget — Runner (SINGLE dependencies block)
```
97C146ED… /* Runner */ = { isa = PBXNativeTarget;
  buildPhases = ( Run Script, Sources, Frameworks, Resources,
                  Embed Frameworks, EMBED_EXT_PHASE, Thin Binary );
  dependencies = ( NSE_TARGET_DEP /* PBXTargetDependency */, );  ← exactly one
  … productType = "com.apple.product-type.application"; };
```

### 7. PBXNativeTarget — NotificationService
```
NSE_TARGET /* NotificationService */ = { isa = PBXNativeTarget;
  buildConfigurationList = NSE_CFG_LIST;
  buildPhases = ( NSE_SOURCES_PHASE, NSE_FRAMEWORKS_PHASE, NSE_RESOURCES_PHASE );
  dependencies = ();
  productReference = NSE_APPEX_FILE_REF;
  productType = "com.apple.product-type.app-extension"; };
```

### 8. XCBuildConfiguration — NSE (Debug/Release/Profile)
```
NSE_*_CFG = { isa = XCBuildConfiguration; buildSettings = {
  CODE_SIGN_STYLE = Automatic;
  CURRENT_PROJECT_VERSION = 1;            ← hardcoded, NOT $(FLUTTER_BUILD_NUMBER)
  DEVELOPMENT_TEAM = YOUR_TEAM_ID;
  INFOPLIST_FILE = NotificationService/Info.plist;
  IPHONEOS_DEPLOYMENT_TARGET = 15.0;
  MARKETING_VERSION = 1.0;                ← hardcoded, NOT $(FLUTTER_BUILD_NAME)
  PRODUCT_BUNDLE_IDENTIFIER = com.yourapp.<EXACT_NSE_SUFFIX>;
  PRODUCT_NAME = "$(TARGET_NAME)";        ← MUST NOT be ""
  SKIP_INSTALL = YES;
  SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = "1,2";
}; };
```
| Setting | Correct | Wrong → symptom |
|---|---|---|
| `PRODUCT_NAME` | `"$(TARGET_NAME)"` | `""` → Multiple commands produce .appex |
| `CURRENT_PROJECT_VERSION` | `1` | `$(FLUTTER_BUILD_NUMBER)` → CocoaPods can't set base xcconfig → Firebase not linked |
| `SKIP_INSTALL` | `YES` | missing → App Store rejects extension as top-level product |
| `baseConfigurationReference` | absent | present → blocks CocoaPods linking Firebase to NSE |
| `CODE_SIGN_ENTITLEMENTS` | absent on NSE | present on NSE → APNs fails on Runner |

### 9. NSE Resources phase — EMPTY
```
NSE_RESOURCES_PHASE /* Resources */ = { isa = PBXResourcesBuildPhase; files = (); … };
```

### 10. XCConfigurationList — NSE + TargetAttributes
Add `NSE_CFG_LIST` with the 3 NSE configs; add `NSE_TARGET =
{ CreatedOnToolsVersion = 15.0; };` LAST in `TargetAttributes`.

---

## Dependencies Reference (pubspec.yaml)

Recommended modern pins. **Do NOT downgrade the attribution/push stack**
to "match an old example" — old AppsFlyer/Firebase mis-classify Organic
vs Non-organic and hang on first-run token retrieval. Diversify per
project by bumping WITHIN or ABOVE these, never below.

```yaml
dependencies:
  # ── Attribution & push — do not downgrade
  appsflyer_sdk: ^6.18.0
  app_tracking_transparency: ^2.0.6+1   # iOS ATT
  firebase_core: ^4.11.0
  firebase_messaging: ^16.4.0
  firebase_app_check: ^0.4.5
  flutter_local_notifications: ^22.0.1

  # ── Rest of the stack — stagger minor versions per project
  connectivity_plus: ^7.1.1
  http: ^1.6.0
  device_info_plus: ^11.4.0
  flutter_secure_storage: ^10.3.1
  shared_preferences: ^2.5.5
  webview_flutter: ^4.14.0
  webview_flutter_wkwebview: ^3.22.0     # iOS WKWebView
  video_player: ^2.9.3                   # loading-screen video
  url_launcher: ^6.3.2
  # file_picker for WebView upload — pin to a stable line if a build breaks.
```

---

## Git Branch Strategy

| Branch | Purpose |
|--------|---------|
| `ios-gray-template` | this template — clean gray flow, no credentials |
| `ios-gray-part` | production gray flow for a specific app |
| `ios-white-part` | game only (no gray flow) |

**Merge gray into white:** `git checkout ios-white-part && git merge
ios-gray-template`. Resolve conflicts in `pubspec.yaml`, `main.dart`,
`Info.plist`, `project.pbxproj`. The gray `main.dart` MUST win (it
initialises Firebase); the game connects at
`BootScreen._goGame()` / `WhitePartPlaceholder`.

---

## Testing Guide

### Non-organic (WebView must open)
1. Add the device IDFA to AppsFlyer Test Devices.
2. Tap an AppsFlyer tracking link / OneLink BEFORE installing.
3. Install → launch → WebView.
4. Kill → relaunch → WebView (saved-url path).
5. Kill → send a push with a `url` → tap → URL opens in the WebView.

### Organic (game must open)
Install WITHOUT a tracking link → game, no push prompt, no WebView.

### Notes
- **Real device only** — attribution, push and ATT never work on the
  iOS Simulator.
- Test resource: `https://web.team-s.club/` — exercise login, form,
  upload, redirect, external-app hand-off, inline video, safe area.
- Verify the config body in debug logs contains all seven device-side
  fields before filing a "push doesn't arrive" bug.
