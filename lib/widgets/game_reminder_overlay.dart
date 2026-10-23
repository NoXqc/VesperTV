import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/game_reminders.dart';
import '../services/viewer_profile_service.dart';

/// Above the root Navigator, including fullscreen players and dialogs.
/// Never requests focus or changes the currently playing stream.
class GameReminderOverlay extends StatefulWidget {
  const GameReminderOverlay({super.key});
  @override
  State<GameReminderOverlay> createState() => _GameReminderOverlayState();
}

class _GameReminderOverlayState extends State<GameReminderOverlay>
    with WidgetsBindingObserver {
  GameReminders? _reminders;
  final _queue = <GameReminderNotice>[];
  GameReminderNotice? _notice;
  Timer? _alarm;
  Timer? _hide;
  Timer? _scheduleRefresh;
  String? _viewer;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<GameReminders>();
    final serviceChanged = _reminders != service;
    if (serviceChanged) {
      _reminders?.removeListener(_refresh);
      _reminders = service;
      service.addListener(_refresh);
    }
    final viewer = context.watch<ViewerProfileService>().active.id;
    if (_viewer != viewer || serviceChanged) {
      _viewer = viewer;
      _alarm?.cancel();
      _hide?.cancel();
      _queue.clear();
      _notice = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  void _refresh() {
    _scheduleRefresh?.cancel();
    _alarm?.cancel();
    if (!mounted || !_active) return;
    final service = _reminders!;
    service.loadViewer();
    if (service.viewerId != _viewer) return;
    if (service.hasTeamReminders) {
      unawaited(service.refreshSchedules());
      final delay = service.nextScheduleRefresh.difference(service.now());
      _scheduleRefresh =
          Timer(delay.isNegative ? Duration.zero : delay, _refresh);
    }
    _queue.addAll(service.poll());
    if ((_notice == null && _queue.isNotEmpty) ||
        (_notice != null && !service.isCurrent(_notice!.reminder))) {
      _showNext();
    }
    final deadline = service.nextDeadline;
    if (deadline != null) {
      final delay = deadline.difference(service.now());
      _alarm = Timer(delay.isNegative ? Duration.zero : delay, _refresh);
    }
  }

  void _showNext() {
    _hide?.cancel();
    GameReminderNotice? next;
    while (_queue.isNotEmpty) {
      final candidate = _queue.removeAt(0);
      if (_reminders!.isCurrent(candidate.reminder) &&
          candidate.validAt(_reminders!.now())) {
        next = candidate;
        break;
      }
    }
    setState(() => _notice = next);
    if (next != null) _hide = Timer(const Duration(seconds: 12), _showNext);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _alarm?.cancel();
    _hide?.cancel();
    _scheduleRefresh?.cancel();
    _queue.clear();
    setState(() => _notice = null);
    if (_active) _refresh();
  }

  @override
  void dispose() {
    _alarm?.cancel();
    _hide?.cancel();
    _scheduleRefresh?.cancel();
    _reminders?.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    if (notice == null || _reminders?.viewerId != _viewer) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              color: const Color(0xF21A1A1A),
              elevation: 12,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                if (notice.reminder.logoUrl?.isNotEmpty == true)
                  Positioned.fill(
                      child: IgnorePointer(
                          child: ExcludeSemantics(
                              child: Opacity(
                    opacity: 0.14,
                    child: Image.network(notice.reminder.logoUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  )))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                  child: Row(children: [
                    Icon(Icons.notifications_active,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              tr('Your team: {home} vs {away}', {
                                'home': notice.reminder.home,
                                'away': notice.reminder.away
                              }),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                              notice.atStart
                                  ? tr('Is about to start')
                                  : tr('Starts in 15 minutes'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ])),
                    ExcludeFocus(
                        child: Semantics(
                            label: tr('Close'),
                            button: true,
                            child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _showNext))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
