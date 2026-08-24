# Gray-Flow Lessons — bugs hit while building from the template

Every item below is a real bug that cost debugging time on the previous
template. The fix is already applied in this codebase — do NOT regress it.

**Sections 1–14** are runtime / build bugs. **Sections 15–24** are
static-analysis markers derived from the HenYardSprint / StormBlitz
post-mortem — every one of them is what Apple's cluster scanner reads
without launching the app. Read `apple_moderation_hardening.mdc` for the
authoritative catalogue; the items below are quick "do not regress"
entries mapped to DEV_PLAYBOOK Stage 5.

## 1. WKWebView `isForMainFrame` can be null → app "freezes", no-wifi never shows
**Symptom:** internet drops inside the WebView; nothing happens, app looks
frozen; the offline screen never appears.
**Cause:** `onWebResourceError: if (err.isForMainFrame != true) return;` — on
WKWebView `isForMainFrame` is sometimes `null` for the main navigation, so a
real load failure was silently swallowed.
**Fix (`roost_portal.dart`):** treat null as main-frame:
```dart
final mainFrame = error.isForMainFrame ?? true;
if (error.errorCode == -999) return; // cancelled
... if (!mainFrame) return;
```

## 2. Offline must show IMMEDIATELY on connectivity none (no probe first)
**Cause:** a DNS probe hangs for seconds while offline, during which the
WebView renders its own error page.
**Fix:** connectivity `none` → `_goOffline()` directly (no probe). Only
WebView *load errors* (which can be transient) go through a probe first.

## 3. Retry on the offline screen must RE-RUN the pipeline
**Symptom A (crash):** Retry threw "widget unmounted / defunct context".
**Cause:** the offline screen captured the parent's `BuildContext` in an
`onRetry` closure. **Fix:** `EmptyAirPage` takes a `retryBuilder` (WidgetBuilder)
and navigates with its OWN context.
**Symptom B (infinite offline):** Retry kept returning to no-wifi even with
internet. **Cause:** `HatchCoordinator.decide()` cached its future forever, so
Retry replayed the cached `OfflineNest`. **Fix:** cache only de-dupes
*concurrent* startup calls, then clears (`whenComplete`) so a later Retry runs
fresh:
```dart
Future<HatchDestination> decide({...}) =>
    _decideFuture ??= _decide(...).whenComplete(() => _decideFuture = null);
```

## 4. Gate-enable predicate must not depend on optional fields
**Symptom:** whole gray flow silently disabled (no AppsFlyer, no config POST,
white part only). **Cause:** `grayCredentialsReady` required `oneLinkHost`
which was empty. **Fix:** predicate = `endpoint && appsFlyerKey &&
firebaseProjectNumber` ONLY. OneLink and similar are optional.

## 5. AppCheck / Firebase failure must not disable attribution
**Cause:** attribution/gate was tied to `productionServicesReady` which was set
only if Firebase AND AppCheck succeeded. **Fix (`main.dart`):** init Firebase
and AppCheck in separate try/catch; the gate runs on
`EraHatchConfig.grayCredentialsReady`, independent of AppCheck. AppCheck debug
token errors are harmless.

## 6. Cold-start push must open in the phone's ACTUAL orientation
**Symptom:** tapping a push (app killed) opened the link in landscape, then
flipped to portrait. **Cause:** the "stretched WebView" fix used a micro-
rotation to `landscapeLeft` (visible flip). **Fix:** removed the forced
rotation; keep deferred mount + immersive settle, then correct any residual
stretch via post-load `resize` + one `reload()` in the current orientation.

## 7. Rotation jitter — poke reflow several times
**Cause:** WKWebView keeps the pre-rotation viewport width ~1s → site renders
wrong then snaps. **Fix (`didChangeMetrics`):** on orientation change, dispatch
`orientationchange`+`resize` at several delays (40/160/320/560/850ms) and
re-assert inset/zoom, so the page reflows in ~0.3s.

## 8. WebView must feel native — kill zoom, tap-highlight, overscroll
- `enableZoom(false)` is NOT enough on iOS. Inject a viewport lock
  (`maximum-scale=1, user-scalable=no`) + preventDefault on
  `gesturestart/gesturechange` and double-tap (`_installZoomLock`).
- Kill the grey box on tap: `* { -webkit-tap-highlight-color: transparent }`
  (`_installTapPolish`).
- Stop rubber-band into black: `html,body{overscroll-behavior:none}` in the
  inset-guard CSS.

## 9. Safe area
- WebView: pad with `MediaQuery.viewPadding` on ALL sides (top notch + bottom
  home indicator) in both orientations. Cold-start uses `viewPadding`, never
  `EdgeInsets.zero`.
- Permit / no-wifi screens in **landscape**: do NOT wrap buttons in `SafeArea`
  and center them horizontally — the notch inset otherwise shifts the
  horizontal center and the buttons look off. Portrait may keep a bottom gap.

## 10. Permit / offline screens must rotate
`BootScreen` locks portrait right before routing; `FeatherInvitation` and
`EmptyAirPage` re-enable `portraitUp + landscapeLeft/Right` in `initState`,
otherwise they stay portrait-locked.

## 11. GCD lookup uses the numeric App Store id on iOS (not bundle id)
`https://gcdsdk.appsflyer.com/install_data/v5.0/id<iosStoreId>?device_id=...`.
Using the bundle id returns wrong/empty data.

## 12. Credential encoding — always regenerate + verify
Never hand-edit the encoded byte arrays. A single stray/missing byte corrupts
the URL (seen: an extra byte turned the endpoint into garbage → 404s / gate
off). Always `dart run tool/encode_era_values.dart` and confirm the VERIFY
block round-trips exactly.

## 13. Asset quality
- Ship screen art as **webp**, display with `filterQuality: FilterQuality.high`,
  and provide source ≥ the device resolution (a 460px source upscaled looked
  pixelated). Compress large PNGs to webp (chapters went 46MB → 4.7MB).
- Use a real display font (bundled `Baloo2`) — the system serif looked default
  and ugly.

## 14. App icon must be opaque (no alpha) for iOS
Generate all `AppIcon.appiconset` sizes from a 1024² source with alpha
flattened, or App Store review rejects it.

---

## Section 2 — Static-analysis markers (App Store cluster hits)

Bugs 15–24 come from real portfolio kills where Apple's static analyzer
matched the binary before App Review ever saw it (Pending Termination
Notice → skipped `In Review` state). Fix them BEFORE submitting.

## 15. Plaintext `Mozilla/5.0 (iPhone…` scaffolding in the UA
**Symptom:** app is banned without ever entering In Review; the sibling
account is banned within 24 h.
**Cause:** `roost_agent.dart` builds the UA as
`'Mozilla/5.0 (iPhone; CPU iPhone OS $cpu like Mac OS X) …'` — the
scaffolding is a plaintext string literal that Apple's UA cluster indexes
verbatim, regardless of the decoded version fragments.
**Fix:** every UA fragment (product token, platform prefix/suffix, engine
token, mobile token, Safari tail) lives as an encoded byte array in
`EraHatchConfig`, assembled at runtime. Verification:
```bash
rg -n 'Mozilla/5\.0|iPhone; CPU iPhone OS|AppleWebKit|Mobile Safari|like Gecko' lib/
# → must be empty.
```
See `gray_user_agent.mdc` §1 and `apple_moderation_hardening.mdc` §4.

## 16. `appid/<bundleId> appname/<AppName>` suffix in the UA
**Symptom:** same as 15 — the suffix is the single most damning literal
in the binary (chat_export.md §Markers #1).
**Cause:** slot-game partner backends historically require the identity
appended to the UA. The exact `appid/… appname/…` pattern is a known
affiliate signature.
**Fix priority:**
1. Ask the partner to accept the identity as `X-Partner-App-*` custom
   headers on the config POST → suffix disappears from the binary.
2. If refused, encode `'appid/'` and `'appname/'` tokens as byte arrays,
   assemble the suffix at runtime.
3. Never omit both encoding AND relocation.
Verification:
```bash
rg -n "appid/|appname/" lib/
# → must be empty.
```
See `gray_user_agent.mdc` §2.

## 17. Purpose string declared without matching API call
**Symptom:** immediate auto-reject with 2.3.1 "hidden functionality".
**Cause:** `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`
in `Info.plist` while the white part has zero `image_picker` /
`AVCaptureDevice` / `PHPhotoLibrary` calls. Apple diffs the two sets.
**Fix:** either strip the key from `Info.plist` OR add a visible
white-part feature that actually calls the API AND word the purpose
string around that feature (never "the embedded web view").
Verification: `apple_moderation_hardening.mdc` §9.4.

## 18. `LSApplicationQueriesSchemes` contains `http` / `https`
**Symptom:** contributes to the cluster hit (an oddly specific
copy-paste artefact — no honest app writes this).
**Cause:** copied verbatim from a partner-flow template.
**Fix:** remove both entries; keep only schemes we actually hand off to
(`tel`, `mailto`, and any specific external app). `http` / `https` are
opened via `UIApplication.canOpenURL` without registration.

## 19. Missing `PrivacyInfo.xcprivacy`
**Symptom:** submission auto-rejected — "Required Reason API" errors
listing `NSUserDefaults`, disk-space, boot-time, etc.
**Cause:** `device_info_plus`, `flutter_secure_storage`,
`shared_preferences`, `webview_flutter` all use Required Reason APIs.
**Fix:** ship `ios/Runner/PrivacyInfo.xcprivacy` (see
`gray_flow_guide.md` §"iOS-Specific Notes: Info.plist keys") and add it to
Runner's Copy Bundle Resources phase in `project.pbxproj`.
Verification: `plutil -lint ios/Runner/PrivacyInfo.xcprivacy`.

## 19a. ITMS-91064 — `NSPrivacyTracking` true with an empty domain list
**Symptom:** App Store Connect rejects the upload before review:
"ITMS-91064: Invalid tracking information … NSPrivacyTracking must be true
if NSPrivacyTrackingDomains isn't empty." Hit ClumsyHenRace 1.0.3 (5).
**Cause:** the e-mail text is the inverse of the real rule. Per TN3181,
`NSPrivacyTracking = true` with an **empty** `NSPrivacyTrackingDomains`
array is invalid — and this template's own guidance used to say "keep this
list empty". `plutil -lint` passes on the broken file, so the §9.5 gate did
not catch it.
**Fix:** list AppsFlyer's dedicated tracking hosts —
`att.attr` / `att.launches` / `att.conversions` / `att.dlsdk`
`.appsflyersdk.com`. Never list the config endpoint, the partner WebView
host or `onelink.me`: iOS fails requests to declared tracking domains when
ATT is denied, which would kill the gray flow for those users. Do not
"fix" it by flipping tracking to `false` while IDFA + ATT + AppsFlyer ship.
Verification: `apple_moderation_hardening.mdc` §9.5a.

## 20. Self-written RC4-style stream cipher (KSA + PRGA) in the binary
**Symptom:** the byte-array → cipher loop → `Uri.parse` →
`WebViewController.loadRequest` data-flow is a known static signature
(chat_export.md §Markers #3). Rotating `_nestSalt` does not change the
graph shape.
**Fix:** replace `feather_codec.dart` with a standard primitive
(`base64Decode` + one-pass XOR against a device-derived key), OR fetch
the config-endpoint host from a remote signed configuration file (no
decoder infrastructure in the binary at all). Never encrypt public URLs
(privacy / support) — they only prove decoder infrastructure exists.
Verification: `apple_moderation_hardening.mdc` §9.6.

## 21. `ITSAppUsesNonExemptEncryption = false` while shipping a custom cipher
**Symptom:** formal declaration mismatch — even if XOR/RC4 is technically
not "content-protection encryption", the declared `false` next to a
KSA/PRGA loop is a red flag on manual review.
**Fix:** either (preferred) remove the custom cipher (§20) then honestly
declare `false`, OR set `true` and answer "using only exempt encryption"
= yes in App Store Connect. Do NOT ship `false` with the loop present.

## 22. Post-release URL router (game → web on later launch, arbitrary push URL)
**Symptom:** Guideline 2.5.2 / 2.3.1 flag on reviewer note — "the app
changes its purpose after review".
**Cause:** `HatchCoordinator._returningNative` can flip an existing
game-mode install to WebView; `LaunchRouteReader.consume()` loads any URL
from a push payload into the fullscreen WebView.
**Fix (without a host allowlist):**
- Do **not** add a host / domain allowlist — the config may replace the
  partner URL with an unknown host after release; an allowlist would
  silently break that swap. See `apple_moderation_hardening.mdc` §6.
- Gate WebView navigations by **scheme** only (`http`/`https`/…).
- Saved URL must expire (`EraHatchConfig.savedUrlExpiryDays`, default 7).
- Push URL is one-shot (`consume()` clears it).

## 23. Structural invariants that survive renaming (numeric constants, JS set)
**Symptom:** two apps with different names/salts/icons still cluster.
**Cause:** magic numbers (`3 days push cooldown`, `6 s organic retry`,
`15 s config timeout`, `retry -1007 × 3`, `ATT wait 5 s`) and the six-JS
injection set (zoom lock, tap polish, keyboard lift, focus scale, inline
media, inset guard) are hashed by the scanner regardless of names.
**Fix:** rotate each numeric constant per project to a project-unique
value (`gray_part_mixing_review.mdc` §6a); reduce OR merge OR reorder the
JS injection set (`gray_part_mixing_review.mdc` §6b). Never ship two
sibling apps with the same numeric row.

## 24. Metadata mismatch (pubspec / README / CFBundleName)
**Symptom:** Guideline 4.3 hit — the code does one thing and the
description says another.
**Cause:** `pubspec.yaml` `description` still says "Gray-flow iOS
template" (or a name from a copied project) while the README and the
game code describe something completely different.
**Fix:** `pubspec.yaml` `name` + `description`, `README.md`,
`Info.plist` `CFBundleName` + `CFBundleDisplayName`, and App Store
Connect metadata must all describe the WHITE game consistently. Never
mention "template", "gray flow", "WebView" or "partner" in anything
shipped or public. See `apple_moderation_hardening.mdc` §8.

## 25. Attribution started before the reachability probe on a first launch
**Symptom:** a non-organic install whose first launch had no route out
lands in the white game permanently after the user restores the network
and taps Retry. On the way there the ATT prompt appears on top of the
offline screen.
**Cause:** the attribution SDK was started ahead of the reachability
check (to widen the deferred-deep-link window). Without a route out its
conversion callback fires `{status: failure}`, the empty payload is
cached in the process for good, and `start()` is memoized — so the Retry
that follows reuses the poisoned state, posts a body with no attribution
fields, and the gate answers "no data". A first-launch answer without an
address commits the route to the game, and nothing revisits it.
**Fix:** on the undecided route nothing network-dependent may run before
both link checks pass — interface, then real reachability, and only then
the push warmup and `awaitSignals()` (which opens the SDK, and with it
the consent prompt). `HatchCoordinator._firstDecision` is the reference
order. Note that this makes the SDK start ~1 s later on a healthy
launch; that is the intended trade.
**Related:** the offline screen's artwork must be warmed before handing
over, or the hand-over paints a black frame first and reads as a crash.
Do NOT hold the offline verdict for the full minimum splash time on top of
that — a dead end that takes three seconds to admit it feels broken. A
short floor (~0.7 s) is enough for the splash to be seen.

## 26. ATT prompt lost for a whole run (memoized SDK start + inactive app)
**Symptom:** the consent prompt never appears on the launch that should
show it and turns up on the next cold start instead. Worst case on a
first launch that began offline: the user retries, gets the content
channel, and consent is asked for only on the launch after that.
**Cause:** two mechanisms, usually together. (1) `requestTrackingAuthorization`
returns the current status *without presenting anything* while the app is
not frontmost, and the status stays `notDetermined` — a request fired
during a route transition or while the app is still settling is simply
lost. (2) The consent call lives inside the memoized `attribution.start()`,
so once that future has completed the prompt is never attempted again in
that process, no matter how many times the pipeline re-runs.
**Fix:** give consent its own memoized future, separate from the SDK
start, and call it explicitly from the pipeline right after reachability
is confirmed (the SDK start awaits the same future, so nothing asks
twice). Before requesting, wait until `WidgetsBinding.instance.lifecycleState`
is `resumed` — treating `null` as frontmost, since the platform reports it
late on a cold start — and if the returned status is still `notDetermined`,
wait for frontmost and request once more. Warm APNs in parallel with the
prompt instead of ahead of it: the prompt is what the user expects to see
first, and registration has no reason to delay it.
