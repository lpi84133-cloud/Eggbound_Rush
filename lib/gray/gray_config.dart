/// Values the gray routing layer needs from you. Everything marked
/// `YOUR_…` is a stub so the app still boots; replace them to go live.
abstract final class GrayConfig {
  /// POST endpoint that returns `{ "url": "…" }` for the WebView.
  static const apiUrl = 'https://domainappteol.xyz/api/click-ios';

  static const apiTimeout = Duration(seconds: 15);

  /// How long we wait for the first of: Adjust deep link or attribution.
  static const adjustSignalTimeout = Duration(seconds: 25);

  static const adjustAppToken = 'wu5j1le1337k';

  /// Custom URL scheme used for Adjust / app deep links.
  static const urlScheme = 'eggboundrush';

  /// Apple Pay merchant id (also goes into Runner.entitlements).
  static const applePayMerchantId = 'merchant.YOUR_MERCHANT_ID';

  static const firebaseConfigured = true;

  static bool get adjustConfigured =>
      adjustAppToken.isNotEmpty && !adjustAppToken.startsWith('YOUR_');

  static bool get apiConfigured =>
      apiUrl.isNotEmpty && !apiUrl.contains('github.com/PatricksCooper');
}
