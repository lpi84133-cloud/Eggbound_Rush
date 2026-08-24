import '../../hatchway/infra/flight_attribution.dart';

/// Backwards-compatible façade over the paid-campaign attribution pipeline.
///
/// The whole implementation now lives in [FlightAttribution]. This class
/// stays only so pre-existing callers can keep using
/// `AttributionService.isOrganic` and `AttributionService.start()` without
/// having to know about the new gate.
class AttributionService {
  AttributionService._();

  /// Kicks off the AppsFlyer SDK exactly once. Safe to call multiple times.
  static Future<void> start() => FlightAttribution.instance.start();

  /// True for direct App Store installs, false for paid campaigns, null
  /// while classification is still pending.
  static bool? get isOrganic => FlightAttribution.instance.isOrganic;

  /// AppsFlyer UID (null while the SDK is warming up or on failure).
  static Future<String?> appsFlyerUID() =>
      FlightAttribution.instance.appsFlyerUID();
}
