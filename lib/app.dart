import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'hatchway/pages/hatch_gate.dart';

class EggboundRushApp extends StatelessWidget {
  const EggboundRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eggbound Rush',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HatchGate(),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child!,
      ),
    );
  }
}
