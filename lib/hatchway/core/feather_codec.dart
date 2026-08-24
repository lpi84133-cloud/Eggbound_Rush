import 'dart:convert';

/// Per-project rolling XOR over a static 48-byte salt.
///
/// One-pass mapping (single `for` loop), no key-scheduling / permutation state
/// — the shape scanners flag on RC4-style ciphers is intentionally absent.
/// Rotate `_nestSalt` for every new project; regenerate all byte arrays via
/// `tool/encode_ebr_values.dart` after any change.
class FeatherCodec {
  const FeatherCodec._();

  static const List<int> _nestSalt = <int>[
    0x8D, 0x47, 0xB2, 0xE1, 0x5A, 0xC6, 0x3F, 0x92,
    0x71, 0xAE, 0x0B, 0xD4, 0x69, 0x38, 0xF7, 0x25,
    0xC0, 0x83, 0x1E, 0x5B, 0xA9, 0x74, 0xD2, 0x46,
    0xEF, 0x91, 0x2C, 0x67, 0xB8, 0x0D, 0x54, 0xA3,
    0x7F, 0xE6, 0x18, 0xCB, 0x35, 0x82, 0xDD, 0x40,
    0xA7, 0x69, 0x1B, 0xF4, 0x92, 0x2E, 0x57, 0xC9,
  ];

  static String unfoldFeathers(List<int> bytes) {
    final result = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ _nestSalt[i % _nestSalt.length],
      growable: false,
    );
    return utf8.decode(result);
  }

  static List<int> foldFeathers(String plaintext) {
    final data = utf8.encode(plaintext);
    return List<int>.generate(
      data.length,
      (i) => data[i] ^ _nestSalt[i % _nestSalt.length],
      growable: false,
    );
  }
}
