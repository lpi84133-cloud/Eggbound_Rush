import 'package:connectivity_plus/connectivity_plus.dart';

class GrayConnectivity {
  const GrayConnectivity();

  /// True when the device reports at least one network interface.
  /// A failed POST is still treated as "request unsuccessful" later.
  Future<bool> hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty) return false;
      return results.any((result) => result != ConnectivityResult.none);
    } on Object {
      return false;
    }
  }
}
