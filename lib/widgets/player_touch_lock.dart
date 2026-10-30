import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Keeps the video mounted and playing while only the unlock button accepts
/// input. Wrap the player's gesture detectors, rather than placing a barrier
/// inside them: an ancestor detector can still receive absorbed child taps.
class PlayerTouchLock extends StatelessWidget {
  const PlayerTouchLock({
    super.key,
    required this.locked,
    required this.onUnlock,
    required this.child,
  });

  final bool locked;
  final VoidCallback onUnlock;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !locked,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ExcludeFocus(
                excluding: locked,
                child: AbsorbPointer(absorbing: locked, child: child),
              ),
            ),
            if (locked)
              Positioned.fill(
                child: BlockSemantics(
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Semantics(
                          label: tr('Touch controls locked'),
                          child: Material(
                            color: Colors.black87,
                            shape: const CircleBorder(
                                side: BorderSide(color: Colors.white38)),
                            child: IconButton(
                              key: const ValueKey('player-touch-unlock'),
                              tooltip: tr('Unlock touch controls'),
                              constraints: const BoxConstraints.tightFor(
                                  width: 56, height: 56),
                              icon: const Icon(Icons.lock,
                                  color: Colors.white, size: 26),
                              onPressed: onUnlock,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
