// ignore_for_file: prefer_initializing_formals
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

import '../config/era_hatch_config.dart';
import '../models/hatch_reply.dart';
import 'flight_attribution.dart';
import 'roost_agent.dart';

/// Builds and posts the config-endpoint request that decides whether this
/// install sees the partner content shell or stays on the native game.
class HatchExchange {
  HatchExchange({
    required RoostAgent agent,
    required FlightAttribution attribution,
  })  : _agent = agent,
        _attribution = attribution;

  final RoostAgent _agent;
  final FlightAttribution _attribution;

  Future<HatchReply> resolve({
    required String? pushToken,
    String? locale,
  }) async {
    if (!EraHatchConfig.grayCredentialsReady) return HatchReply.denied;

    final attribution = await _attribution.awaitConversion();
    final afId = await _attribution.appsFlyerUID();
    final idfa = await _readIdfaIfAllowed();

    final body = _buildBody(
      attribution: attribution,
      afId: afId,
      idfa: idfa,
      pushToken: pushToken,
      locale: locale,
    );

    _log('POST ${EraHatchConfig.configEndpoint} body_keys=${body.keys.toList()}');
    final response = await _agent.postJson(
      uri: Uri.parse(EraHatchConfig.configEndpoint),
      body: body,
    );
    if (response == null) return HatchReply.denied;

    final reply = HatchReply.fromJson(response);
    _log('response granted=${reply.granted} url=${reply.destination ?? '—'}');
    return reply;
  }

  /// Returns the raw advertising identifier (IDFA on iOS) only when the
  /// user has explicitly granted tracking access. `sub_id_10` follows the
  /// same rule everywhere in the backend contract.
  Future<String?> _readIdfaIfAllowed() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.authorized) return null;
      final id = await AppTrackingTransparency.getAdvertisingIdentifier();
      if (id.isEmpty) return null;
      if (id == '00000000-0000-0000-0000-000000000000') return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildBody({
    required Map<String, dynamic> attribution,
    required String? afId,
    required String? idfa,
    required String? pushToken,
    required String? locale,
  }) {
    // Merge order per gray_flow_guide §"Config Request Contract":
    //   1) full AppsFlyer conversion payload (verbatim, no filtering)
    //   2) device-side fields (overwrite on collision)
    final body = <String, dynamic>{
      ...attribution,
      'bundle_id': EraHatchConfig.bundleId,
      'os': 'iOS',
      'store_id': EraHatchConfig.platformStoreId,
      'locale': locale ?? Platform.localeName,
    };
    if (afId != null && afId.isNotEmpty) {
      // Device-side override wins even if AppsFlyer already delivered the
      // key — the SDK sometimes stamps a placeholder before the real UID
      // resolves.
      body['af_id'] = afId;
    }
    if (idfa != null && idfa.isNotEmpty) body['sub_id_10'] = idfa;
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = EraHatchConfig.firebaseProjectNumber;
    }
    // Never send explicit nulls / empty strings for optional identifiers —
    // the partner backend treats them as "field is present, value is
    // invalid" and drops the install from the attribution pool.
    body.removeWhere((_, value) => value == null || value == '');
    return body;
  }

  void _log(String message) {
    assert(() { debugPrint('[EBR.exchange] $message'); return true; }());
  }
}
