import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/sports.dart';
import '../services/game_reminders.dart';
import 'tv_menu_tile.dart';

class GameReminderMenuTile extends StatelessWidget {
  const GameReminderMenuTile(
      {super.key, required this.game, required this.onTap});
  final SportsGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<GameReminders>();
    final enabled = reminders.isSet(game);
    if (!enabled && !reminders.canSet(game)) return const SizedBox.shrink();
    return TvMenuTile(
      icon: enabled
          ? Icons.notifications_off_outlined
          : Icons.notifications_active_outlined,
      title: enabled ? tr('Cancel reminder') : tr('Remind me'),
      subtitle:
          tr('15 minutes before and at game time (while VesperTV is open)'),
      onTap: onTap,
    );
  }
}
