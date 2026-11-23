import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/top_notice_overlay.dart';

/// The player's Sources / Tuliprox messages roll down from the top instead
/// of a snackbar over the player bar and Sources (owner, 2026-11-23).
void main() {
  testWidgets('rolls down from the top, leaves focus alone, then goes',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        Focus(focusNode: focus, autofocus: true, child: const SizedBox()),
        const TopNoticeOverlay(),
      ]),
    ));
    expect(find.byKey(const ValueKey('top-notice')), findsNothing);

    TopNotice.show('Source changed to UK| SKY SPORTS F1 FHD.',
        duration: const Duration(seconds: 2));
    await tester.pump(); // built above the screen
    await tester.pump(); // starts sliding down
    await tester.pump(const Duration(milliseconds: 300));
    final card = find.byKey(const ValueKey('top-notice'));
    expect(card, findsOneWidget);
    expect(
        find.text('Source changed to UK| SKY SPORTS F1 FHD.'), findsOneWidget);
    // At the top of the screen, never where the player bar is.
    expect(tester.getTopLeft(card).dy, lessThan(100));
    expect(focus.hasFocus, isTrue);

    // A newer message replaces it.
    TopNotice.show('That source is already on the list.',
        duration: const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('That source is already on the list.'), findsOneWidget);

    // Rolls back up and leaves the tree.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const ValueKey('top-notice')), findsNothing);
  });
}
