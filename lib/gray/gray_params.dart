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
  final String naming;

  /// Apple Search Ads `attributionToken`.
  final String referer;

  Map<String, String> toJson() => {
    'appId': appId,
    'pushToken': pushToken,
    'userAgent': userAgent,
    'deviceID': deviceID,
    'adId': adId,
    'oneLink': oneLink,
    'naming': naming,
    'referer': referer,
  };
}
