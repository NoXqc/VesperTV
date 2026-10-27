import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/sports.dart';
import '../services/goals_alerts.dart';
import 'tv_menu_tile.dart';

class GameScoreAlertMenuTile extends StatelessWidget {
  const GameScoreAlertMenuTile({super.key, required this.game});
  final SportsGame game;

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<GoalsAlerts>();
    final enabled = alerts.isSet(game);
    if (!enabled && !alerts.canSet(game)) return const SizedBox.shrink();
    return TvMenuTile(
      icon: enabled ? Icons.notifications_off_outlined : Icons.sports_score,
      title: tr(enabled
          ? 'Remove goals alert for this match'
          : 'Set goals alert for this match'),
      subtitle: tr(
          'Notify me when either team scores (while VesperTV is open). Hide scores pauses alerts.'),
      onTap: () async {
        try {
          await alerts.setGame(game, !enabled);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Could not save score alert.'))));
          }
        }
      },
    );
  }
}
