import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/sports.dart';
import '../services/sports_service.dart';
import '../utils/route_observer.dart';

/// Small, non-focusable context for the selected matchup. Uses the same cached
/// summary as the game-details dialog; resting on a card fetches only that game.
class SportsMatchupStats extends StatefulWidget {
  const SportsMatchupStats({
    super.key,
    required this.game,
    required this.service,
    required this.hideScores,
    this.compact = false,
    this.showOdds = false,
  });

  final SportsGame game;
  final SportsService service;
  final bool hideScores;
  final bool compact;

  /// Settings > Sports Trak > Betting odds.
  final bool showOdds;

  @override
  State<SportsMatchupStats> createState() => _SportsMatchupStatsState();
}

class _SportsMatchupStatsState extends State<SportsMatchupStats>
    with RouteAware, WidgetsBindingObserver {
  Timer? _timer;
  PageRoute<dynamic>? _route;
  SportsGameSummary? _summary;
  bool _loading = true;
  bool _covered = false;
  bool _foreground = true;
  int _generation = 0;

  bool get _suppressed =>
      widget.hideScores && widget.game.state != GameState.pre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route && route is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(SportsMatchupStats old) {
    super.didUpdateWidget(old);
    if (old.game.id != widget.game.id ||
        old.game.league.id != widget.game.league.id ||
        old.game.state != widget.game.state ||
        old.service != widget.service ||
        old.hideScores != widget.hideScores) {
      _summary = null;
      _loading = true;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final generation = ++_generation;
    if (_suppressed || _covered || !_foreground) return;
    _timer = Timer(const Duration(milliseconds: 350), () => _load(generation));
  }

  Future<void> _load(int generation) async {
    SportsGameSummary? summary;
    try {
      summary = await widget.service.gameSummary(widget.game);
    } catch (_) {
      // A missing/failed feed is ordinary: show only known scoreboard details.
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
    _timer = Timer(
        widget.game.state == GameState.live
            ? const Duration(seconds: 30)
            : const Duration(minutes: 10),
        () => _load(generation));
  }

  void _pause() {
    _timer?.cancel();
    _generation++;
  }

  @override
  void didPushNext() {
    _covered = true;
    _pause();
  }

  @override
  void didPopNext() {
    _covered = false;
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _schedule();
    } else {
      _pause();
    }
  }

  @override
  void dispose() {
    _pause();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<(String, String)> _details() {
    final game = widget.game;
    final summary = _summary;
    if (_suppressed) return [(tr('Scores hidden'), '')];
    final result = <(String, String)>[];
    if (game.state == GameState.pre) {
      for (final team in [game.first, game.second]) {
        var standing = ('', '');
        for (final table in summary?.tables ?? <SportsSummaryTable>[]) {
          final row = table.rows.where((r) => r.$1 == team.id).firstOrNull;
          if (row == null) continue;
          final values = <String>[];
          for (var i = 0; i < table.labels.length && i < row.$3.length; i++) {
            if (row.$3[i].isNotEmpty) {
              values.add('${trSports(table.labels[i])} ${row.$3[i]}');
            }
          }
          if (values.isNotEmpty) {
            standing = (
              team.shortName,
              '${table.title} · ${values.take(3).join(' · ')}'
            );
            break;
          }
        }
        result.add(standing);
      }
      final injuries = <String>[
        for (final team in [game.first, game.second])
          if (summary?.injuries[team.id]?.firstOrNull case final injury?)
            '${injury.name} · ${trSports(injury.status)}',
      ];
      // Betting odds on (Settings > Sports Trak): the line fills the middle
      // slot when there's no injury to show.
      final odds = widget.showOdds ? game.odds : null;
      // Keep a slot beneath each team even when one feed detail is missing.
      result.insert(
          1,
          injuries.isNotEmpty
              ? (tr('Injuries'), injuries.join(' / '))
              : odds != null && odds.line.isNotEmpty
                  ? (tr('Betting odds'), odds.line)
                  : ('', ''));
      if (result.every((item) => item.$1.isEmpty)) return [];
    } else {
      final goal = summary?.goals.lastOrNull;
      if (goal != null) {
        result.add((
          tr('Latest goal'),
          '${goal.scorer} · ${[
            goal.period,
            goal.minute
          ].whereType<String>().where((s) => s.isNotEmpty).join(' ')}'
        ));
      } else if (game.situation?.lastPlay case final String play
          when play.isNotEmpty) {
        result.add((tr('Last play'), play));
      } else if (game.situation?.text case final String situation
          when situation.isNotEmpty) {
        result.add((tr('Game situation'), situation));
      }
      final leaders = <SportsLeader>[
        ...game.leaders,
        for (final team in [game.first, game.second])
          ...?summary?.leaders[team.id],
      ];
      final seen = <String>{};
      for (final leader in leaders) {
        if (!seen.add('${leader.teamId}|${leader.name}|${leader.stat}')) {
          continue;
        }
        final team = [game.first, game.second]
            .where((t) => t.id == leader.teamId)
            .firstOrNull;
        result.add((
          [team?.shortName, trSports(leader.stat)]
              .whereType<String>()
              .join(' · '),
          '${leader.name} · ${leader.value}',
        ));
        if (result.length >= 2) break;
      }
      for (final stat in summary?.teamStats ?? <(String, String, String)>[]) {
        if (stat.$2.isEmpty && stat.$3.isEmpty) continue;
        final homeFirst = game.first.id == game.home.id;
        final first = homeFirst ? stat.$3 : stat.$2;
        final second = homeFirst ? stat.$2 : stat.$3;
        result.add((
          trSports(stat.$1),
          '${game.first.abbreviation} ${first.isEmpty ? '—' : first} · ${game.second.abbreviation} ${second.isEmpty ? '—' : second}'
        ));
        if (result.length >= 3) break;
      }
    }
    return result.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final details = _details();
    final accent = Theme.of(context).colorScheme.primary;
    Widget entry((String, String) item, {TextAlign align = TextAlign.start}) =>
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: align == TextAlign.end
              ? CrossAxisAlignment.end
              : align == TextAlign.center
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
          children: [
            Text(item.$1,
                textAlign: align,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, color: accent, fontWeight: FontWeight.w700)),
            if (item.$2.isNotEmpty)
              Text(item.$2,
                  textAlign: align,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70, height: 1.15)),
          ],
        );
    return ExcludeFocus(
      child: Container(
        key: const ValueKey('sports-matchup-stats'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.black26,
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(10)),
        child: LayoutBuilder(builder: (context, bounds) {
          final cells = details.isEmpty
              ? [
                  (
                    tr('Key stats'),
                    _loading ? '' : tr('No stats for this game yet.')
                  )
                ]
              : details;
          if (bounds.maxWidth < 500 && !widget.compact) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              for (final cell in cells.where((item) => item.$1.isNotEmpty))
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child:
                        SizedBox(width: double.infinity, child: entry(cell))),
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(right: 8, top: 3),
                child: Icon(Icons.insights, size: 16, color: accent)),
            for (final (i, cell) in (bounds.maxWidth < 500
                    ? cells.where((item) => item.$1.isNotEmpty).take(1)
                    : cells)
                .indexed)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: entry(cell,
                          align: widget.game.state == GameState.pre &&
                                  bounds.maxWidth >= 500 &&
                                  cells.length == 3
                              ? [
                                  TextAlign.start,
                                  TextAlign.center,
                                  TextAlign.end
                                ][i]
                              : TextAlign.start))),
          ]);
        }),
      ),
    );
  }
}
