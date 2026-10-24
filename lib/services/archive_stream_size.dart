import 'archive_service.dart';

/// Prefer structured bytes; many add-ons only supply a labelled size.
int archiveStreamBytes(ArchiveStreamOption option) {
  final stream = option.stream;
  if (stream.sizeBytes case final bytes? when bytes > 0) return bytes;
  final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(TiB|GiB|MiB|KiB|TB|GB|MB|KB)\b',
          caseSensitive: false)
      .firstMatch(stream.title ?? '');
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
