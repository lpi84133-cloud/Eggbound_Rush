# Custom Screen Assets — Template Contract (iOS-first)

## Purpose

The gray-flow shell uses **orientation-aware background assets** for three
foreground screens: the loading splash, the push-permission screen and the
no-internet screen. This rule is the single source of truth for **where
those assets live** and **how each screen must consume them**.

The template ships example artwork under `assets/Loading/`,
`assets/Notifications/` and `assets/Nowifi/`. Replace those files with
project-specific artwork on every new build, and register them in
`pubspec.yaml` under `flutter.assets`.

---

## Loading / Splash Screen (BootScreen)

**File:** `lib/screens/boot_screen.dart`

This template's loading screen uses a **looping muted background video**
plus a **progress-bar image swapped between discrete states** (not an
animated 0→100 % bar).

**Video background (both required):**
- Portrait: `assets/Loading/Vertical_Loading_Screen.mp4`
- Landscape: `assets/Loading/Horizontal_Loading_Screen.mp4`

**Progress-bar frames (webp):**
- `assets/Loading/Loading_Bar_Empty.webp`  → `_BarStep.empty`
- `assets/Loading/Loading_Bar_Half.webp`   → `_BarStep.midway`
- `assets/Loading/Loading_Bar_Almost.webp` → (optional intermediate)
- `assets/Loading/Loading_Bar_Full.webp`   → `_BarStep.done`

**Rules:**
- The video is chosen by orientation in `didChangeDependencies` and played
  with `BoxFit.cover` inside a `FittedBox`, muted, looping.
- The bar image fades in only after `_vidReady` — never render the bar
  over a black frame.
- `_bar` reaches `done` at the moment routing decides the next screen; the
  bar hitting "full" must map to real boot completion (do not park it at
  full and hang).
- The animated "loading" feel comes from the video — do not bake UI chrome
  or clickable regions into it.

---

## Push Permission Screen (FeatherInvitation)

**File:** `lib/hatchway/pages/feather_invitation.dart`

**Background assets:**
- Portrait: `assets/Notifications/Vertical_Notifications_Screen.webp`
- Landscape: `assets/Notifications/Horizontal_Notifications_Screen.webp`

```dart
final bool landscape =
    MediaQuery.of(context).orientation == Orientation.landscape;
final String bg = landscape
    ? 'assets/Notifications/Horizontal_Notifications_Screen.webp'
    : 'assets/Notifications/Vertical_Notifications_Screen.webp';
Image.asset(bg, fit: BoxFit.cover);
```

The Accept / Skip buttons overlay this image (`Align`).
**Skip must be a real, visible button** (same gradient family as Accept),
not a low-contrast text link; labels use `height: 1.0` +
`CrossAxisAlignment.center` (no baseline drift). Verify both orientations.

> ⚠️ **LESSON — landscape button centering (do NOT regress):**
> In **landscape**, do NOT wrap the buttons in `SafeArea`, and center them
> horizontally (`Align(Alignment(0, y))`). The notch/Dynamic Island inset
> otherwise shifts the horizontal center and the buttons look skewed/off.
> Portrait may keep a small bottom gap. Same rule for the no-wifi Retry.
>
> ⚠️ **LESSON — these screens must rotate:** `BootScreen` locks portrait right
> before routing here, so `FeatherInvitation` and `EmptyAirPage` must
> re-enable `portraitUp + landscapeLeft/Right` in `initState`, or they stay
> portrait-locked.
>
> ⚠️ **LESSON — button size/quality:** make buttons large and legible; render
> the screen at device resolution and eyeball that buttons are centered on the
> art and not pixelated (ship webp + `filterQuality: FilterQuality.high`;
> source art ≥ device resolution — a 460px source upscaled looks blocky).

---

## No-Internet Screen (EmptyAirPage)

**File:** `lib/hatchway/pages/empty_air_page.dart`

**Background assets:**
- Portrait: `assets/Nowifi/Vertical_Nowifi_Screen.webp`
- Landscape: `assets/Nowifi/Horizontal_Nowifi_Screen.webp`

The Retry button is a `Positioned` widget at the bottom; it rebuilds a
fresh `BootScreen` (`retryBuilder`) to re-run the whole pipeline.

**⚠️ CRITICAL:** show this screen **immediately** on
`ConnectivityResult.none` — no DNS probe first. A probe can hang for
seconds while offline, during which the WebView renders its built-in error
page. Load-error recovery (which can be transient) uses the
probe-then-show path; keep the two paths separate.

Retry sizing: portrait width ≈ 70 % (clamp 220–380), landscape ≈ 35 %;
never cover the artwork illustration; guard against double-tap.

---

## WebView Safe Area (camera cutout / Dynamic Island / home indicator)

**File:** `lib/hatchway/pages/roost_portal.dart`

> ⚠️ **LESSON (corrected):** pad the WebView with `MediaQuery.viewPadding` on
> **ALL** sides (top + bottom + left + right), in both orientations — the user
> wants a real bottom safe zone (home indicator) as well as the top notch and
> the side cutout in landscape. `SafeArea(bottom:false)` leaves content under
> the home indicator.

```dart
final safe = MediaQuery.of(context).viewPadding;
Padding(
  padding: EdgeInsets.only(
    top: safe.top, bottom: safe.bottom, left: safe.left, right: safe.right,
  ),
  child: WebViewWidget(controller: _wv),
);
```

For the cold-start push case still read `MediaQuery.viewPadding` (never
`EdgeInsets.zero`) — see `cold_start_push_viewport.mdc`. The keyboard is
handled by the JS scroll fix.

---

## Asset Registration

Declare every asset in `pubspec.yaml` under `flutter.assets`:

```yaml
flutter:
  assets:
    - assets/Loading/Horizontal_Loading_Screen.mp4
    - assets/Loading/Vertical_Loading_Screen.mp4
    - assets/Loading/Loading_Bar_Empty.webp
    - assets/Loading/Loading_Bar_Half.webp
    - assets/Loading/Loading_Bar_Almost.webp
    - assets/Loading/Loading_Bar_Full.webp
    - assets/Notifications/Horizontal_Notifications_Screen.webp
    - assets/Notifications/Vertical_Notifications_Screen.webp
    - assets/Nowifi/Horizontal_Nowifi_Screen.webp
    - assets/Nowifi/Vertical_Nowifi_Screen.webp
    # - assets/<your_game_assets>/
```

---

## [FINGERPRINT] Replace artwork + vary folder names per project

The asset paths appear as literal strings in the compiled binary. Two apps
shipping the exact same artwork bytes AND the same folder layout are a
cross-submission fingerprint for store scanners.

For every new project:

1. **Replace the artwork** — never reuse the exact same webp/mp4 bytes
   across apps.
2. **Vary the folder segment** where practical (e.g. `assets/boot/`,
   `assets/permit_bg/`, `assets/offline_bg/`) and update the string paths
   in `splash_gate.dart`, `permit_screen.dart`, `no_signal_screen.dart` +
   `pubspec.yaml` accordingly.
3. **Replace the app icon** (`assets/Logo_white.webp` and the generated
   icon set) — do not ship a sibling app's icon.
4. Run `flutter clean && flutter pub get` before the next build.

Screen dimensions: portrait 1080×1920, landscape 1920×1080 (match the
device aspect so `BoxFit.cover` does not crop key art).
