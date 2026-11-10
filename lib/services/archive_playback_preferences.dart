import 'dart:convert';
import 'dart:math';
import '../l10n/l10n.dart';
import 'archive_service.dart';
import 'archive_playback_sources.dart';
import 'storage_service.dart';
import 'stream_languages.dart';

class ArchivePlaybackPreferences {
  const ArchivePlaybackPreferences(
      {this.autoPlay = false,
      this.language = '',
      this.maxHeight = 0,
      this.sourceKey = '',
      this.avoidHdr = false,
      this.audioLanguage = '',
      this.appLanguage = ''});
  final bool autoPlay;

  /// Settings > Media Hub > Playback > language: only streams whose label
  /// fits it (see [streamLanguageFit]: for English, also untagged ones).
  final String language;

  /// Settings > Playback > Audio (per viewer), when [language] is unset:
  /// streams that fit it come first; the others stay, after them.
  final String audioLanguage;

  /// The app's language, when neither is set: only streams naming nothing
  /// but other languages (a dub) go last.
  final String appLanguage;
  final int maxHeight;
  final String sourceKey;
  final bool avoidHdr;

  factory ArchivePlaybackPreferences.read(StorageService storage) {
    try {
      final j =
          jsonDecode(storage.getArchiveOptionsJson('playback') ?? '{}') as Map;
      return ArchivePlaybackPreferences(
          autoPlay: j['auto'] == true,
          language: const ['', 'en', 'fr', 'es', 'de', 'it', 'pt']
                  .contains(j['language'])
              ? j['language']
              : '',
          maxHeight:
              [720, 1080, 2160].contains(j['maxHeight']) ? j['maxHeight'] : 0,
          sourceKey: j['source'] is String ? j['source'] : '',
          avoidHdr: j['avoidHdr'] == true,
          audioLanguage: storage.getPreferredAudioLanguage(),
          appLanguage: L10n.code);
    } catch (_) {
      return ArchivePlaybackPreferences(
          audioLanguage: storage.getPreferredAudioLanguage(),
          appLanguage: L10n.code);
    }
  }

  Future<void> save(StorageService storage) => storage.setArchiveOptionsJson(
      'playback',
      jsonEncode({
        'auto': autoPlay,
        'language': language,
        'maxHeight': maxHeight,
        'source': sourceKey,
        'avoidHdr': avoidHdr
      }));

  static int height(ArchiveStreamOption option) {
    final formats = archiveStreamFormats(option);
    return formats.contains('4K')
        ? 2160
        : formats.contains('1080p')
            ? 1080
            : formats.contains('720p')
                ? 720
                : 0;
  }

  bool accepts(ArchiveStreamOption option) {
    final h = height(option);
    if (maxHeight > 0 && h > maxHeight) return false;
    if (avoidHdr &&
        archiveStreamFormats(option).any(
            (f) => f.contains('HDR') || f == 'Dolby Vision' || f == 'HLG')) {
      return false;
    }
    return true;
  }

  /// How well [o]'s label fits the viewer's language: 2 = it has it (only
  /// that language or among others, see [streamLanguageFit]), 1 = maybe,
  /// 0 = only other languages; 1 for every stream when no language
  /// applies. Having it is enough: the player picks that audio track, so
  /// an English + Russian remux counts like an English-only one (owner,
  /// 2026-11-09: largest file = largest with English, not English only).
  int languageTier(ArchiveStreamOption o) {
    final text =
        archiveStreamLabel('${o.stream.name ?? ''} ${o.stream.title ?? ''}');
    if (language.isNotEmpty) return min(streamLanguageFit(text, language), 2);
    if (audioLanguage.isNotEmpty) {
      return min(streamLanguageFit(text, audioLanguage), 2);
    }
    if (appLanguage.isNotEmpty) {
      return streamLanguageFit(text, appLanguage) == 0 ? 0 : 1;
    }
    return 1;
  }

  /// The acceptable streams, best first: language fit, preferred source,
  /// quality, then the add-on's order. With [language] set, a stream whose
  /// label doesn't fit it is left out (unknown is never taken as that
  /// language, except untagged releases for English). [strict] false keeps
  /// every stream and only orders them (a fallback when none is acceptable).
  List<ArchiveStreamOption> ranked(List<ArchiveStreamOption> options,
      {bool strict = true}) {
    final tiers = {for (final o in options) o: languageTier(o)};
    final result = strict
        ? options
            .where((o) =>
                accepts(o) &&
                (maxHeight == 0 || height(o) > 0) &&
                (language.isEmpty || tiers[o]! >= 2))
            .toList()
        : options.toList();
    final positions = {for (var i = 0; i < options.length; i++) options[i]: i};
    result.sort((a, b) {
      final fit = tiers[b]!.compareTo(tiers[a]!);
      if (fit != 0) return fit;
      final source = (b.source.key == sourceKey ? 1 : 0)
          .compareTo(a.source.key == sourceKey ? 1 : 0);
      final quality = height(b).compareTo(height(a));
      return source != 0
          ? source
          : quality != 0
              ? quality
              : positions[a]!.compareTo(positions[b]!);
    });
    return result;
  }

  /// The leading streams of [ranked] that fit the language best (every
  /// stream that has it): "play the largest file" picks among these, so a
  /// bigger dub never wins.
  List<ArchiveStreamOption> bestLanguage(List<ArchiveStreamOption> ranked) {
    if (ranked.isEmpty) return ranked;
    final top = languageTier(ranked.first);
    return [
      for (final o in ranked)
        if (languageTier(o) == top) o
    ];
  }
}
