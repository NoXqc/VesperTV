import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/trailer.dart';
import '../services/app_preferences.dart';
import '../services/archive_service.dart';
import '../services/storage_service.dart';
import '../services/trailer_service.dart';
import '../services/youtube_streams.dart';
import 'detail_trailer.dart';

/// Media Hub's focused card playing the title's trailer (Settings >
/// Playback > Trailers on Media Hub cards; owner, 2026-11-26,
/// after ARVIO's rows): the card's backdrop stays until the first picture,
/// then the video fades in over it; at the end it fades back out. The
/// Media Hub tab's rows, a collection's page (the wide card) and Expand
/// collection / Expand catalog with Wide cards on (the focused 16:9 card);
/// [CardTrailerSlot] runs it for a page.
class CardTrailer extends StatefulWidget {
  const CardTrailer({super.key, required this.uri, this.onDone});
  final Uri uri;

  /// Played to the end or failed: don't start it again on this card.
  final VoidCallback? onDone;

  /// Settings > Playback > Trailers on Media Hub cards.
  static bool enabledIn(BuildContext context) =>
      context.read<AppPreferences?>()?.cardTrailers ?? false;

  /// [find] with the viewer's add-ons and TMDB key.
  static Future<Uri?> findIn(
      BuildContext context, ArchiveMeta meta, ArchiveSource source) {
    final addons = context.read<ArchiveService>().enabledSources;
    final tmdbKey = context.read<StorageService?>()?.getTmdbApiKey() ?? '';
    return find(meta, source, addons: addons, tmdbKey: tmdbKey);
  }

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
    final file = await YouTubeStreams.instance.resolveSmall(youtube);
    if (file == null) tellIfYouTubeBlocked();
    return file;
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

/// One page's card trailer: [arm] when a card takes the focus. The trailer
/// is looked up after [lookupAfter] on the card (fast scrolling asks
/// nothing) and plays from [startAfter] when found by then (at 0.5 s,
/// stepping along a row opened and closed a player per card). [video] is
/// a card's slot. A notifier: only that slot redraws (a Media Hub setState
/// costs ~450 ms on the Homatics). `done`: played out on this card, not
/// again until the remote leaves it.
class CardTrailerSlot {
  static const lookupAfter = Duration(milliseconds: 300);
  static const startAfter = Duration(seconds: 1);

  /// The card whose trailer is found ([place]: its row, or a grid cell).
  final current =
      ValueNotifier<({String place, String id, Uri uri, bool done})?>(null);
  Timer? _lookup, _due;
  int _generation = 0;
  bool _disposed = false;

  /// Card [id] in [place] took the focus; [stillHere] turns false once the
  /// remote left it.
  void arm({
    required String place,
    required String id,
    required bool Function() stillHere,
    required Future<Uri?> Function() find,
  }) {
    cancel();
    final known = current.value;
    if (known != null && known.place == place && known.id == id) return;
    current.value = null;
    final generation = _generation;
    Uri? found;
    var due = false;
    void start() {
      if (_disposed || generation != _generation) return;
      if (found != null && due && stillHere()) {
        current.value = (place: place, id: id, uri: found!, done: false);
      }
    }

    _due = Timer(startAfter, () {
      due = true;
      start();
    });
    _lookup = Timer(lookupAfter, () async {
      if (!stillHere()) return;
      found = await find();
      start();
    });
  }

  /// The timers only (a trailer already playing plays on).
  void cancel() {
    _lookup?.cancel();
    _due?.cancel();
    _lookup = null;
    _due = null;
    _generation++;
  }

  /// The timers and the trailer (the remote left the cards, a page opened).
  void stop() {
    cancel();
    if (!_disposed) current.value = null;
  }

  /// Card [id]'s video in [place]: nothing until its trailer is found.
  Widget video(String place, String id) => ValueListenableBuilder(
      valueListenable: current,
      builder: (context, trailer, _) {
        if (trailer == null ||
            trailer.done ||
            trailer.place != place ||
            trailer.id != id) {
          return const SizedBox.shrink();
        }
        return CardTrailer(
            key: ValueKey(trailer.uri),
            uri: trailer.uri,
            onDone: () {
              final now = current.value;
              if (_disposed || now == null) return;
              if (now.place == place && now.id == id) {
                current.value =
                    (place: place, id: id, uri: trailer.uri, done: true);
              }
            });
      });

  void dispose() {
    cancel();
    _disposed = true;
    current.dispose();
  }
}
