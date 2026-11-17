import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/whole_words_text.dart';

// Owner photo, 2026-11-17: the focused (bold) "Recordings" tab still broke
// into "Recording / s". The word was measured without the inherited text
// style (Material's letter spacing), so it fit on paper and not on screen.
void main() {
  // The test font draws every letter as wide as the font size: "Recordings"
  // at 20 = 200 px, + 10 x 2 px of letter spacing = 220 px.
  Future<double> drawnSize(WidgetTester tester, double rowWidth) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: rowWidth,
          child: const DefaultTextStyle(
            style: TextStyle(letterSpacing: 2),
            child: WholeWordsText('Recordings',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ));
    return tester.widget<Text>(find.text('Recordings')).style!.fontSize!;
  }

  testWidgets('a word that only fits without the inherited spacing shrinks',
      (tester) async {
    final size = await drawnSize(tester, 210);
    expect(size, lessThan(20));
    // One line: the word didn't break.
    expect(tester.getSize(find.text('Recordings')).height, lessThan(30));
  });

  testWidgets('a word that fits keeps its size', (tester) async {
    expect(await drawnSize(tester, 300), 20);
  });
}
