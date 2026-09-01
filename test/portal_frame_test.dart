import 'package:eggbound_rush/gray/portal_webview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _frame({bool failed = false, VoidCallback? onClose}) {
  return MaterialApp(
    home: PortalFrame(
      page: const ColoredBox(color: Colors.blue),
      progress: 0.4,
      failed: failed,
      onRetry: () async {},
      canGoBack: true,
      canGoForward: false,
      onBack: () async {},
      onForward: () async {},
      onReload: () async {},
      onClose: onClose,
    ),
  );
}

void main() {
  testWidgets('insets stay black and clear of the page on a notched phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    // iPhone 15 Pro: Dynamic Island on top, home indicator at the bottom.
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_frame());

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.black,
    );

    final safeArea = tester.widget<SafeArea>(find.byType(SafeArea).first);
    expect(safeArea.top, isTrue);
    expect(safeArea.bottom, isTrue);
    expect(safeArea.left, isTrue);
    expect(safeArea.right, isTrue);

    // The page must start below the island and end above the indicator.
    final page = tester.getRect(find.byType(ColoredBox).last);
    final screen = tester.getSize(find.byType(Scaffold));
    expect(page.top, greaterThanOrEqualTo(177 / 3));
    expect(page.bottom, lessThanOrEqualTo(screen.height - 102 / 3));
  });

  testWidgets('landscape notch insets are respected', (tester) async {
    tester.view.physicalSize = const Size(2556, 1179);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(left: 177, right: 177);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_frame());

    final page = tester.getRect(find.byType(ColoredBox).last);
    expect(page.left, greaterThanOrEqualTo(177 / 3));
    expect(page.right, lessThanOrEqualTo(2556 / 3 - 177 / 3));
  });

  testWidgets('navigation bar shows arrows and reload without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(_frame());

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup windows get a close button', (tester) async {
    await tester.pumpWidget(_frame(onClose: () {}));

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('forward arrow is disabled when there is no history ahead', (
    tester,
  ) async {
    await tester.pumpWidget(_frame());

    final forward = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_forward_ios_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(forward.onPressed, isNull);
  });

  testWidgets('bar survives the largest supported text size', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _frame(onClose: () {}),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('offline overlay offers a retry', (tester) async {
    await tester.pumpWidget(_frame(failed: true));

    expect(find.text('The page could not be loaded.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
  });
}
