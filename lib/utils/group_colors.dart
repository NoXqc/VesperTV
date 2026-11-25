import 'package:flutter/material.dart';

/// The fade a coloured group row wears ([groupColorFade]): strongest at the
/// icon, gone before the count. Fine enough that white text stays easy to
/// read on every colour.
LinearGradient groupColorFade(Color color) => LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        color.withValues(alpha: 0.42),
        color.withValues(alpha: 0.14),
        color.withValues(alpha: 0),
      ],
      stops: const [0, 0.55, 1],
    );

/// Hold OK on a live group > Colour… (owner, 2026-11-25): a group can wear
/// one of these colours in the groups column, as a fine fade behind the
/// row ([groupColorFade]; the first try was an outline + coloured name)
/// while the remote is elsewhere; the focused group keeps the usual
/// highlight. Ids are what is saved (`AppConstants.keyGroupColors`), so a
/// shade can change here without touching anyone's choice; never rename
/// one.
class GroupColor {
  const GroupColor(this.id, this.name, this.color);

  final String id;

  /// English name, shown through `tr()`.
  final String name;
  final Color color;

  static const presets = [
    GroupColor('red', 'Red', Color(0xFFFF5252)),
    GroupColor('orange', 'Orange', Color(0xFFFF9800)),
    GroupColor('yellow', 'Yellow', Color(0xFFFFD600)),
    GroupColor('green', 'Green', Color(0xFF66BB6A)),
    GroupColor('aqua', 'Aqua', Color(0xFF26C6DA)),
    GroupColor('blue', 'Blue', Color(0xFF448AFF)),
    GroupColor('purple', 'Purple', Color(0xFFB388FF)),
    GroupColor('pink', 'Pink', Color(0xFFFF4081)),
  ];

  /// The scope the viewer's own groups keep their colours under (a
  /// playlist's are under its id).
  static const ownScope = 'own';

  static GroupColor? byId(String? id) {
    if (id == null) return null;
    for (final c in presets) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The colour for a saved id; null = none (or an id this version
  /// doesn't know).
  static Color? of(String? id) => byId(id)?.color;
}

/// Settings > Appearance > Column lines (owner, 2026-11-25): the colour of
/// the lines between the TV home's columns and the guide's own. '' (or an
/// unknown id) = the theme's; 'accent' = the palette's colour; 'white';
/// else one of [GroupColor.presets].
Color? columnLineColorOf(String id, ColorScheme scheme) => switch (id) {
      '' => null,
      'accent' => scheme.primary,
      'white' => Colors.white70,
      _ => GroupColor.of(id),
    };
