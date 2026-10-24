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
    final accent = Theme.of(context).colorScheme.primary;
    final logoUrl = notice.reminder.logoUrl;
    final hasLogo = logoUrl?.isNotEmpty == true;
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: const Color(0xFA15171C),
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: accent.withValues(alpha: 0.55)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                if (hasLogo)
                  Positioned(
                    top: -24,
                    bottom: -24,
                    right: -12,
                    width: 160,
                    child: IgnorePointer(
                        child: ExcludeSemantics(
                            child: Opacity(
                      opacity: 0.28,
                      child: Image.network(logoUrl!,
                          key: const ValueKey('reminder-watermark'),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    ))),
                  ),
                Positioned.fill(
                    child: IgnorePointer(
                        child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.12),
                      Colors.transparent
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )),
                ))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 10, 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Icon(Icons.notifications_active, size: 15, color: accent),
                      const SizedBox(width: 7),
                      Expanded(
                          child: Text(tr('My Teams'),
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700))),
                      ExcludeFocus(
                          child: Semantics(
                        label: tr('Close'),
                        button: true,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                              width: 32, height: 32),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close,
                              color: Colors.white70, size: 19),
                          onPressed: _showNext,
                        ),
                      )),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      ExcludeSemantics(
                          child: SizedBox(
                        width: 64,
                        height: 64,
                        child: hasLogo
                            ? Image.network(logoUrl!,
                                key: const ValueKey('reminder-crest'),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.sports, color: accent, size: 38))
                            : Icon(Icons.sports, color: accent, size: 38),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              tr('Your team: {home} vs {away}', {
                                'home': notice.reminder.home,
                                'away': notice.reminder.away,
                              }),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 9),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xE615171C),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                                notice.atStart
                                    ? tr('Is about to start')
                                    : tr('Starts in 15 minutes'),
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      )),
                    ]),
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
