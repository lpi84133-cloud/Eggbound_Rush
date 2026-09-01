import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gray/gray_adjust.dart';
import 'gray/gray_device.dart';
import 'gray/gray_push.dart';
import 'gray/gray_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GrayPush.configure();
  GrayDevice.listenForDeeplinks();
  GrayPush.installBackgroundHandler();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  unawaited(GrayAdjust.start());
  runApp(const ProviderScope(child: AppEntry()));
}
