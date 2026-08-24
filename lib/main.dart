import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/attribution/attribution_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  // Fire-and-forget: attribution runs after the first frame and never blocks
  // or delays the app start-up sequence.
  unawaited(AttributionService.start());
  runApp(const ProviderScope(child: EggboundRushApp()));
}
