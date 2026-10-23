import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/episode_airing.dart';
import '../models/series_details.dart';
import '../services/episode_air_date_service.dart';

/// Non-focusable schedule text. It never adds an episode to the playback queue.
class NextEpisodeAirDate extends StatefulWidget {
  const NextEpisodeAirDate(
      {super.key,
      this.details,
      this.imdbId,
      this.tmdbId,
      this.tmdbKey = '',
      this.scale = 1,
      this.service});
  final SeriesDetails? details;
  final String? imdbId;
  final String? tmdbId;
  final String tmdbKey;
  final double scale;
  final EpisodeAirDateService? service;

  @override
  State<NextEpisodeAirDate> createState() => _NextEpisodeAirDateState();
}

class _NextEpisodeAirDateState extends State<NextEpisodeAirDate> {
  EpisodeAiring? _airing;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(NextEpisodeAirDate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.details != widget.details ||
        oldWidget.imdbId != widget.imdbId ||
        oldWidget.tmdbId != widget.tmdbId ||
        oldWidget.tmdbKey != widget.tmdbKey ||
        oldWidget.service != widget.service) {
      _airing = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final generation = ++_generation;
    final airing = await (widget.service ?? EpisodeAirDateService.instance)
        .resolve(
            details: widget.details,
            imdbId: widget.imdbId,
            tmdbId: widget.tmdbId,
            tmdbKey: widget.tmdbKey);
    if (mounted && generation == _generation) setState(() => _airing = airing);
  }

  @override
  Widget build(BuildContext context) {
    final airing = _airing;
    if (airing == null) return const SizedBox.shrink();
    final date = DateFormat.yMMMd(L10n.code).format(airing.displayDate);
    final code = airing.code;
    return Padding(
      padding: EdgeInsets.only(top: 8 * widget.scale),
      child: Text(
          code == null
              ? tr('Next episode airs {date}', {'date': date})
              : tr('Next episode: {code} · {date}',
                  {'code': code, 'date': date}),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13 * widget.scale,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
