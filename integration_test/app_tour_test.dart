import 'package:eggbound_rush/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Walks the app the way a reviewer would: start-up, onboarding, adding a
/// hen, logging her eggs, then every section reachable from the orbit menu.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 120));
    for (var i = 0; i < seconds * 8; i++) {
      await tester.pump(const Duration(milliseconds: 125));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 120));
  }

  Future<void> shoot(String name) => binding.takeScreenshot(name);

  Future<void> openOrbit(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.apps_rounded));
    await settle(tester, 1);
    await tester.tap(find.text(label));
    await settle(tester, 2);
  }

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await settle(tester, 1);
  }

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EggboundRushApp()));
    await settle(tester, 8);
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await settle(tester, 2);
    }
  }

  testWidgets('add a hen, log her eggs and see the totals move',
      (tester) async {
    await launch(tester);
    await shoot('01-today-first-run');

    // The first-run dashboard has to state who the app is for.
    expect(find.textContaining('back garden'), findsOneWidget);

    await tester.tap(find.text('Add your first hen'));
    await settle(tester, 2);
    await shoot('02-hen-editor');

    await tester.enterText(find.byType(TextField).first, 'Henrietta');
    await settle(tester, 1);
    await tester.tap(find.text('Add to my flock'));
    await settle(tester, 2);
    await shoot('03-today-with-hen');

    // The hero card and section headings render in small caps.
    expect(find.text('EGGS TODAY'), findsOneWidget);

    await tester.tap(find.text('Log eggs'));
    await settle(tester, 2);
    await shoot('04-log-eggs-sheet');

    await tester.tap(find.text('Henrietta').last);
    await settle(tester, 1);
    await tester.tap(find.text('Save record'));
    await settle(tester, 2);
    await shoot('05-egg-logged');

    await openOrbit(tester, 'My flock');
    await shoot('06-flock-list');
    expect(find.text('Laid today'), findsOneWidget);

    await tester.tap(find.text('Henrietta'));
    await settle(tester, 2);
    await shoot('07-hen-detail');
    expect(find.text('LAYING HISTORY'), findsOneWidget);

    await goBack(tester);
    await goBack(tester);
  });

  testWidgets('tour every section', (tester) async {
    await launch(tester);

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await settle(tester, 1);
    await shoot('08-orbit-open');
    await tester.tap(find.text('Stats'));
    await settle(tester, 2);
    await shoot('09-stats');
    await goBack(tester);

    await openOrbit(tester, 'Feed & costs');
    await shoot('10-feed');
    await goBack(tester);

    await openOrbit(tester, 'Coop layout');
    await shoot('11-coop-layout');
    await goBack(tester);

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await settle(tester, 1);
    await tester.tap(find.text('More'));
    await settle(tester, 1);
    await shoot('12-more-sheet');

    await tester.tap(find.text('Settings'));
    await settle(tester, 2);
    await shoot('13-settings');
    await goBack(tester);

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await settle(tester, 1);
    await tester.tap(find.text('More'));
    await settle(tester, 1);
    await tester.tap(find.text('Help & documents'));
    await settle(tester, 2);
    await shoot('14-help');

    await tester.tap(find.text('Privacy Policy'));
    await settle(tester, 4);
    await shoot('15-privacy-offline');
    await goBack(tester);
    await goBack(tester);

    await shoot('16-back-on-today');
  });
}
