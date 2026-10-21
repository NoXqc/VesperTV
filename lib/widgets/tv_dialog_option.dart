import 'package:flutter/material.dart';

import 'hold_to_activate.dart';

/// A [SimpleDialogOption] with a visible D-pad selector. The plain one
/// draws no focus highlight on the TV theme, so a hold-OK menu showed no
/// sign of which row OK would pick (owner, 2026-10-21, using the TV's own
/// remote). Same API: [onPressed] + [child].
///
/// Each row sits in a [SwallowHeldActivate]: these menus open on a held OK,
/// and with a row focused at once the hold's key repeats pressed it
/// ("Remove from Favourites" the moment the channel menu opened).
class TvDialogOption extends StatefulWidget {
  const TvDialogOption({
    super.key,
    this.onPressed,
    this.child,
    this.autofocus = false,
    this.padding,
  });

  final VoidCallback? onPressed;
  final Widget? child;
  final bool autofocus;
  final EdgeInsetsGeometry? padding;

  @override
  State<TvDialogOption> createState() => _TvDialogOptionState();
}

class _TvDialogOptionState extends State<TvDialogOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: SwallowHeldActivate(
          child: InkWell(
        autofocus: widget.autofocus,
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(10),
        onFocusChange: (f) => setState(() => _focused = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding ??
              const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: _focused ? scheme.primary.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontWeight: _focused ? FontWeight.w700 : null,
            ),
            child: widget.child ?? const SizedBox.shrink(),
          ),
        ),
      )),
    );
  }
}
