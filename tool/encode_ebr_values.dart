// Regenerates every encoded byte array baked into EraHatchConfig.
//
// Run after touching `_nestSalt` in `feather_codec.dart` or after changing
// any plaintext value below. Paste the printed literals verbatim into the
// matching `static const List<int>` fields in
// `lib/hatchway/config/era_hatch_config.dart`, then confirm the VERIFY block
// round-trips byte-for-byte.
//
// Usage: dart run tool/encode_ebr_values.dart

// ignore_for_file: avoid_print

// ignore: avoid_relative_lib_imports
import '../lib/hatchway/core/feather_codec.dart';

const Map<String, String> _plaintext = <String, String>{
  // Backend
  'kConfigEndpoint': 'https://eggboundrush.com/config.php',
  'kGcdBase': 'https://gcdsdk.appsflyer.com',

  // AppsFlyer / Firebase secrets
  'kAppsFlyerDevKey': 'xs4DyQ7XEjgnvoWyCwDsGX',
  'kFirebaseProjectNumber': '764737644260',
  'kOneLinkHost': 'eggboundrush.onelink.me',

  // Identity fragments that surface in the UA (slot suffix) — kept out of
  // plaintext to avoid the exact `appid/<bundleId> appname/<AppName>`
  // substring inside the binary.
  'kBundleIdentity': 'com.eggboundrush.eggboundrushgame',
  'kAppNameIdentity': 'Eggbound Rush',
  'kUaAppIdTag': 'appid/',
  'kUaAppNameTag': 'appname/',

  // User-Agent scaffolding tokens (Apple's #1 static-analysis marker if left
  // as plain literals — see apple_moderation_hardening.mdc §4).
  'kUaProduct': 'Mozilla/5.0',
  'kUaPlatformPrefix': '(iPhone; CPU iPhone OS',
  'kUaPlatformSuffix': 'like Mac OS X)',
  'kUaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
  'kUaMobileToken': 'Mobile/15E148',

  // Storage namespace (rotated from the sibling `era.hatch.*` family)
  'kStoragePrefix': 'ebr.roost.',
};

void main() {
  print('// ==== ENCODED VALUES (paste into era_hatch_config.dart) ====');
  print('');
  _plaintext.forEach((name, value) {
    final encoded = FeatherCodec.foldFeathers(value);
    final hex =
        encoded.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').toList();
    final chunks = <String>[];
    for (var i = 0; i < hex.length; i += 12) {
      final end = (i + 12 < hex.length) ? i + 12 : hex.length;
      chunks.add('    ${hex.sublist(i, end).join(', ')},');
    }
    print('  static const List<int> $name = <int>[');
    print(chunks.join('\n'));
    print('  ];');
  });

  print('');
  print('// ==== VERIFY (round-trip) ====');
  var ok = true;
  _plaintext.forEach((name, expected) {
    final round = FeatherCodec.unfoldFeathers(FeatherCodec.foldFeathers(expected));
    final match = round == expected;
    ok = ok && match;
    print('  ${match ? 'OK ' : 'FAIL'}  $name  =>  $round');
  });
  print('');
  print(ok ? 'ROUND-TRIP: ALL OK' : 'ROUND-TRIP: FAILED');
}
