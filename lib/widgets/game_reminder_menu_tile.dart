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
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (enabled || reminders.canSet(game))
        TvMenuTile(
          icon: enabled
              ? Icons.notifications_off_outlined
              : Icons.notifications_active_outlined,
          title: enabled ? tr('Cancel reminder') : tr('Remind me'),
          subtitle:
              tr('15 minutes before and at game time (while VesperTV is open)'),
          onTap: onTap,
        ),
      for (final followed in reminders.followedTeams)
        if (followed.leagueId == game.league.id &&
            (followed.teamId == game.home.id ||
                followed.teamId == game.away.id))
          TvMenuTile(
            icon: reminders.teamEnabled(followed)
                ? Icons.notifications_off_outlined
                : Icons.notifications_active_outlined,
            title: tr(
                reminders.teamEnabled(followed)
                    ? 'Stop team reminders: {team}'
                    : 'Remind me for every game: {team}',
                {
                  'team':
                      (followed.teamId == game.home.id ? game.home : game.away)
                          .shortName
                }),
            subtitle: tr(
                '15 minutes before and at game time (while VesperTV is open)'),
            onTap: () async {
              try {
                await reminders.setTeam(
                    followed, !reminders.teamEnabled(followed),
                    games: [game]);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('Could not save reminder.'))));
                }
              }
            },
          ),
    ]);
  }
}
