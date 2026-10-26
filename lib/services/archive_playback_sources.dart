import '../models/channel.dart';
import 'archive_service.dart';

/// A title's available streams, scoped to its playback route and active viewer.
/// Channel IDs identify episodes, so opening the drawer after Next never offers
/// the previous episode's files. URLs stay in memory and are never UI labels.
class ArchivePlaybackSources {
  const ArchivePlaybackSources({
    required this.load,
    required this.current,
    required this.select,
    required this.remember,
  });

  final Future<List<ArchiveStreamOption>> Function(String channelId) load;
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
