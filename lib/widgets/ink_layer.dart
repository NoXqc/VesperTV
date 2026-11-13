import 'package:flutter/material.dart';

/// A focusable card or row on its own layer, with its own Material.
/// InkWell / ListTile paint their focus highlight on the nearest Material
/// ancestor, often a whole page or panel, so every remote step repainted all
/// of it for the highlight's fade; on a weak box that is a slow frame or
/// several per press (frame cost audit, 2026-11-13; CLAUDE.md §10). Always
/// present, so the focusable child keeps its slot (and its FocusNode).
class InkLayer extends StatelessWidget {
  const InkLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: Material(type: MaterialType.transparency, child: child));
}
