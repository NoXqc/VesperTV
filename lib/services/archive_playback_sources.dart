import 'archive_stream_session.dart';
import '../models/channel.dart';
import 'archive_service.dart';
import 'archive_stream_size.dart';

/// A title's available streams, scoped to its playback route and active viewer.
/// Channel IDs identify episodes, so opening the drawer after Next never offers
/// the previous episode's files. URLs stay in memory and are never UI labels.
class ArchivePlaybackSources {
  const ArchivePlaybackSources({
    required this.load,
    required this.current,
    required this.select,
    required this.remember,
    this.search,
  });

  final Future<List<ArchiveStreamOption>> Function(String channelId) load;
  final ArchiveStreamSession? Function(String channelId)? search;
  final ArchiveStreamOption? Function(String channelId) current;
  final Future<Channel?> Function(String channelId, ArchiveStreamOption option)
      select;
  final Future<void> Function(String channelId, ArchiveStreamOption option)
      remember;
}

class ArchiveSourceSelection {
  const ArchiveSourceSelection(this.channel, this.option);
  final Channel channel;
  final ArchiveStreamOption option;
}

/// Add-on-advertised format information; never guess from a playback URL.
List<String> archiveStreamFormats(ArchiveStreamOption option) {
  final text = archiveStreamLabel(
      '${option.stream.name ?? ''} ${option.stream.title ?? ''}');
  bool has(String pattern) =>
      RegExp(pattern, caseSensitive: false).hasMatch(text);
  return [
    if (has(r'\b(4k|2160p|uhd)\b'))
      '4K'
    else if (has(r'\b1080[pi]?\b'))
      '1080p'
    else if (has(r'\b720p?\b'))
      '720p',
    if (has(r'\b(dolby[ ._-]*vision|dovi|dv)\b')) 'Dolby Vision',
    if (has(r'\bhdr10\s*\+'))
      'HDR10+'
    else if (has(r'\bhdr10\b'))
      'HDR10'
    else if (has(r'\bhdr\b'))
      'HDR',
    if (has(r'\bhlg\b')) 'HLG',
    if (has(r'\b(hevc|[hx][ ._-]?265)\b'))
      'HEVC'
    else if (has(r'\bav1\b'))
      'AV1'
    else if (has(r'\b(avc|[hx][ ._-]?264)\b'))
      'H.264',
  ];
}

String archiveStreamLabel(String text) => text
    .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Locate the playing source after an add-on refreshes its signed links.
/// Never infer a current row from a shared quality label or another provider.
/// -1 means there is no unique match; the drawer can retain the known selection.
int archiveCurrentStreamIndex(
    List<ArchiveStreamOption> options, ArchiveStreamOption? current) {
  if (current == null || current.stream.ytId != null) return -1;
  String hash(ArchiveStreamOption o) =>
      (o.stream.videoHash ?? '').trim().toLowerCase();
  String filename(ArchiveStreamOption o) => (o.stream.fileName ?? '').trim();
  final currentHash = hash(current);
  final currentFile = filename(current);
  final currentBytes = archiveStreamBytes(current);
  final candidates = <int>[];
  for (var i = 0; i < options.length; i++) {
    final candidate = options[i];
    if (candidate.stream.ytId != null ||
        candidate.source.manifestUrl != current.source.manifestUrl) {
      continue;
    }
    final bytes = archiveStreamBytes(candidate);
    if (currentBytes > 0 && bytes > 0 && currentBytes != bytes) continue;
    final candidateHash = hash(candidate);
    if (currentHash.isNotEmpty &&
        candidateHash.isNotEmpty &&
        currentHash != candidateHash) {
      continue;
    }
    if ((currentHash.isEmpty || candidateHash.isEmpty) &&
        currentFile.isNotEmpty &&
        filename(candidate).isNotEmpty &&
        currentFile != filename(candidate)) {
      continue;
    }
    candidates.add(i);
  }
  final checks = <bool Function(ArchiveStreamOption)>[
    (o) =>
        current.stream.url.isNotEmpty &&
        o.stream.identity == current.stream.identity,
    (o) => currentHash.isNotEmpty && hash(o) == currentHash,
    (o) => currentFile.isNotEmpty && filename(o) == currentFile,
    (o) =>
        ((current.stream.name ?? '').isNotEmpty ||
            (current.stream.title ?? '').isNotEmpty) &&
        o.stream.name == current.stream.name &&
        o.stream.title == current.stream.title,
  ];
  for (final check in checks) {
    final matched = candidates.where((i) => check(options[i])).toList();
    if (matched.isNotEmpty) return matched.length == 1 ? matched.single : -1;
  }
  return -1;
}
