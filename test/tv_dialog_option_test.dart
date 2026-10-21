import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/tv_dialog_option.dart';

/// A hold-OK menu opens with its first row focused while OK is still held:
/// the hold's repeats and key-up must not press that row (owner,
/// 2026-10-21: the channel menu removed the channel from Favourites at once).
void main() {
  testWidgets('held OK repeats do not press the focused row', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SimpleDialog(children: [
          TvDialogOption(
            autofocus: true,
            onPressed: () => pressed++,
            child: const Text('Remove from Favourites'),
          ),
          TvDialogOption(onPressed: () {}, child: const Text('Hide')),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    // The tail of the hold that opened the menu.
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(pressed, 0);

    // A fresh press picks it.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });
}
