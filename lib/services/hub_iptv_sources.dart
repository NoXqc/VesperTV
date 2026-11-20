import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/archive_models.dart';
import '../models/channel.dart';
import '../models/xtream_series.dart';
import '../utils/display_title.dart';
import 'archive_discovery_service.dart';
import 'playlist_manager.dart';

/// Media Hub's Sources list can also offer the same movie / episode from
/// the viewer's IPTV playlists (Settings > Player > Movies & TV Shows >
/// IPTV copies in Sources; asked for by a Plex user, 2026-11-20). Plugged
/// into `ArchiveService.searchStreams` as one more source ([ArchiveService
/// .iptvStreams]), so the picker, Resume, Next episode and the player's
/// Sources tab treat it like any add-on.
///
/// A copy matches by TMDB id when both sides have one (a different id
/// rules it out), else by cleaned title ([ArchiveDiscoveryService
/// .titleKey]) and year (one year apart at most) when both have a year.
/// Only enabled playlists, through the viewer-aware searches (a restricted
/// profile never sees a hidden group's titles here either).
class HubIptvSources {
  HubIptvSources(this._playlists);

  final PlaylistManager _playlists;

  /// Copies offered at most, per title.
  static const maxCopies = 8;

  /// Shows whose episode lists are fetched at most (one request each).
  static const maxShows = 4;

  Future<List<ArchiveStream>> streams(
      ArchiveMeta meta, ArchiveVideo? episode, bool Function() active) async {
    final query = cleanDisplayTitle(meta.name).trim();
    if (query.isEmpty) return const [];
    final ids = [
      for (final p in _playlists.profiles)
        if (p.enabled) p.id,
    ];
    if (ids.isEmpty) return const [];
    final names = {for (final p in _playlists.profiles) p.id: p.name};
    final tmdb = tmdbOf(meta);
    final year = yearOf(meta.year);
    final key = ArchiveDiscoveryService.titleKey(meta.name);
    final copies = <Channel>[];
    if (meta.type == ArchiveType.movie) {
      final rows = await _playlists.searchVisibleVod(query, ids, limit: 60);
      for (final c in rows) {
        if (matches(
            key: key,
            tmdb: tmdb,
            year: year,
            name: c.name,
            otherTmdb: c.tmdbId,
            otherYear: c.releaseDate?.year ?? _yearInName(c.name))) {
          copies.add(c);
        }
      }
    } else {
      if (episode == null) return const [];
      final rows = await _playlists.searchVisibleSeries(query, ids, limit: 60);
      final shows = <XtreamSeries>[
        for (final s in rows)
          if (matches(
              key: key,
              tmdb: tmdb,
              year: year,
              name: s.name,
              otherTmdb: s.tmdbId,
              otherYear: s.releaseDate?.year ?? _yearInName(s.name)))
            s,
      ].take(maxShows);
      final found = await Future.wait([
        for (final show in shows)
          _playlists
              .loadSeriesEpisodes(show)
              .timeout(const Duration(seconds: 15))
              .then<Channel?>((r) {
            for (final c in r.episodes[episode.season] ?? const <Channel>[]) {
              final number = r.details?.episodes[c.id]?.episodeNumber ??
                  episodeInName(c.name);
              if (number == episode.episode) return c;
            }
            return null;
          }).catchError((Object e) {
            debugPrint(
                'HubIptvSources: ${show.playlistId} episodes failed: $e');
            return null;
          }),
      ]);
      copies.addAll(found.whereType<Channel>());
    }
    if (!active()) return const [];
    final seen = <String>{};
    return [
      for (final c in copies)
        if (c.url.isNotEmpty && seen.add(c.url))
          ArchiveStream(
            url: c.url,
            name: ['IPTV', ...qualityTagsOf(c.name)].join(' '),
            title: [
              c.name,
              if (names[c.playlistId] case final playlist?) playlist,
            ].join('\n'),
            requestHeaders: c.httpHeaders,
          ),
    ].take(maxCopies).toList();
  }

  /// [meta]'s TMDB id from a `tmdb:123` id (AIOMetadata and the like).
  static String? tmdbOf(ArchiveMeta meta) =>
      RegExp(r'^tmdb:(\d+)').firstMatch(meta.id)?.group(1);

  /// The first year in "2022", "2019–2023" or "2022-05-01".
  static int? yearOf(String? text) {
    final m = RegExp(r'(19|20)\d{2}').firstMatch(text ?? '');
    return m == null ? null : int.parse(m.group(0)!);
  }

  /// The episode number in "S1E3 — Title" (the app's own episode names) or
  /// a provider's "S01E03" / "1x03", when the details don't give one.
  @visibleForTesting
  static int? episodeInName(String name) {
    final m =
        RegExp(r'(?:[Ss]\d{1,3}\s*[Ee]|\b\d{1,2}x)(\d{1,4})').firstMatch(name);
    return m == null ? null : int.parse(m.group(1)!);
  }

  /// A year the provider put in brackets: "Violent Night (2022)".
  static int? _yearInName(String name) {
    final m = RegExp(r'[(\[]((19|20)\d{2})[)\]]').firstMatch(name);
    return m == null ? null : int.parse(m.group(1)!);
  }

  @visibleForTesting
  static bool matches({
    required String key,
    required String? tmdb,
    required int? year,
    required String name,
    required String? otherTmdb,
    required int? otherYear,
  }) {
    final other = otherTmdb?.trim();
    if (tmdb != null && other != null && other.isNotEmpty) {
      return other == tmdb;
    }
    if (key.isEmpty || ArchiveDiscoveryService.titleKey(name) != key) {
      return false;
    }
    return year == null || otherYear == null || (year - otherYear).abs() <= 1;
  }
}
