import 'package:flutter/material.dart';

/// Hold OK on a live group > Colour… (owner, 2026-11-25): a group can wear
/// one of these colours in the groups column, as its outline and name
/// while the remote is elsewhere; the focused / open group keeps the usual
/// highlight. Ids are what is saved (`AppConstants.keyGroupColors`), so a
/// shade can change here without touching anyone's choice; never rename
/// one. All are bright enough to read on the dark columns of every palette.
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
