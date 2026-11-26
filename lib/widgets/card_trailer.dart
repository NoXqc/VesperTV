import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/trailer.dart';
import '../services/trailer_service.dart';
import '../services/youtube_streams.dart';
import 'detail_trailer.dart';

/// Media Hub's focused card playing the title's trailer (Settings >
/// Playback > Trailers on Media Hub cards; owner, 2026-11-26,
/// after ARVIO's rows): the card's backdrop stays until the first picture,
/// then the video fades in over it; at the end it fades back out.
class CardTrailer extends StatefulWidget {
  const CardTrailer({super.key, required this.uri, this.onDone});
  final Uri uri;

  /// Played to the end or failed: don't start it again on this card.
  final VoidCallback? onDone;

  /// The trailer file for [meta], or null: the title page's lookup in its
  /// quick form ([TrailerService.resolve] `quick`), and only files our player opens
  /// (a YouTube trailer's own file, or an add-on's direct link). YouTube's
  /// web player in a card is too heavy for a TV box.
  static Future<Uri?> find(ArchiveMeta meta, ArchiveSource source,
      {required List<ArchiveSource> addons, required String tmdbKey}) async {
    if (debugFind case final fake?) return fake(meta);
    final found = await TrailerService.instance.resolve(
        TrailerRequest(
            title: meta.name,
            series: meta.type == ArchiveType.series,
            year: int.tryParse(meta.year ?? ''),
            imdbId: meta.imdb,
            supplied: source.suppliesOwnMetadata ? meta.trailers : const [],
            suppliedStreams:
                source.suppliesOwnMetadata ? meta.trailerStreams : const [],
            language: L10n.code,
            tmdbKey: tmdbKey),
        addons: addons,
        quick: true);
    if (found == null) return null;
    final youtube = TrailerLinks.videoId(found.toString());
    if (youtube == null) return found;
    if (!YouTubeStreams.supported) return null;
    return YouTubeStreams.instance.resolveSmall(youtube);
  }

  /// Tests: answers [find] instead of the trailer lookup.
  @visibleForTesting
  static Future<Uri?> Function(ArchiveMeta meta)? debugFind;

  @override
  State<CardTrailer> createState() => _CardTrailerState();
}

class _CardTrailerState extends State<CardTrailer> {
  bool _playing = false;
  bool _done = false;

  void _end({bool failed = false}) {
    if (!mounted || _done) return;
    if (failed) {
      debugPrint('Trailer: card file failed');
      if (TrailerLinks.videoId(widget.uri.toString()) case final id?) {
        YouTubeStreams.instance.forget(id);
      }
    }
    setState(() => _done = true);
    // After the fade back to the backdrop.
    Timer(const Duration(milliseconds: 450), () => widget.onDone?.call());
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeFocus(
          child: AnimatedOpacity(
            opacity: _playing && !_done ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            // Kept through the fade out; the card drops it after [onDone].
            child: TrailerVideo(
              uri: widget.uri,
              onPlaying: () {
                if (mounted && !_playing) {
                  debugPrint('Trailer: card playing');
                  setState(() => _playing = true);
                }
              },
              onFinished: _end,
              onFailed: () => _end(failed: true),
            ),
          ),
        ),
      );
}
