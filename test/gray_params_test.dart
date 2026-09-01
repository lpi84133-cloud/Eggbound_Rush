import 'dart:convert';

import 'package:eggbound_rush/gray/gray_params.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const params = GrayParams(
    appId: 'com.eggboundrush.eggboundrushgame',
    pushToken: 'fXMyrVpa20bIkqHzCSi2RF:APA91b',
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 26_5 like Mac OS X)',
    deviceID: '74785751e3fcc02cdec84c600b1e0964',
    adId: '8E9D5DFB-0CAB-4CD1-8F8F-3D1BDF2EC668',
    oneLink: '',
    naming: '{"network":"TestLink","campaign":"attributionName001"}',
    referer: '63Ar3zrw42HjRHlKfxP3S7fHvd4v',
  );

  test('body carries exactly the seven fields from the spec', () {
    expect(params.toJson().keys, [
      'appId',
      'pushToken',
      'userAgent',
      'deviceID',
      'adId',
      'oneLink',
      'naming',
      'referer',
    ]);
  });

  test('every value is a flat string, naming included', () {
    final decoded = jsonDecode(jsonEncode(params.toJson())) as Map;
    expect(decoded.values.every((value) => value is String), isTrue);
    // The attribution payload travels as an escaped string, not a nested
    // object, so the server reads one type for every field.
    expect(decoded['naming'], isA<String>());
    expect(
      jsonDecode(decoded['naming'] as String),
      containsPair('network', 'TestLink'),
    );
  });

  test('oneLink and naming are mutually exclusive', () {
    expect(params.oneLink.isEmpty && params.naming.isNotEmpty, isTrue);
  });
}
