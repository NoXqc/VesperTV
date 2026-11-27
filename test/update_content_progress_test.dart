import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/catalog_sync_screen.dart';

/// LOG-5L9ZYS (Mac 1.0.73, 2026-11-27): Back closed Update Content's
/// progress page while the update ran on; when it ended, `pop()` took the
/// home off instead and left a black window until a restart.
void main() {
  final navKey = GlobalKey<NavigatorState>();

  Future<void> pumpHome(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('home')),
      ));

  Widget progress(BuildContext _) =>
      const Scaffold(backgroundColor: Colors.black, body: Text('updating'));

  testWidgets('closed early with Back: the home stays when it ends',
      (tester) async {
    await pumpHome(tester);
    final work = Completer<void>();
    final done =
        runBehindProgressPage(navKey.currentState!, work.future, progress);
    await tester.pumpAndSettle();
    expect(find.text('updating'), findsOneWidget);

    navKey.currentState!.pop(); // Back / Esc / back swipe
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    work.complete();
    await done;
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget, reason: 'not popped away');
    expect(navKey.currentState!.canPop(), isFalse);
  });

  testWidgets('left open: closes when the update ends', (tester) async {
    await pumpHome(tester);
    final work = Completer<int>();
    final done =
        runBehindProgressPage(navKey.currentState!, work.future, progress);
    await tester.pumpAndSettle();
    work.complete(7);
    expect(await done, 7);
    await tester.pumpAndSettle();
    expect(find.text('updating'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('another page over it: only the progress page goes',
      (tester) async {
    await pumpHome(tester);
    final work = Completer<void>();
    final done =
        runBehindProgressPage(navKey.currentState!, work.future, progress);
    await tester.pumpAndSettle();
    unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('reminder')))));
    await tester.pumpAndSettle();
    work.complete();
    await done;
    await tester.pumpAndSettle();
    expect(find.text('reminder'), findsOneWidget);
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('updating'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a failed update still closes the page', (tester) async {
    await pumpHome(tester);
    final work = Completer<void>();
    final done =
        runBehindProgressPage(navKey.currentState!, work.future, progress);
    await tester.pumpAndSettle();
    work.completeError(StateError('server down'));
    await expectLater(done, throwsStateError);
    await tester.pumpAndSettle();
    expect(find.text('updating'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
