/// Display metadata for the selected Media Hub stream. No playable URLs or tokens.
class MediaFileInfo {
  const MediaFileInfo({required this.source, this.sizeBytes});
  final String source;
  final int? sizeBytes;

  String? get formattedSize => formatSize(sizeBytes);

  /// Shared decimal units for source metadata and the playing file's headers.
  static String? formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    var value = bytes.toDouble();
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var unit = 0;
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1000;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}
