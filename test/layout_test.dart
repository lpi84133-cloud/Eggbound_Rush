import 'package:eggbound_rush/core/theme/app_theme.dart';
import 'package:eggbound_rush/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sizes that have historically broken this app's layouts: a short phone, a
/// tall phone, a landscape phone and a tablet. A RenderFlex overflow throws
/// during paint, so simply rendering at each size is the assertion.
const _sizes = <String, Size>{
  'compact phone': Size(320, 568),
  'tall phone': Size(402, 874),
  'landscape phone': Size(874, 402),
  'tablet': Size(1024, 768),
};

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget child, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('onboarding fits', () {
    for (final entry in _sizes.entries) {
      testWidgets('on a ${entry.key}', (tester) async {
        await _pumpAt(
          tester,
          entry.value,
          OnboardingScreen(onFinished: () async {}),
        );
        expect(tester.takeException(), isNull);
      });
    }

    // The overflow the keeper reported appeared only once the system text
    // size was turned up, so the largest supported scale is covered too.
    testWidgets('at the largest supported text size', (tester) async {
      await _pumpAt(
        tester,
        const Size(402, 874),
        OnboardingScreen(onFinished: () async {}),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
