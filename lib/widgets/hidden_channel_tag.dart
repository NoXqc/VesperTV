import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// A small muted "Hidden" tag: a Sports Trak channel that comes from a
/// group the viewer hid (Settings > Sports Trak > Find games in hidden
/// groups; owner, 2026-11-25: "a small hidden channel tag"). Game menu,
/// Pick the channel, the player's This game and Multiview's chooser.
class HiddenChannelTag extends StatelessWidget {
  const HiddenChannelTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white38),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_off_outlined,
                size: 12, color: Colors.white60),
            const SizedBox(width: 4),
            Text(tr('Hidden'),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );
}
