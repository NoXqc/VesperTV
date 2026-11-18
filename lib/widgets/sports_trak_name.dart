import 'package:flutter/material.dart';

/// "Sports" with a small gold "Trak" sitting high after it, like the
/// superscript tags in channel names (Prime ᴿᴬᵂ). The TV home tab: as two
/// words it wrapped onto two lines (owner, 2026-11-17).
///
/// "Sports" takes [style] (focus colour, weight, size); "Trak" is always the
/// brand gold, whatever the palette. One line, shrunk to fit if it must.
class SportsTrakName extends StatelessWidget {
  const SportsTrakName({super.key, required this.style});

  final TextStyle style;

  /// VesperTV's brand gold (the Platinum palette's accent, the wordmark).
  static const gold = Color(0xFFF0C75E);

  @override
  Widget build(BuildContext context) {
    final size = DefaultTextStyle.of(context).style.merge(style).fontSize ?? 14;
    final small = size * 0.58;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Sports', style: style),
          // Bottom on the baseline, then raised so its letters line up with
          // the top of "Sports"; the raise isn't layout, so the row keeps
          // its height.
          WidgetSpan(
            alignment: PlaceholderAlignment.aboveBaseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.translate(
              offset: Offset(size * 0.06, -size * 0.3),
              child: Text(
                'Trak',
                style: style.copyWith(
                  fontSize: small,
                  height: 1,
                  color: gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ]),
        maxLines: 1,
        softWrap: false,
        semanticsLabel: 'Sports Trak',
      ),
    );
  }
}
