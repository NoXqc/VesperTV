import '../l10n/l10n.dart';

/// HDR reported by the playing stream/decoder, never a guess at HDMI output.
class VideoHdrReport {
  static String label(Map stats) {
    final kind = stats['hdr'];
    final value = kind == 'dolby_vision' ? _dolbyVision(stats) : _kind(kind);
    if (!const {'dolby_vision', 'hdr10', 'hlg', 'sdr'}.contains(kind)) {
      return value;
    }
    return switch (stats['hdrSource']) {
      'stream' => tr('{format} (stream)', {'format': value}),
      'decoder' => tr('{format} (decoder)', {'format': value}),
      _ => value,
    };
  }

  /// Preserve conflicting output information instead of silently hiding it.
  static String? decoderDifference(Map stats) {
    final decoded = stats['decoderHdr'];
    final stream = stats['streamHdr'];
    if (!const {'dolby_vision', 'hdr10', 'hlg', 'sdr'}.contains(decoded) ||
        !const {'dolby_vision', 'hdr10', 'hlg', 'sdr'}.contains(stream) ||
        decoded == stream) {
      return null;
    }
    return _kind(decoded);
  }

  /// Dolby Vision with its profile and what a non-DV device falls back to
  /// (Samiam23: an "HDR" release showed only "Dolby Vision" — profile 8.1 is
  /// both). Profile 5 has no fallback; 7 and 8.1 carry HDR10, 8.4 HLG.
  static String _dolbyVision(Map stats) {
    final profile = stats['dvProfile'];
    if (profile is! int) return 'Dolby Vision';
    final base = stats['dvBase'] as String? ?? '';
    if (profile == 5) {
      return tr('Dolby Vision (profile {p}, no HDR10 fallback)', {'p': '5'});
    }
    if (base == 'hdr10' || profile == 7) {
      return tr(
          'Dolby Vision (profile {p}, HDR10 compatible)', {'p': '$profile'});
    }
    if (base == 'hlg') {
      return tr(
          'Dolby Vision (profile {p}, HLG compatible)', {'p': '$profile'});
    }
    return tr('Dolby Vision (profile {p})', {'p': '$profile'});
  }

  static String _kind(Object? kind) => switch (kind) {
        'dolby_vision' => 'Dolby Vision',
        'hdr10' => 'HDR10',
        'hlg' => 'HLG',
        'sdr' => tr('No (SDR)'),
        _ => tr('Unknown / not reported'),
      };
}
