import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/sports.dart';
import '../services/game_reminders.dart';
import 'tv_menu_tile.dart';
import 'hold_to_activate.dart';

String gameReminderLeadLabel(int minutes) => switch (minutes) {
      60 => tr('1 hour before'),
      1440 => tr('1 day before'),
      10080 => tr('1 week before'),
      0 => tr('At game time only'),
      _ => tr('15 minutes before'),
    };

Future<int?> showGameReminderTimingMenu(
    BuildContext context, SportsGame game, GameReminders reminders) {
  return showDialog<int>(
      context: context,
      builder: (context) {
        final selected = reminders.leadMinutesFor(game);
        bool available(int minutes) =>
            minutes == 0 ||
            game.start
                .subtract(Duration(minutes: minutes))
                .isAfter(reminders.now());
        final focus = available(selected) ? selected : 0;
        return SwallowHeldActivate(
            child: Dialog(
          alignment: Alignment.centerRight,
          insetPadding: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 390,
                maxHeight: MediaQuery.sizeOf(context).height - 60),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                      child: Text(tr('Reminder timing'),
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: tr('Close'),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ]),
                Text(game.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Text(tr(
                    'Advance reminders also notify at game time. VesperTV must be open.')),
                const SizedBox(height: 12),
                Flexible(
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final minutes in GameReminder.supportedLeadMinutes)
                    TvMenuTile(
                      autofocus: minutes == focus,
                      enabled: available(minutes),
                      icon: minutes == selected
                          ? Icons.check_circle
                          : Icons.notifications_outlined,
                      title: gameReminderLeadLabel(minutes),
                      subtitle: available(minutes)
                          ? null
                          : tr('This reminder time has passed'),
                      onTap: () => Navigator.pop(context, minutes),
                    ),
                ]))),
              ]),
            ),
          ),
        ));
      });
}
