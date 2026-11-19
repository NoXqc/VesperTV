import 'package:flutter/foundation.dart';

import '../models/catchup.dart';
import '../models/channel.dart';
import 'catchup_session.dart';
import 'dispatcharr.dart';
import 'storage_service.dart';

/// Which Xtream catch-up link a playlist gets: `.m3u8` (HLS: exact start,
/// cheap seeks, a finite recording; dev-notes/catchup-plan.md) or `.ts`.
///
/// `.ts` when the playlist learned it, saved on this device
/// ([StorageService.getCatchupTsPlaylists]): its panel refused the `.m3u8`
/// link, or gave no picture within [hlsPatience] (LOG-76X9CH, 2026-11-19:
/// a panel that builds the HLS archive on demand kept a Fire TV waiting
/// 12-44 s, where TiviMate's `.ts` link starts at once). Also when the
/// channel is on the signed-in Dispatcharr: its `/timeshift/` serves `.ts`
/// only (`.m3u8` = 404 "Channel not found", 0.34.1).
///
/// Shared by the Android player ([PlaybackService]) and the desktop / iOS
/// one (`DesktopCatchup`).
class CatchupFormat {
  CatchupFormat(this._storage);

  final StorageService _storage;

  /// How long a `.m3u8` request may go without a picture before the same
  /// request is asked again as `.ts`. A fast panel answers in 1-2 s.
  static const hlsPatience = Duration(seconds: 4);

  /// Learned this run too (saving can fail: storage not ready in tests).
  final Set<String> _learned = {};

  Set<String> _saved() {
    try {
      return _storage.getCatchupTsPlaylists();
    } catch (_) {
      return const {};
    }
  }

  bool usesTs(Channel live) =>
      _learned.contains(live.playlistId) ||
      _saved().contains(live.playlistId) ||
      Dispatcharr.instance.refOf(live) != null;

  String extFor(Channel live) => usesTs(live) ? 'ts' : 'm3u8';

  /// Remembers `.ts` for [playlistId] on this device; false when it already
  /// had it.
  bool learnTs(String playlistId, String why) {
    final saved = _saved();
    if (_learned.contains(playlistId) || saved.contains(playlistId)) {
      return false;
    }
    _learned.add(playlistId);
    debugPrint('Catchup: this playlist asks .ts from now on ($why)');
    try {
      _storage.setCatchupTsPlaylists({...saved, playlistId});
    } catch (_) {}
    return true;
  }

  /// [s] is an Xtream `.m3u8` request: worth watching for a slow start.
  static bool isHls(CatchupSession s) =>
      s.live.catchupKind == CatchupKind.xc &&
      (Uri.tryParse(s.channel.url)?.path.endsWith('.m3u8') ?? false);

  /// How much already-played catch-up the Android player keeps, so −10 /
  /// rewind replays it from memory. Without it (LOG-EVPPYN, Fire TV,
  /// 2026-11-19) every −10 asked the slow `.ts` panel again and froze
  /// 12-17 s, while +10 (already downloaded) came back in 0.2 s. 30 s is
  /// ~15-30 MB at TV bitrates, inside the low-RAM 64 MB buffer budget.
  static const backBuffer = Duration(seconds: 30);

  /// [url] is a catch-up (archive) request: Xtream `/timeshift/…` and
  /// `timeshift.php`, Flussonic `timeshift_abs-…`.
  static bool isArchiveLink(String url) =>
      Uri.tryParse(url)?.path.toLowerCase().contains('timeshift') ?? false;

  /// `.ts` or `.m3u8`, for Send log.
  static String extOf(CatchupSession s) {
    final path = Uri.tryParse(s.channel.url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    return dot < 0 || dot < path.lastIndexOf('/') ? '-' : path.substring(dot);
  }
}
