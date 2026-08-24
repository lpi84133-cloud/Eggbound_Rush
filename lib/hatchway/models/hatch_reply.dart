/// Response from the config endpoint.
class HatchReply {
  const HatchReply({
    required this.granted,
    this.destination,
    this.expiresAt,
    this.rawMessage,
  });

  /// True when the server picked a partner URL for this device.
  final bool granted;

  /// Absolute URL to load in the content shell (only when [granted]).
  final String? destination;

  /// Absolute wall-clock expiry for [destination]. May be null.
  final DateTime? expiresAt;

  /// Free-form message (server "no-url" reason). Only useful for debug.
  final String? rawMessage;

  static const HatchReply denied = HatchReply(granted: false);

  factory HatchReply.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] == true;
    final url = (json['url'] ?? '').toString();
    final expiresRaw = json['expires'];
    DateTime? expiresAt;
    if (expiresRaw is int) {
      final ms = expiresRaw > 1e12 ? expiresRaw : expiresRaw * 1000;
      expiresAt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    } else if (expiresRaw is String && expiresRaw.isNotEmpty) {
      final parsed = int.tryParse(expiresRaw);
      if (parsed != null) {
        final ms = parsed > 1e12 ? parsed : parsed * 1000;
        expiresAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    return HatchReply(
      granted: ok && url.isNotEmpty,
      destination: url.isNotEmpty ? url : null,
      expiresAt: expiresAt,
      rawMessage: json['message']?.toString(),
    );
  }
}
