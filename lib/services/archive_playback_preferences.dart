import 'dart:convert';
import 'archive_service.dart';
import 'archive_playback_sources.dart';
import 'storage_service.dart';

class ArchivePlaybackPreferences {
  const ArchivePlaybackPreferences(
      {this.autoPlay = false,
      this.language = '',
      this.maxHeight = 0,
      this.sourceKey = '',
      this.avoidHdr = false});
  final bool autoPlay;
  final String language;
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
          avoidHdr: j['avoidHdr'] == true);
    } catch (_) {
      return const ArchivePlaybackPreferences();
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

  bool _languageMatches(ArchiveStreamOption o) {
    if (language.isEmpty) return true;
    final aliases = const {
          'en': 'eng|english',
          'fr': 'fra|fre|french|français',
          'es': 'spa|spanish|español',
          'de': 'deu|ger|german',
          'it': 'ita|italian',
          'pt': 'por|portuguese'
        }[language] ??
        language;
    final text =
        archiveStreamLabel('${o.stream.name ?? ''} ${o.stream.title ?? ''}');
    return RegExp('\\b($language|$aliases)\\b', caseSensitive: false)
        .hasMatch(text);
  }

  /// Unknown audio language is never silently treated as a requested language.
  List<ArchiveStreamOption> ranked(List<ArchiveStreamOption> options) {
    final result = options
        .where((o) =>
            accepts(o) &&
            (maxHeight == 0 || height(o) > 0) &&
            _languageMatches(o))
        .toList();
    final positions = {for (var i = 0; i < options.length; i++) options[i]: i};
    result.sort((a, b) {
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
}
