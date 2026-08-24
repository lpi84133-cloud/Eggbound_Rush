# START HERE — Cursor / AI Agent Entry Point

> **Read this file first. Every time you are asked to work on this
> project, read this file, then read every file in `.cursor/rules/`
> before writing any code.**

This project is an **iOS-only Gray-Part Flow template** for Flutter. The
iOS path — APNs, the Notification Service Extension (NSE), SceneDelegate
cold-start capture, ATT, `project.pbxproj` — is where the hard,
error-prone work lives. The full architecture, the config API contract,
the state machine and the setup manual live in
`.cursor/rules/gray_flow_guide.md`. This file is the short "where to
look" index that points into it.

> **This template targets iOS only.** Do not add Android build config,
> manifests, notification channels, or Android-specific rules here — the
> whole toolchain (APNs + NSE + SceneDelegate + ATT + pbxproj) is iOS.

> **⚠️ READ `.cursor/rules/gray_flow_lessons.md` too** — it is the catalogue of
> real bugs hit while building an app from this template, each with the fix
> already applied here. Do not regress them.

> **⚠️ READ `.cursor/rules/apple_moderation_hardening.mdc` too** — this is the
> post-mortem catalogue of static-analysis markers that killed sibling apps
> (HenYardSprint / StormBlitz) *before* App Review ever saw them. Every
> submission must pass DEV_PLAYBOOK Stage 5 (mapped to that file). If a
> conflict appears between this rule and older rules in `.cursor/rules/`,
> the hardening rule wins.

> **👉 Building a NEW app? Follow `.cursor/DEV_PLAYBOOK.md`** — a copy-paste,
> stage-by-stage flow (fill your inputs, tick each stage, verify at the end).
> **Stage 5 (moderation markers) is mandatory before submission** — do not
> skip.

---

## 0. Operating protocol (the two pipelines: START_HERE + DEV_PLAYBOOK)

**These two files ARE the pipeline.** `START_HERE.md` is the map + invariants;
`DEV_PLAYBOOK.md` is the ordered stages. When a developer works with you (the
agent), drive the build through the playbook like this:

1. **You own the stage order.** Track which `DEV_PLAYBOOK` stage is active. When
   the dev says **"идём дальше" / "next" / "go on"**, advance to the next stage
   and run it — the dev should NOT have to re-paste prompts.
2. **Gate on inputs.** Before running a stage, check every input it needs (see
   the INPUTS block). If anything required is **missing or a placeholder, STOP
   and ask for exactly that value** — never scaffold with a guess or a stub.
3. **Self-verify every stage before advancing.** At the end of each stage run
   its "Done when" checks yourself: read the relevant `rules/*` and
   `gray_flow_lessons.md`, confirm your own code matches, run `flutter analyze`,
   render screens, or make the real request the stage asks for. Report each
   check as **OK `<file:line>`** or **FOUND → fixed**.
4. **Do not mark a stage done until its checks pass.** If a check fails, fix it,
   re-verify, then continue.
5. **Announce transitions.** Say which stage just passed and which is next, so
   the dev can simply reply "next".

> TL;DR for the dev: paste the INPUTS once, then just say **"идём дальше"** each
> time. Cursor advances the stage, asks for any missing data, verifies its own
> work against the rules, and only then moves on.

> **This template's structure differs from generic gray-flow docs below:**
> - Routing lives in **`HatchCoordinator.decide`** (not a single
>   `BootScreen._boot`). `BootScreen` is the splash UI + it calls `decide`.
> - All encoded creds live in **one** file: `hatchway/config/era_hatch_config.dart`
>   (there is no separate `endpoint_vault` / `signal_keys` / `brand_links`).
> - The cipher is `hatchway/core/feather_codec.dart` (`unfoldFeathers`,
>   `_nestSalt`), encode tool is `tool/encode_era_values.dart`.
> The code is the source of truth; adapt any stale symbol names you see below.

---

## 1. What "gray flow" means (30-second version)

A dual-mode Flutter app:

- **Gray mode** — full-screen WebView (`RoostPortal`) loading a URL
  from a remote config endpoint. Non-organic (paid / ad-attributed)
  users see this.
- **White mode** — a native game (`lib/screens/*`, `lib/widgets/*`,
  wired through `WhitePartPlaceholder` in `lib/white/white_placeholder.dart`).
  Organic users see this. Also what App Store reviewers see.

The routing decision is made ONCE per install, by the backend, from
AppsFlyer attribution data. It cannot be spoofed client-side.

Detailed doc: `.cursor/rules/gray_flow_guide.md` §"What Is This Project?".

---

## 2. Where to look for what

| You need to… | Read |
|---|---|
| Build a new app step by step (inputs → stages → verify) | `.cursor/DEV_PLAYBOOK.md` |
| Understand the whole architecture end-to-end | `.cursor/rules/gray_flow_guide.md` (top-to-bottom) |
| **Harden the binary against App Store static-analysis (MANDATORY before shipping)** | `.cursor/rules/apple_moderation_hardening.mdc` + DEV_PLAYBOOK Stage 5 |
| Get the concise map of files / classes / API | `.cursor/rules/AGENT.md` |
| Know the exact config-endpoint request / response | `gray_flow_guide.md` §"Config Request Contract" |
| Know the boot sequence + state transitions | `gray_flow_guide.md` §"Gray Flow State Machine" |
| Handle the OneLink + offline install scenario | `gray_flow_guide.md` §"First-Launch UX Contract" |
| Style the loading / splash screen | `gray_flow_guide.md` §"Screen Layout: BootScreen (Loading)" |
| Style the push-permission screen | `gray_flow_guide.md` §"Screen Layout: FeatherInvitation" |
| Style the no-internet screen | `gray_flow_guide.md` §"Screen Layout: EmptyAirPage" |
| Wire the NSE into `project.pbxproj` | `.cursor/rules/pbxproj_nse_integration.mdc` + `gray_flow_guide.md` §"Ideal project.pbxproj Structure" |
| Fix the cold-start push → stretched WebView | `.cursor/rules/cold_start_push_viewport.mdc` |
| Make the binary NOT a clone of sibling apps + pass review | `.cursor/rules/gray_part_mixing_review.mdc` (§6 structural invariants is mandatory) |
| Configure the WebView safe-area CSS injection | `.cursor/rules/webview_safe_area_injection.mdc` |
| Set the User-Agent (encoded scaffolding + slot / crash decision) | `.cursor/rules/gray_user_agent.mdc` |
| Wire the custom screen background assets | `.cursor/rules/custom_screens.md` |
| Add Microsoft Clarity analytics (OPTIONAL — only if the user asks; if unsure, ask first) | `.cursor/rules/clarity_analytics.mdc` |
| Avoid the exact bugs hit last time (offline/retry/rotation/webview/gate/creds + static-analysis markers) | `.cursor/rules/gray_flow_lessons.md` (§1–§14 runtime, §15–§24 App Store markers) |
| Verify a release is ready to ship | `.cursor/FINAL_CHECKLIST.md` (Part G is the moderation gate) |

---

## 3. Order of operations for a new project (one-shot generation)

You will normally be handed a customer brief. Do it in this order:

1. **Parse the brief against §"Inputs You Need Before Generating"** in
   `gray_flow_guide.md`. If any starred (★) input is missing (config
   endpoint, AppsFlyer key, Firebase config, iOS App Store numeric id,
   privacy URL, cipher seed, screen assets, **slot-vs-crash theme**),
   STOP and ask the user in one batched question. Do not scaffold with
   placeholders that silently break.
2. **Refresh the fingerprint.** Every location in §4 below must be
   re-diversified for this project. See also
   `.cursor/rules/gray_part_mixing_review.mdc` — renaming public classes
   is NOT enough.
3. **Fill config layer.** In this order:
   - `lib/hatchway/config/era_hatch_config.dart` → `bundleId`, `iosStoreId`
     (numeric App Store id), `appTitle`
   - `lib/hatchway/config/era_hatch_config.dart` → privacy + support URLs
   - `tool/encode_era_values.dart` → paste raw config endpoint / AppsFlyer
     dev key / Firebase project number / privacy / support / GCD URL
   - `lib/hatchway/core/feather_codec.dart` → change `_nestSalt` (and ideally the
     cipher algorithm — see mixing rule) to fresh unique values
   - Run `dart run tool/encode_era_values.dart` → paste the byte arrays into
     `lib/hatchway/config/era_hatch_config.dart` + `signal_keys.dart`
     (+ `brand_links.dart` if you encode those too). **VERIFY block
     must match plaintext exactly.**
4. **Sync bundle identity.** All of these MUST match
   `EraHatchConfig.bundleId`:
   - `ios/Runner.xcodeproj/project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER`
     ×3 (Runner Debug/Release/Profile) + ×3 (NSE, with the exact NSE
     suffix from Apple Developer Portal)
   - `GoogleService-Info.plist` → bundle id
5. **Wire iOS push (NSE + entitlements + SceneDelegate).** See
   `gray_flow_guide.md` §"Setup Checklist" Step 7 and
   `.cursor/rules/pbxproj_nse_integration.mdc`.
6. **Replace assets.** See `.cursor/rules/custom_screens.md`. Swap the
   loading video + bar frames + push / no-wifi backgrounds; rename the
   asset folder segment per project.
7. **White-part routes.** Register EVERY named route the game uses in
   `FeatheredOriginsApp` (`lib/app/app.dart`) — a missing route crashes on the
   organic path (`Could not find route "/menu"`).
8. **Build & smoke-test.**
   - `flutter pub get && flutter analyze`
   - iOS: `cd ios && pod install` (NO base-configuration warnings) →
     open `Runner.xcworkspace` → run on a **real device** (push /
     attribution / ATT never work on Simulator).
9. **QA against `.cursor/FINAL_CHECKLIST.md`.** Every point must pass on
   a real device before shipping.

---

## 4. Fingerprint — mandatory per-project changes

Everything below MUST differ between projects. Static analysis reads
private symbols, string literals and machine code — see
`.cursor/rules/gray_part_mixing_review.mdc` for the deeper list
(cipher *algorithm*, JS injection bodies, probe host, backend infra).

> **⚠️ The cosmetic list below is not enough.** Read
> `.cursor/rules/apple_moderation_hardening.mdc` §7 and
> `gray_part_mixing_review.mdc` §6 for the **structural** invariants Apple
> actually clusters on: numeric constants, JS injection behaviour set,
> purpose-string ↔ API-use consistency, root-UI bifurcation, cipher family.
> Renaming without rotating those does not decouple sibling apps.

- `lib/hatchway/core/feather_codec.dart` → `_nestSalt` (+ ideally the cipher family)
- `tool/encode_era_values.dart` → seed + all plaintext values, re-run after
  every seed change
- `lib/hatchway/config/era_hatch_config.dart` → `bundleId` / `iosStoreId` /
  `appTitle`
- `lib/hatchway/config/era_hatch_config.dart` → privacy + support URLs (unique
  per project)
- `lib/hatchway/config/era_hatch_config.dart` + `signal_keys.dart` → freshly
  encoded byte arrays
- `pubspec.yaml` → `name` + `description` + `version` + stagger at least
  two plugin minor versions from the previous project
- `lib/app/app.dart` → `FeatheredOriginsApp` class name + `title`
- `lib/screens/boot_screen.dart` → `BootScreen` class + private
  method / variable names (`_boot`, `_handleFreshMode`, `_goContent`, …)
- `lib/hatchway/infra/launch_route_reader.dart` → `_key = 'era_launch_route'`
- `ios/Runner/SceneDelegate.swift` → `tapUrlKey = "flutter.era_launch_route"`
  (MUST stay in sync with the bridge key, including the `flutter.` prefix)
- SharedPreferences / SecureStorage key prefixes (`era.hatch.*` → new prefix)
- Debug log tags (`[ERA.*]` → project-specific; must be stripped from
  release, see mixing rule §2)
- `ios/Runner.xcodeproj/project.pbxproj` → NSE `PRODUCT_BUNDLE_IDENTIFIER`
  + all NSE UUIDs (random 24-hex, no `AA0000…` pattern)
- Asset folder segment (see `custom_screens.md`)
- Clarity `projectId` (once analytics is added — see `clarity_analytics.mdc`)
- Safari / iOS version fragments in the User-Agent (see `gray_user_agent.mdc`)

---

## 5. Things that must NEVER break (invariants)

If your changes threaten any of the following, STOP and reconsider —
these are the load-bearing behaviours of the gray flow:

1. **Cold-start push tap is consumed FIRST.** In `BootScreen._boot()`,
   `LaunchRouteReader.consumeTapUrl()` runs before push bootstrap, before
   the network check, before attribution. Reordering it loses the URL to
   a timeout race and the user lands on the game/menu instead of the
   push destination.
2. **Non-organic + offline install boot** must show the No-Signal screen
   promptly, then retry back through the full pipeline (network →
   attribution → gate → `RoostPortal`). No game screen, no loop.
3. **`NestRoute.fresh` never commits to `game` on a network failure** —
   only a successful config response with no URL commits the game path.
   Otherwise offline-install non-organic users trap in the game forever.
4. **`push_token` + `firebase_project_id` are omitted from the config
   body when the push token is not ready** — never sent as empty strings
   or `null`. Token arrival triggers `onTokenRefresh` → immediate re-POST.
5. **The AppsFlyer conversion payload is forwarded verbatim** to the
   config endpoint — no field renamed, dropped, or added except the
   documented device-side fields.
6. **WebView back gesture** returns one page inside the WebView;
   back-from-first-page does NOT close the WebView.
7. **File upload input** opens the native chooser (camera + gallery)
   without a filesystem-permission dialog.
8. **User-Agent looks like a real Mobile Safari on a real iPhone** — no
   `Dart/…`, `Flutter/…`, `CFNetwork`, `Darwin`, or package-name tokens;
   identical UA on the HTTP client and the WebView.
9. **`GoogleService-Info.plist` is in Runner's Copy Bundle Resources**
   and the NSE has NO `baseConfigurationReference` — breaking either
   silently kills Firebase / push.
10. **`project.pbxproj` is saved without a UTF-8 BOM and with real tabs
    (never literal `\t`)** — see `pbxproj_nse_integration.mdc`. A BOM or
    escaped tab breaks `pod install` on macOS.

For every invariant there is a matching item in `FINAL_CHECKLIST.md`.

---

## 6. When the user asks something you cannot solve here

- The user is often on **Windows / PowerShell**; the build often runs on
  **macOS / Codemagic**. `project.pbxproj` edited on Windows must be
  saved as binary (`.gitattributes: *.pbxproj binary`), without BOM, with
  real tabs — see `pbxproj_nse_integration.mdc`.
- Prefer `dart run tool/encode_era_values.dart` over ad-hoc PowerShell loops —
  PowerShell overflows 32-bit integers and produces wrong byte values
  (symptom: `FormatException: Invalid HTTP header field value`).
- If the user asks you to "make it work like project X", first find and
  diff project X's fingerprint locations (§4) to know what MUST diverge.
