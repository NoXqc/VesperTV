import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../services/programme_reminders.dart';
import '../services/recording_service.dart';
import '../utils/time_format.dart';
import 'hold_to_activate.dart';
import 'tv_menu_tile.dart';

Future<void> showProgrammeActions(
  BuildContext context, {
  required Channel channel,
  required EpgProgram programme,
  required ProgrammeReminders reminders,
  required RecordingService recordings,
  int maxConnections = 1,
}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _ProgrammeActions(
            channel: channel,
            programme: programme,
            reminders: reminders,
            recordings: recordings,
            maxConnections: maxConnections));

class _ProgrammeActions extends StatefulWidget {
  const _ProgrammeActions(
      {required this.channel,
      required this.programme,
      required this.reminders,
      required this.recordings,
      required this.maxConnections});
  final Channel channel;
  final EpgProgram programme;
  final ProgrammeReminders reminders;
  final RecordingService recordings;
  final int maxConnections;
  @override
  State<_ProgrammeActions> createState() => _ProgrammeActionsState();
}

class _ProgrammeActionsState extends State<_ProgrammeActions> {
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<String> Function() action, String error) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await action();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SwallowHeldActivate(
        child: Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: 460,
                  maxHeight: MediaQuery.sizeOf(context).height - 40),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                    child: AnimatedBuilder(
                        animation: Listenable.merge(
                            [widget.reminders, widget.recordings]),
                        builder: (context, _) {
                          final p = widget.programme;
                          final reminded =
                              widget.reminders.isSet(widget.channel, p);
                          final entry = widget.recordings
                              .entryForProgramme(widget.channel, p);
                          final upcoming =
                              p.start.isAfter(widget.reminders.now());
                          final conflict = widget.recordings.programmeConflict(
                              widget.channel, p, widget.maxConnections);
                          return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(p.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 6),
                                Text(
                                    '${widget.channel.name} · ${TimeFormat.dayTime(p.start)} - ${TimeFormat.hm.format(p.stop)}'),
                                const SizedBox(height: 16),
                                TvMenuTile(
                                    key: const ValueKey('programme-reminder'),
                                    autofocus: true,
                                    enabled: !_busy && (upcoming || reminded),
                                    icon: reminded
                                        ? Icons.notifications_off_outlined
                                        : Icons.notifications_active_outlined,
                                    title: reminded
                                        ? tr('Cancel reminder')
                                        : tr('Remind me'),
                                    subtitle: tr(
                                        '5 minutes before and at programme time (while VesperTV is open)'),
                                    onTap: () => _run(() async {
                                          final added = await widget.reminders
                                              .toggle(widget.channel, p);
                                          return added
                                              ? tr('Reminder set')
                                              : tr('Reminder cancelled');
                                        }, tr('Could not save reminder.'))),
                                if (widget.recordings.available)
                                  TvMenuTile(
                                      key: const ValueKey('programme-record'),
                                      enabled: !_busy &&
                                          (entry != null ||
                                              upcoming && conflict == null),
                                      icon: entry == null
                                          ? Icons.fiber_manual_record
                                          : Icons.cancel_outlined,
                                      title: entry != null
                                          ? (entry.state == RecState.recording
                                              ? tr('Stop recording')
                                              : tr('Cancel recording'))
                                          : tr('Record'),
                                      subtitle: conflict != null &&
                                              entry == null
                                          ? tr(
                                              'Overlaps {title}. Your playlist has no free recording connection.',
                                              {
                                                  'title': conflict.title
                                                })
                                          : tr(
                                              'Records the programme start to end. Manage it in Recordings.'),
                                      onTap: () => _run(() async {
                                            if (entry != null) {
                                              await widget.recordings
                                                  .cancelProgramme(entry);
                                              return entry.state ==
                                                      RecState.stopped
                                                  ? tr('Recording stopped')
                                                  : tr('Recording cancelled');
                                            }
                                            await widget.recordings
                                                .askNotifications();
                                            if (!await widget.recordings
                                                .hasRoom()) {
                                              throw StateError(
                                                  'No recording storage');
                                            }
                                            await widget.recordings
                                                .recordProgramme(
                                                    widget.channel, p,
                                                    maxConnections:
                                                        widget.maxConnections);
                                            return widget
                                                    .recordings.exactSchedule
                                                ? tr('{title} will be recorded',
                                                    {'title': p.title})
                                                : tr(
                                                    'Recording scheduled. Android may delay the start without exact alarm access.');
                                          }, tr('Could not schedule recording. Check recording storage and try again.'))),
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(_error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error))),
                                TvMenuTile(
                                    icon: Icons.close,
                                    title: tr('Close'),
                                    onTap: () => Navigator.pop(context)),
                              ]);
                        })),
              )),
        ),
      );
}
