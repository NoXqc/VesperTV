/// Maps a decoded video track's real size to the usual consumer label:
/// 720p = HD, 1080p = FHD (Full HD), 2160p = 4K - read off the playing
/// stream's selected track, never guessed from a channel's name
/// (providers routinely tag a channel "4K" or "UHD" that never decodes
/// above 1080p). Frame rate has its own pill beside it. Until 2026-11-06
/// 1080p was "HD" below 40 fps and "FHD" at 50/60, and 720p had no badge
/// (owner: not the standard).
///
/// Null below 720p.
///
/// [width] counts too: a film is usually wider than 16:9, so a 4K movie is
/// 3840x1600 and a 1080p one 1920x800 - by height alone they read lower
/// (user report, 2026-10-21: a 4K Media Hub stream showed HD).
/// The width bars sit a little under the nominal 3840/1920/1280 for crops.
String? qualityLabelForTrack({required int height, int? width}) {
  final w = width ?? 0;
  if (height >= 2160 || w >= 3800) return '4K';
  if (height >= 1080 || w >= 1900) return 'FHD';
  if (height >= 720 || w >= 1260) return 'HD';
  return null;
}
