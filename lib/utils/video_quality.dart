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
/// Both bars sit under the nominal sizes for crops: a 4K IMAX-ratio film
/// (1.50:1) is 3236x2156, a few lines short of 2160 and far from 3840 wide
/// (owner's photo, 2026-11-11: showed FHD). A 1080p picture never reaches
/// 2000 lines or 3600 columns, so a crop can't promote it.
String? qualityLabelForTrack({required int height, int? width}) {
  final w = width ?? 0;
  if (height >= 2000 || w >= 3600) return '4K';
  if (height >= 1040 || w >= 1800) return 'FHD';
  if (height >= 700 || w >= 1200) return 'HD';
  return null;
}
