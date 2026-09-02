import 'dart:convert';

/// Body of the routing POST, field names match the spec exactly.
class GrayParams {
  const GrayParams({
    required this.appId,
    required this.pushToken,
    required this.userAgent,
    required this.deviceID,
    required this.adId,
    required this.oneLink,
    required this.naming,
    required this.referer,
  });

  /// Bundle identifier.
  final String appId;

  /// Firebase Cloud Messaging token.
  final String pushToken;

  /// WKWebView / system user agent.
  final String userAgent;

  /// Adjust ADID.
  final String deviceID;

  /// IDFV (`identifierForVendor`).
  final String adId;

  /// Adjust deep link / universal link, only if it arrived first.
  final String oneLink;

  /// Adjust attribution JSON, only if attribution arrived first.
  /// Stored as the raw payload string; [toJson] sends it as an object.
  final String naming;

  /// Apple Search Ads `attributionToken`.
  final String referer;

  Map<String, Object> toJson() => {
    'appId': appId,
    'pushToken': pushToken,
    'userAgent': userAgent,
    'deviceID': deviceID,
    'adId': adId,
    'oneLink': oneLink,
    'naming': namingAsJson(),
    'referer': referer,
  };

  /// The attribution object the API expects. An empty or unreadable payload
  /// becomes `{}` so the field is always a JSON object, never a string.
  Object namingAsJson() {
    final trimmed = naming.trim();
    if (trimmed.isEmpty) return const <String, Object?>{};
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } on Object {
      // Fall through to an empty object: a string here is exactly the
      // shape the server asked us not to send.
    }
    return const <String, Object?>{};
  }
}
