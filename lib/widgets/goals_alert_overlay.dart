import 'popup_surface.dart';
import '../utils/refined_finish.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/app_preferences.dart';
import '../models/sports.dart';
import '../services/goals_alerts.dart';
import '../services/sports_service.dart';
import '../services/viewer_profile_service.dart';
import 'game_reminder_overlay.dart';

/// App-wide, non-interactive score card. Never requests focus or touches playback.
class GoalsAlertOverlay extends StatefulWidget {
  const GoalsAlertOverlay({super.key});

  /// Settings' "Show a test popup": each bump shows a sample goal card for
  /// 8 s, so the look (e.g. Transparent popups) can be checked any time.
  static final ValueNotifier<int> previewRequests = ValueNotifier(0);

  /// Tests: replaces [SportsService.gameSummary] for the scorer lookup.
  @visibleForTesting
  static Future<SportsGameSummary?> Function(SportsGame game)? debugSummary;
  @override
  State<GoalsAlertOverlay> createState() => _GoalsAlertOverlayState();
}

class _GoalsAlertOverlayState extends State<GoalsAlertOverlay>
    with WidgetsBindingObserver {
  GoalsAlerts? _service;
  String? _viewer;
  bool _enabled = false;
  bool _teamAlerts = false;
  bool _active = true;
  int _epoch = 0;
  Timer? _poll;
  Timer? _hide;
  final _queue = <GoalAlertNotice>[];

  /// Goals held back by the Goals alert delay setting, released into
  /// [_queue] when due. Cancelled with everything else in [_clear].
  final _delayed = <Timer>{};
  GoalAlertNotice? _notice;
  bool _preview = false;

  /// Who scored ("C. Caufield · 2nd 12:34"), from the game's summary, once
  /// it lists this goal (owner, 1.0.51). Null = the card without it.
  String? _scorer;

  /// ESPN's summary lists a goal ~20-30 s after the scoreboard counts it
  /// (measured on NHL, 2026-11-03), so the scorer lookup retries and the
  /// card stays up past its 8 s while it does, unless another goal waits.
  bool _waitingScorer = false;
  bool _timeIsUp = false;

  /// Lookups 5 s apart: the first + 8 retries = ~40 s.
  static const _scorerRetries = 8;

  @override
  void initState() {
    super.initState();
    GoalsAlertOverlay.previewRequests.addListener(_showPreview);
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.watch<GoalsAlerts>();
    final viewer = context.watch<ViewerProfileService>().active.id;
    final teamAlerts = context.watch<AppPreferences>().goalsAlert;
    final enabled = service.enabled;
    if (_service != service ||
        _viewer != viewer ||
        _enabled != enabled ||
        _teamAlerts != teamAlerts) {
      _service = service;
      _viewer = viewer;
      _enabled = enabled;
      _teamAlerts = teamAlerts;
      _clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  void _clear() {
    _epoch++;
    _poll?.cancel();
    _hide?.cancel();
    for (final t in _delayed) {
      t.cancel();
    }
    _delayed.clear();
    _queue.clear();
    _notice = null;
    _waitingScorer = false;
    _service?.reset();
  }

  Future<void> _refresh() async {
    _poll?.cancel();
    if (!mounted || !_active || !_enabled) return;
    final epoch = _epoch;
    try {
      final notices = await _service!.poll();
      if (!mounted || !_active || epoch != _epoch) return;
      final current = notices.where(_service!.isCurrent).toList();
      final delay = _service!.storage.getGoalAlertDelay();
      if (delay > 0 && current.isNotEmpty) {
        // Settings > Goals alert delay: the viewer's stream (HLS) runs
        // behind the score feed. Counted from when the feed showed the goal.
        final wait = current.first.observedAt
            .add(Duration(seconds: delay))
            .difference(_service!.now());
        late final Timer release;
        release = Timer(wait.isNegative ? Duration.zero : wait, () {
          _delayed.remove(release);
          if (!mounted || !_active || epoch != _epoch) return;
          _enqueue(current);
        });
        _delayed.add(release);
      } else {
        _enqueue(current);
      }
    } finally {
      if (mounted && _active && _enabled && epoch == _epoch) {
        _poll = Timer(const Duration(seconds: 30), _refresh);
      }
    }
  }

  void _enqueue(List<GoalAlertNotice> notices) {
    _queue.addAll(notices.where(_service!.isCurrent));
    // Show the most recent scores if several leagues update together.
    if (_queue.length > 8) _queue.removeRange(0, _queue.length - 8);
    if (_notice != null && !_service!.isCurrent(_notice!)) {
      _notice = null;
    }
    if (_notice == null || (_queue.isNotEmpty && _waitingScorer && _timeIsUp)) {
      _showNext();
    }
  }

  void _showPreview() {
    if (!mounted) return;
    _hide?.cancel();
    const home = SportsTeam(
        id: 'preview-home',
        name: 'Montreal',
        shortName: 'Montreal',
        abbreviation: 'MTL',
        score: '2');
    const away = SportsTeam(
        id: 'preview-away',
        name: 'Toronto',
        shortName: 'Toronto',
        abbreviation: 'TOR',
        score: '1');
    final game = SportsGame(
        id: 'preview',
        league: kSportsLeagues.first,
        start: DateTime.now(),
        state: GameState.live,
        statusText: '2nd',
        home: home,
        away: away);
    _waitingScorer = false;
    setState(() {
      _preview = true;
      _scorer = 'C. Caufield · 2nd 12:34';
      _notice = GoalAlertNotice(
          viewerId: _viewer ?? '',
          game: game,
          team: home,
          observedAt: DateTime.now());
    });
    _hide = Timer(const Duration(seconds: 8), _showNext);
  }

  void _showNext() {
    _hide?.cancel();
    _preview = false;
    GoalAlertNotice? next;
    while (_queue.isNotEmpty) {
      final item = _queue.removeAt(0);
      if (_service!.isCurrent(item)) {
        next = item;
        break;
      }
    }
    _waitingScorer = next != null && !next.overturned;
    _timeIsUp = false;
    setState(() {
      _notice = next;
      _scorer = null;
    });
    if (next != null) {
      _hide = Timer(const Duration(seconds: 8), _timeUp);
      if (!next.overturned) unawaited(_lookupScorer(next));
    }
  }

  /// The card's 8 s are up: it stays while the scorer lookup still runs and
  /// no other goal waits (the lookup then ends it).
  void _timeUp() {
    _timeIsUp = true;
    if (_waitingScorer && _queue.isEmpty) return;
    _showNext();
  }

  /// The scorer of [notice]'s goal: the summary's last goal by that team,
  /// only when its goal count equals the new score (a summary behind the
  /// scoreboard would name the previous scorer). Retried every 5 s for up to
  /// ~40 s: the summary trails the scoreboard. A found name keeps
  /// the card up 6 s more; giving up after the 8 s ends the card.
  /// Football: "TD: Josh Jacobs · Q2 6:33" (or FG), see [_footballPlay].
  Future<void> _lookupScorer(GoalAlertNotice notice) async {
    final score = int.tryParse(notice.team.score ?? '');
    if (score == null || score <= 0) {
      _waitingScorer = false;
      return;
    }
    // Only ESPN hockey/soccer/football summaries list scorers: anything else
    // gets the one try, never the longer card.
    final league = notice.game.league;
    final football = league.sport == 'football';
    final retry = league.sportsDbId == null &&
        !league.isCfl &&
        (football || league.sport == 'hockey' || league.sport == 'soccer');
    var retries = retry ? _scorerRetries : 0;
    while (true) {
      SportsGoal? goal;
      try {
        final summary =
            await (GoalsAlertOverlay.debugSummary?.call(notice.game) ??
                SportsService.instance.gameSummary(notice.game, fresh: true));
        if (!mounted || _notice != notice) return;
        // No summary at all (feed down, nothing cached): don't wait on it.
        if (summary == null) break;
        if (football) {
          goal = _footballPlay(summary.scoringPlays, notice, score);
        } else {
          final goals = summary.goals;
          final mine = goals.where((g) => g.teamId == notice.team.id).toList();
          if (mine.isNotEmpty) {
            if (mine.length == score) goal = mine.last;
          } else if (goals.isNotEmpty && goals.every((g) => g.teamId == null)) {
            // No team ids: only when the whole game's count is right.
            final total = (int.tryParse(notice.game.home.score ?? '') ?? -1) +
                (int.tryParse(notice.game.away.score ?? '') ?? -1);
            if (goals.length == total) goal = goals.last;
          }
        }
      } catch (_) {/* Retried below. */}
      if (!mounted || _notice != notice) return;
      if (goal != null && goal.scorer.trim().isNotEmpty) {
        final when = [goal.period, goal.minute]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');
        _waitingScorer = false;
        setState(() =>
            _scorer = when.isEmpty ? goal!.scorer : '${goal!.scorer} · $when');
        _hide?.cancel();
        _hide = Timer(const Duration(seconds: 6), _showNext);
        return;
      }
      if (retries-- <= 0) break;
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!mounted || _notice != notice) return;
    }
    _waitingScorer = false;
    if (_timeIsUp) _showNext();
  }

  /// The team's last touchdown / field goal when its score after the play is
  /// the new score, or up to 2 more: a scoreboard can count the 6 before the
  /// kick that ESPN's play already includes. An older play (summary behind)
  /// never matches.
  static SportsGoal? _footballPlay(
      List<SportsGoal> plays, GoalAlertNotice notice, int score) {
    final home = notice.team.id == notice.game.home.id;
    for (final p in plays.reversed) {
      if (p.teamId != notice.team.id) continue;
      final parts = p.score?.split('-');
      final after =
          parts?.length == 2 ? int.tryParse(parts![home ? 1 : 0]) : null;
      if (after == null) return null;
      return after >= score && after <= score + 2 ? p : null;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _clear();
    setState(() {});
    if (_active) _refresh();
  }

  @override
  void dispose() {
    _epoch++;
    _poll?.cancel();
    _hide?.cancel();
    for (final t in _delayed) {
      t.cancel();
    }
    _service?.reset();
    GoalsAlertOverlay.previewRequests.removeListener(_showPreview);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    if (!_active ||
        notice == null ||
        (!_preview && !_service!.isCurrent(notice))) {
      return const SizedBox.shrink();
    }
    final game = notice.game;
    final accent = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: ExcludeFocus(
        child: SafeArea(
          child: ValueListenableBuilder<double>(
            valueListenable: GameReminderOverlay.occupiedHeight,
            builder: (context, reminderHeight, _) => Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20,
                    20 +
                        (MediaQuery.sizeOf(context).width < 800
                            ? reminderHeight
                            : 0),
                    20,
                    20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Semantics(
                    liveRegion: true,
                    child: Material(
                      key: const ValueKey('goal-alert'),
                      color: transparentPopups(context)
                          ? Colors.transparent
                          : RefinedFinish.surface(
                              context, const Color(0xFA15171C)),
                      elevation: transparentPopups(context) ? 0 : 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: transparentPopups(context)
                            ? BorderSide.none
                            : BorderSide(color: accent.withValues(alpha: 0.55)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: PopupTextShadow(
                          child: Stack(children: [
                        if (notice.team.logoUrl?.isNotEmpty == true)
                          Positioned(
                              top: -12,
                              bottom: -12,
                              right: -8,
                              width: 115,
                              child: Opacity(
                                  opacity: 0.16,
                                  child: _ScoreLogo(
                                      url: notice.team.logoUrl, size: 100))),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  _ScoreLogo(
                                      key: const ValueKey('goal-league-logo'),
                                      url: game.league.logoUrl,
                                      size: 22),
                                  const SizedBox(width: 7),
                                  Expanded(
                                      child: Text(game.league.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12))),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  _ScoreLogo(
                                      key: const ValueKey('goal-team-logo'),
                                      url: notice.team.logoUrl,
                                      size: 44),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            notice.overturned
                                                ? notice.overturnedText
                                                : tr('{team} scored!', {
                                                    'team':
                                                        notice.team.shortName
                                                  }),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: accent,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800)),
                                        if (_scorer case final scorer?)
                                          Text(scorer,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(
                                            tr(
                                                '{first} {firstScore} – {secondScore} {second}',
                                                {
                                                  'first':
                                                      game.first.abbreviation,
                                                  'firstScore':
                                                      game.first.score!,
                                                  'secondScore':
                                                      game.second.score!,
                                                  'second':
                                                      game.second.abbreviation,
                                                }),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold)),
                                        if (game.statusText.isNotEmpty)
                                          Text(game.statusText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11)),
                                      ])),
                                ]),
                              ]),
                        ),
                      ])),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreLogo extends StatelessWidget {
  const _ScoreLogo({super.key, required this.url, required this.size});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: url?.isNotEmpty == true
          ? Image.network(url!,
              fit: BoxFit.contain,
              cacheWidth: 128,
              cacheHeight: 128,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.sports, size: size * 0.7, color: Colors.white70))
          : Icon(Icons.sports, size: size * 0.7, color: Colors.white70));
}
