import 'archive_service.dart';
import '../models/media_file_info.dart';

/// Prefer structured bytes; many add-ons only supply a labelled size.
int archiveStreamBytes(ArchiveStreamOption option) {
  final stream = option.stream;
  if (stream.sizeBytes case final bytes? when bytes > 0) return bytes;
  return archiveStreamLabelBytes(option);
}

/// Kept separately for diagnostics when structured and displayed sizes disagree.
int archiveStreamLabelBytes(ArchiveStreamOption option) {
  final stream = option.stream;
  final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(TiB|GiB|MiB|KiB|TB|GB|MB|KB)\b',
          caseSensitive: false)
      .firstMatch('${stream.title ?? ''} ${stream.name ?? ''}');
  if (match == null) return 0;
  final number = double.tryParse(match[1]!.replaceAll(',', '.')) ?? 0;
  final unit = match[2]!.toUpperCase();
  final power = switch (unit[0]) { 'T' => 4, 'G' => 3, 'M' => 2, _ => 1 };
  final base = unit.contains('I') ? 1024 : 1000;
  var bytes = number;
  for (var n = 0; n < power; n++) {
    bytes *= base;
  }
  return bytes.round();
}

/// Metadata follows the selected stream provider, not the catalog's source.
MediaFileInfo archiveMediaFileInfo(ArchiveStreamOption option) {
  String label(String text) => text
      .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Provider labels are safe to show; transport URLs can contain access tokens.
  final name = label(option.stream.name ?? '');
  final fallback = label(option.source.name);
  final bytes = archiveStreamBytes(option);
  return MediaFileInfo(
      source:
          name.isNotEmpty ? name : (fallback.isEmpty ? 'Media Hub' : fallback),
      sizeBytes: bytes > 0 ? bytes : null);
}

/// One link for a whole season (or several episodes), sized as all of it:
/// its file names a season or an episode range but no single episode
/// ("Dark Matter 2024 S02 1080p…", 45.6 GB; a 111 GB one won Largest file
/// for one episode, LOG-7QUQAW). A pack link that names the episode's own
/// file inside it (`…S02E07…mkv`) is sized as that file and isn't one.
bool archiveStreamIsSeasonPack(ArchiveStreamOption option) {
  final stream = option.stream;
  final text = stream.fileName ?? '${stream.name ?? ''} ${stream.title ?? ''}';
  return !_singleEpisode.hasMatch(text) &&
      (_episodeRange.hasMatch(text) || _seasonOnly.hasMatch(text));
}

// S02E07 (not S02E07-E09), 2x07, EP-7, Episode 7, Spanish Cap.207.
final _singleEpisode = RegExp(
    r's\d{1,2}[ ._-]?e\d{1,3}(?!\d)'
    r'(?![ ._-]*(?:-|~|to)[ ._-]*(?:s\d{1,2}[ ._-]?)?e?\d)'
    r'|(?<![a-z0-9])\d{1,2}x\d{2,3}(?!\d)'
    r'|(?<![a-z])ep(?:isode)?[ ._-]?\d{1,3}(?!\d)'
    r'|cap\.?\s?\d{3,4}',
    caseSensitive: false);
final _episodeRange = RegExp(
    r'e\d{1,3}[ ._-]*(?:-|~|to)[ ._-]*(?:s\d{1,2}[ ._-]?)?e?\d{1,3}(?!\d)',
    caseSensitive: false);
final _seasonOnly = RegExp(
    r'(?<![a-z0-9])s\d{1,2}(?![0-9]|[ ._-]?e\d)|season[ ._-]?\d|complete',
    caseSensitive: false);

/// Unknown sizes retain the picker. Equal sizes preserve provider order.
/// Season packs only when nothing else has a size: theirs is the season's.
ArchiveStreamOption? largestArchiveStream(List<ArchiveStreamOption> options) {
  ArchiveStreamOption? best, bestPack;
  var bytes = 0, packBytes = 0;
  for (final option in options) {
    if (option.stream.ytId != null) continue;
    final size = archiveStreamBytes(option);
    if (archiveStreamIsSeasonPack(option)) {
      if (size > packBytes) {
        bestPack = option;
        packBytes = size;
      }
    } else if (size > bytes) {
      best = option;
      bytes = size;
    }
  }
  return best ?? bestPack;
}

/// True when a cached debrid link served a provider's error clip instead of
/// the file: Comet answers a failed TorBox lookup with a 0.4 MB video that
/// reads "Unexpected provider response" (owner, 2026-10-28; 32 of 60
/// Shawshank links at that moment, the rest played). Deliberately strict:
/// the stream must say it's cached (⚡ / `+]`) and nothing uncached, the
/// listing must name a file of 500 MB or more, and the reply must be 5 MB
/// or less. An uncached `[TB download]` link's "being downloaded" clip is
/// the Ready watch's business (`ArchiveReadyWatch`), never this.
bool archiveProviderFailed(
    ArchiveStreamOption option, String finalUrl, int? servedBytes) {
  if (servedBytes == null || servedBytes > 5 * 1000 * 1000) return false;
  if (archiveStreamBytes(option) < 500 * 1000 * 1000) return false;
  final label = '${option.stream.name ?? ''} ${option.stream.title ?? ''}';
  final cached = label.contains('⚡') || label.contains('+]');
  final uncached = label.toLowerCase().contains('download') ||
      label.contains('⏳') ||
      finalUrl.toLowerCase().contains('download');
  return cached && !uncached;
}
