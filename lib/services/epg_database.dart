import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// One programme row as stored in [EpgDatabase] — times are epoch
/// milliseconds (UTC), so reading a row back never goes through
/// `DateTime.parse` (the old JSON cache paid ~430k of those per cold start).
typedef EpgRow = ({
  String channelId,
  int startMs,
  int stopMs,
  String title,
  String? description,
});

/// On-disk EPG store — replaces the single big JSON cache file that
/// `EpgService.init()` used to fully decode on every cold start (measured
/// ~58 s on a Formuler before the guide appeared). The guide is now only
/// ever *queried* for the channels actually on screen, the same way the
/// VOD/series catalog moved into [CatalogDatabase].
///
/// Only a rolling window is kept (see `AppConstants.epgPastRetention` /
/// `epgFutureWindow`) — the past side is a constant on purpose so a later
/// catch-up feature can simply widen it.
///
/// Fully re-derivable from the EPG URLs, so a database that won't open is
/// deleted and recreated rather than surfaced as an error.
class EpgDatabase {
  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    // Application *support* dir, not the temporary/cache dir the old JSON
    // file lived in: Android may purge the cache dir at any time, which
    // left the guide empty until the next refresh.
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'vesper_epg.db');
    try {
      _db = await _open(path);
    } catch (e) {
      debugPrint('EpgDatabase: reopening from scratch after $e');
      await deleteDatabase(path);
      _db = await _open(path);
    }
    return _db!;
  }

  Future<Database> _open(String path) => openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // (channel_id, start) is the natural key and also exactly the
          // lookup every read does — WITHOUT ROWID stores rows in that
          // order, so "programmes for these channels" is an index range
          // scan with no extra table lookup.
          await db.execute('''
            CREATE TABLE programme (
              channel_id TEXT NOT NULL,
              start INTEGER NOT NULL,
              stop INTEGER NOT NULL,
              title TEXT NOT NULL,
              descr TEXT,
              source_url TEXT NOT NULL,
              gen INTEGER NOT NULL,
              PRIMARY KEY (channel_id, start)
            ) WITHOUT ROWID
          ''');
          await db
              .execute('CREATE INDEX idx_programme_stop ON programme(stop)');
          await db.execute(
              'CREATE INDEX idx_programme_source ON programme(source_url, gen)');
        },
      );

  Future<void> open() async => _database;

  /// Every programme for [channelIds] that hasn't ended before [minStopMs],
  /// ordered by channel then start. Chunked to stay under SQLite's bound
  /// parameter limit.
  Future<Map<String, List<EpgRow>>> programmesFor(
      List<String> channelIds, int minStopMs) async {
    final db = await _database;
    final result = <String, List<EpgRow>>{};
    const chunk = 500;
    for (var i = 0; i < channelIds.length; i += chunk) {
      final ids = channelIds.sublist(
          i, i + chunk > channelIds.length ? channelIds.length : i + chunk);
      final placeholders = List.filled(ids.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT channel_id, start, stop, title, descr FROM programme '
        'WHERE channel_id IN ($placeholders) AND stop > ? '
        'ORDER BY channel_id, start',
        [...ids, minStopMs],
      );
      for (final r in rows) {
        final id = r['channel_id'] as String;
        (result[id] ??= []).add((
          channelId: id,
          startMs: r['start'] as int,
          stopMs: r['stop'] as int,
          title: r['title'] as String,
          description: r['descr'] as String?,
        ));
      }
    }
    return result;
  }

  /// Every channel's programmes overlapping [fromMs, toMs) — the small
  /// "now / next" slice `EpgService` preloads for *all* channels at startup
  /// (a few rows per channel instead of the whole window).
  Future<Map<String, List<EpgRow>>> programmesBetween(
      int fromMs, int toMs) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT channel_id, start, stop, title, descr FROM programme '
      'WHERE stop > ? AND start < ? ORDER BY channel_id, start',
      [fromMs, toMs],
    );
    final result = <String, List<EpgRow>>{};
    for (final r in rows) {
      final id = r['channel_id'] as String;
      (result[id] ??= []).add((
        channelId: id,
        startMs: r['start'] as int,
        stopMs: r['stop'] as int,
        title: r['title'] as String,
        description: r['descr'] as String?,
      ));
    }
    return result;
  }

  Future<int> count() async {
    final db = await _database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM programme');
    return rows.first['n'] as int;
  }

  /// Distinct channel ids that still have any programme ending after
  /// [minStopMs] — the "does this channel have EPG at all" answer for
  /// callers that need it for every channel at once (auto-pair).
  Future<Set<String>> channelIdsWithData(int minStopMs) async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT channel_id FROM programme WHERE stop > ?',
        [minStopMs]);
    return {for (final r in rows) r['channel_id'] as String};
  }

  Future<bool> isEmpty() async {
    final db = await _database;
    final rows = await db.rawQuery('SELECT 1 FROM programme LIMIT 1');
    return rows.isEmpty;
  }

  /// Writes one batch of parsed rows in a single transaction. A re-sent
  /// programme (same channel + start) replaces the old row and takes the
  /// new [gen], which is what [deleteStaleFromSource] keys off.
  ///
  /// Two *different* sources covering the same channel + start overwrite
  /// each other's row ("last refresh wins") — harmless for display, and
  /// either source's next refresh puts its own version back.
  ///
  /// Keep batches small (~1000 rows): sqflite has one connection, so a
  /// long commit would stall the guide's reads behind it.
  Future<void> insertBatch(List<EpgRow> rows, String sourceUrl, int gen) async {
    if (rows.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final r in rows) {
      batch.rawInsert(
        'INSERT OR REPLACE INTO programme '
        '(channel_id, start, stop, title, descr, source_url, gen) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          r.channelId,
          r.startMs,
          r.stopMs,
          r.title,
          r.description,
          sourceUrl,
          gen
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  /// After a *successful* refresh of [sourceUrl]: drops every row that
  /// source wrote in an earlier refresh but didn't re-send this time
  /// (channel removed from the feed, programme rescheduled). Never touches
  /// another source's rows. A failed/aborted refresh skips this, so the
  /// previous data survives a network error.
  Future<void> deleteStaleFromSource(String sourceUrl, int gen) async {
    final db = await _database;
    await db.delete('programme',
        where: 'source_url = ? AND gen <> ?', whereArgs: [sourceUrl, gen]);
  }

  /// Rolling-window trim: drops programmes that ended before [minStopMs].
  Future<void> deleteEndedBefore(int minStopMs) async {
    final db = await _database;
    await db.delete('programme', where: 'stop < ?', whereArgs: [minStopMs]);
  }

  Future<void> clearAll() async {
    final db = await _database;
    await db.delete('programme');
  }
}
