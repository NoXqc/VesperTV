import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../services/programme_reminders.dart';
import '../services/recording_service.dart';
import '../utils/time_format.dart';
import 'glass_menu.dart';
import 'hold_to_activate.dart';
import 'tv_dialog_option.dart';
import 'tv_menu_tile.dart';

/// [upcoming]: the channel's programmes to come (`EpgService
/// .upcomingPrograms`), for Record series; null hides it.
Future<void> showProgrammeActions(
  BuildContext context, {
  required Channel channel,
  required EpgProgram programme,
  required ProgrammeReminders reminders,
  required RecordingService recordings,
  int maxConnections = 1,
  Future<List<EpgProgram>> Function()? upcoming,
}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _ProgrammeActions(
            channel: channel,
            programme: programme,
            reminders: reminders,
            recordings: recordings,
            maxConnections: maxConnections,
            upcoming: upcoming));

/// Schedules one show to come; returns what to tell the viewer (also when
/// it couldn't: no free connection, no storage).
Future<String> recordUpcomingProgramme(
    RecordingService recordings, Channel channel, EpgProgram programme,
    {int maxConnections = 1}) async {
  final conflict =
      recordings.programmeConflict(channel, programme, maxConnections);
  if (conflict != null) {
    return tr('Overlaps {title}. Your playlist has no free recording connection.',
        {'title': conflict.title});
  }
  try {
    await recordings.askNotifications();
    if (!await recordings.hasRoom()) throw StateError('No recording storage');
    await recordings.recordProgramme(channel, programme,
        maxConnections: maxConnections);
  } catch (_) {
    return tr(
        'Could not schedule recording. Check recording storage and try again.');
  }
  return recordings.exactSchedule
      ? tr('{title} will be recorded', {'title': programme.title})
      : tr(
          'Recording scheduled. Android may delay the start without exact alarm access.');
}

/// Record series: every airing (false) or skipping repeats (true); null =
/// the viewer backed out.
Future<bool?> showSeriesChoice(BuildContext context,
    {required String title, required String channelName}) {
  Widget twoLines(String title, String detail) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 2),
          Text(detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: Colors.white60)),
        ],
      );
  return showGlassMenu<bool>(
    context: context,
    builder: (context) => GlassMenuDialog(
      maxWidth: 420,
      title: Text(tr('Record series'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      children: [
        TvDialogOption(
          key: const ValueKey('series-every'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: twoLines(
              tr('Every airing'),
              tr('Every showing of {title} on {channel}',
                  {'title': title, 'channel': channelName})),
        ),
        TvDialogOption(
          key: const ValueKey('series-skip-repeats'),
          onPressed: () => Navigator.of(context).pop(true),
          child: twoLines(tr('Skip repeats'),
              tr('Not an episode it already has (same guide description)')),
        ),
        TvDialogOption(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
      ],
    ),
  );
}

/// Record series… : asks every airing / skip repeats, then sets it. Returns
/// what to tell the viewer, null when they backed out.
Future<String?> recordSeriesFlow(BuildContext context,
    {required RecordingService recordings,
    required Future<List<EpgProgram>> Function() upcoming,
    required Channel channel,
    required EpgProgram programme,
    int maxConnections = 1}) async {
  final skipRepeats = await showSeriesChoice(context,
      title: programme.title, channelName: channel.name);
  if (skipRepeats == null) return null;
  return addSeriesRecording(recordings,
      upcoming: upcoming,
      channel: channel,
      programme: programme,
      skipRepeats: skipRepeats,
      maxConnections: maxConnections);
}

/// Sets the series (after [showSeriesChoice]); returns what to tell the
/// viewer, also when it couldn't be saved.
Future<String> addSeriesRecording(RecordingService recordings,
    {required Future<List<EpgProgram>> Function() upcoming,
    required Channel channel,
    required EpgProgram programme,
    required bool skipRepeats,
    int maxConnections = 1}) async {
  try {
    await recordings.askNotifications();
    final r = await recordings.addSeries(channel, programme, await upcoming(),
        skipRepeats: skipRepeats, maxConnections: maxConnections);
    return seriesAddedMessage(r.added, r.conflicts);
  } catch (_) {
    return tr(
        'Could not schedule recording. Check recording storage and try again.');
  }
}

String seriesAddedMessage(int added, int conflicts) => [
      added == 0
          ? tr('Series recording on. Airings are added as the guide lists them.')
          : tr('Series recording on: {count} scheduled', {'count': '$added'}),
      if (conflicts > 0)
        tr('{count} skipped (no free connection)', {'count': '$conflicts'}),
    ].join(' · ');

class _ProgrammeActions extends StatefulWidget {
  const _ProgrammeActions(
      {required this.channel,
      required this.programme,
      required this.reminders,
      required this.recordings,
      required this.maxConnections,
      this.upcoming});
  final Channel channel;
  final EpgProgram programme;
  final ProgrammeReminders reminders;
  final RecordingService recordings;
  final int maxConnections;
  final Future<List<EpgProgram>> Function()? upcoming;
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
                          final series =
                              widget.recordings.seriesFor(widget.channel, p.title);
                          final upcomingOf = widget.upcoming;
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
                                if (widget.recordings.available &&
                                    upcomingOf != null)
                                  TvMenuTile(
                                      key: const ValueKey('programme-series'),
                                      enabled: !_busy,
                                      icon: series == null
                                          ? Icons.event_repeat
                                          : Icons.event_busy,
                                      title: series == null
                                          ? tr('Record series…')
                                          : tr('Stop series recording'),
                                      subtitle: series == null
                                          ? tr('Every showing of {title} on this channel',
                                              {'title': p.title})
                                          : tr('Recordings made stay.'),
                                      onTap: () async {
                                        if (_busy) return;
                                        if (series != null) {
                                          return _run(() async {
                                            await widget.recordings
                                                .stopSeries(series);
                                            return tr(
                                                'Series recording stopped. Recordings made stay.');
                                          }, tr('Could not schedule recording. Check recording storage and try again.'));
                                        }
                                        // The choice first: busy would take
                                        // the focus off this tile meanwhile.
                                        final skip = await showSeriesChoice(
                                            context,
                                            title: p.title,
                                            channelName: widget.channel.name);
                                        if (skip == null || !mounted) return;
                                        await _run(
                                            () => addSeriesRecording(
                                                widget.recordings,
                                                upcoming: upcomingOf,
                                                channel: widget.channel,
                                                programme: p,
                                                skipRepeats: skip,
                                                maxConnections:
                                                    widget.maxConnections),
                                            tr('Could not schedule recording. Check recording storage and try again.'));
                                      }),
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
