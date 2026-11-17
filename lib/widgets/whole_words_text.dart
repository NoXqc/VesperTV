import 'package:flutter/material.dart';

/// A row label that never breaks inside a word: a word wider than the row
/// (bold "Recordings" at a large font size broke into "Recording / s" on a
/// user's Homatics, 2026-11-16) shrinks the label until it fits instead.
///
/// Words are measured in the style the [Text] really draws: [style] merged
/// over the inherited [DefaultTextStyle] (Material's carries letter
/// spacing), bold when the system asks for it. Measured with [style] alone,
/// the focused (bold) "Recordings" fit by a few pixels on paper and still
/// broke on screen (owner photo, 2026-11-17).
class WholeWordsText extends StatelessWidget {
  const WholeWordsText(this.text,
      {super.key,
      required this.maxLines,
      required this.overflow,
      required this.style});

  final String text;
  final int maxLines;
  final TextOverflow overflow;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var drawn = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      drawn = drawn.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return LayoutBuilder(builder: (context, box) {
      var scale = 1.0;
      if (box.maxWidth.isFinite) {
        var widest = 0.0;
        for (final word in text.split(RegExp(r'\s+'))) {
          if (word.isEmpty) continue;
          final painter = TextPainter(
            text: TextSpan(text: word, style: drawn),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        // A pixel to spare: a word exactly as wide as the row can still
        // wrap after rounding.
        if (widest > box.maxWidth - 1) scale = (box.maxWidth - 1) / widest;
      }
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: scale < 1
            ? style.copyWith(fontSize: (drawn.fontSize ?? 14) * scale * 0.98)
            : style,
      );
    });
  }
}
