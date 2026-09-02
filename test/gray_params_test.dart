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

  test('naming is a nested object, not an escaped string', () {
    final decoded = jsonDecode(jsonEncode(params.toJson())) as Map;
    expect(decoded['naming'], isA<Map>());
    expect(decoded['naming'], containsPair('network', 'TestLink'));
    expect(decoded['naming'], containsPair('campaign', 'attributionName001'));
    expect(
      jsonEncode(params.toJson()),
      isNot(contains(r'\"network\"')),
    );
  });

  test('empty naming serialises as an empty object', () {
    const empty = GrayParams(
      appId: 'app',
      pushToken: '',
      userAgent: '',
      deviceID: '',
      adId: '',
      oneLink: 'https://example.go.link',
      naming: '',
      referer: '',
    );
    expect(empty.toJson()['naming'], isA<Map>());
    expect(empty.toJson()['naming'], isEmpty);
  });

  test('oneLink and naming are mutually exclusive', () {
    expect(params.oneLink.isEmpty && params.naming.isNotEmpty, isTrue);
  });
}
