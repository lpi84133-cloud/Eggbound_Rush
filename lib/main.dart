import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/attribution/attribution_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // Best-effort — a broken plist should never brick the game path.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    assert(() { debugPrint('[EBR.firebase] init failed: $error'); return true; }());
  }

  // Fire-and-forget: attribution runs after the first frame and never blocks
  // or delays the app start-up sequence.
  unawaited(AttributionService.start());

  runApp(const ProviderScope(child: EggboundRushApp()));
}
