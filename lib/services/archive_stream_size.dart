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

/// Unknown sizes retain the picker. Equal sizes preserve provider order.
ArchiveStreamOption? largestArchiveStream(List<ArchiveStreamOption> options) {
  ArchiveStreamOption? best;
  var bytes = 0;
  for (final option in options) {
    if (option.stream.ytId != null) continue;
    final size = archiveStreamBytes(option);
    if (size > bytes) {
      best = option;
      bytes = size;
    }
  }
  return best;
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
