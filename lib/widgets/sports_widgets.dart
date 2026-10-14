import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/sports.dart';

// Pieces shared by the Sports screen and its Standings screen.

Color? sportsTeamColor(String? hex) {
  if (hex == null || hex.length != 6) return null;
  final v = int.tryParse(hex, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// Team or league logo in a soft disc; initials on the team colour when
/// there's no logo (or it fails to load).
class SportsLogo extends StatelessWidget {
  const SportsLogo(
      {super.key,
      required this.url,
      required this.size,
      this.fallback,
      this.color});
  final String? url;
  final double size;
  final String? fallback;
  final String? color;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final px = (size * dpr).round();
    final fetchPx = px < 64 ? 64 : (px > 200 ? 200 : px);
    final src = sportsLogoUrl(url, size: fetchPx);
    final darkSrc = sportsLogoUrl(sportsDarkLogoUrl(url), size: fetchPx);
    final initials = Center(
      child: Text(
        (fallback ?? '').length > 3
            ? fallback!.substring(0, 3)
            : (fallback ?? ''),
        style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.32),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: sportsTeamColor(color)
                ?.withValues(alpha: src == null ? 0.9 : 0.0) ??
            const Color(0xFF2A2A30),
        gradient: src == null
            ? null
            : const RadialGradient(
                colors: [Color(0xFF46464F), Color(0xFF2B2B32)]),
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: src == null
          ? initials
          : CachedNetworkImage(
              // Dark-background variant first, the original if there's none.
              imageUrl: darkSrc ?? src,
              fit: BoxFit.contain,
              memCacheWidth: px,
              fadeInDuration: const Duration(milliseconds: 200),
              errorWidget: (_, __, ___) => darkSrc == null
                  ? initials
                  : CachedNetworkImage(
                      imageUrl: src,
                      fit: BoxFit.contain,
                      memCacheWidth: px,
                      errorWidget: (_, __, ___) => initials,
                    ),
            ),
    );
  }
}

/// The app-wide focus look (`_SelectableRow`, `TvMenuTile`): a dark ->
/// accent -> dark diagonal sheen. A flat `scheme.primary` / white-alpha fill
/// reads pastel on Dark/Gold — reported again on the Sports chips.
LinearGradient sportsFocusSheen(ColorScheme scheme) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.black,
        Color.lerp(Colors.black, scheme.primaryContainer, 0.4)!,
        Colors.black,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

/// Pill used for league/day/option rows. Same language as `_SelectableRow`:
/// focused = sheen + thick accent contour + glow, selected = accent text +
/// faint contour (kept clearly quieter than focus — on the TV the two read
/// alike), idle = faint fill.
class SportsChip extends StatefulWidget {
  const SportsChip({
    super.key,
    required this.focusNode,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onFocus,
    this.logoUrl,
    this.icon,
    this.compact = false,
    this.moving = false,
    this.enabled = true,
  });

  final FocusNode focusNode;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final String? logoUrl;
  final IconData? icon;
  final bool compact;

  /// "Move" mode (league reorder): arrows either side of the label.
  final bool moving;

  /// False = dimmed and skipped by the D-pad (e.g. the other league chips
  /// while one is being moved).
  final bool enabled;

  @override
  State<SportsChip> createState() => _SportsChipState();
}

class _SportsChipState extends State<SportsChip> {
  // Seeded from the node, and re-read when the node changes: a state that
  // inherits another node never gets the focus-lost callback, which left
  // stale "focused" outlines behind.
  late bool _focused = widget.focusNode.hasFocus;

  @override
  void didUpdateWidget(SportsChip old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      _focused = widget.focusNode.hasFocus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = (_focused || widget.selected) ? scheme.primary : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1 : 0.35,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          focusNode: widget.focusNode,
          canRequestFocus: widget.enabled,
          borderRadius: BorderRadius.circular(22),
          onTap: widget.enabled ? widget.onTap : null,
          onFocusChange: (f) {
            setState(() => _focused = f);
            if (f) widget.onFocus();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 14 : 12, vertical: 4),
            decoration: BoxDecoration(
              color: _focused
                  ? null
                  : (widget.selected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.07)),
              gradient: _focused ? sportsFocusSheen(scheme) : null,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _focused
                    ? scheme.primary
                    : (widget.selected
                        ? scheme.primary.withValues(alpha: 0.4)
                        : Colors.transparent),
                width: _focused ? 2.5 : 1,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 10)
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.moving)
                  Icon(Icons.chevron_left, size: 20, color: fg),
                if (widget.logoUrl != null) ...[
                  SportsLogo(url: widget.logoUrl, size: 24),
                  const SizedBox(width: 6),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(widget.label,
                    style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w500)),
                if (widget.moving)
                  Icon(Icons.chevron_right, size: 20, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
