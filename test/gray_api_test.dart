import 'package:eggbound_rush/gray/gray_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty body blocks the user', () {
    expect(GrayApi.parseResponse('').outcome, GrayApiOutcome.block);
    expect(GrayApi.parseResponse('{}').outcome, GrayApiOutcome.block);
    expect(GrayApi.parseResponse('{"url":""}').outcome, GrayApiOutcome.block);
  });

  test('url field opens webview', () {
    final result = GrayApi.parseResponse('{"url":"https://example.com/app"}');
    expect(result.outcome, GrayApiOutcome.webview);
    expect(result.url, 'https://example.com/app');
  });

  test('nested data.url is accepted', () {
    final result = GrayApi.parseResponse(
      '{"data":{"url":"https://example.com/nested"}}',
    );
    expect(result.outcome, GrayApiOutcome.webview);
    expect(result.url, 'https://example.com/nested');
  });

  test('raw url string is accepted', () {
    final result = GrayApi.parseResponse('https://example.com/raw');
    expect(result.outcome, GrayApiOutcome.webview);
    expect(result.url, 'https://example.com/raw');
  });

  test('error payload retries instead of blocking for good', () {
    expect(
      GrayApi.parseResponse('{"error":"iOS App \'com.example.app\' not found"}')
          .outcome,
      GrayApiOutcome.failed,
    );
  });

  test('non-json body retries instead of blocking for good', () {
    expect(
      GrayApi.parseResponse('<!DOCTYPE html><html>Error</html>').outcome,
      GrayApiOutcome.failed,
    );
  });

  test('bare json string is accepted and escaped for WKWebView', () {
    // Shape the API actually returns: a quoted URL whose sub_id_1 carries the
    // Adjust attribution JSON unencoded.
    final result = GrayApi.parseResponse(
      '"https://banda-soft.space/webview/?push=token%3AAPA91b'
      '&sub_id_1={\\"network\\":\\"TestLink\\"}"',
    );
    expect(result.outcome, GrayApiOutcome.webview);
    expect(result.url, contains('sub_id_1=%7B%22network%22:%22TestLink%22%7D'));
    // An escape that was already correct must survive untouched.
    expect(result.url, contains('push=token%3AAPA91b'));
    expect(result.url, isNot(contains('%253A')));
  });

  test('normalising a plain url changes nothing', () {
    expect(
      GrayApi.normalizeUrl('https://example.com/app?a=1&b=2'),
      'https://example.com/app?a=1&b=2',
    );
  });

  test('url wins over an accompanying message', () {
    final result = GrayApi.parseResponse(
      '{"message":"ok","url":"https://example.com/app"}',
    );
    expect(result.outcome, GrayApiOutcome.webview);
    expect(result.url, 'https://example.com/app');
  });
}
