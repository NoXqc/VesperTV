# Catalog save speed (Update Content / Add Playlist), 2026-11-23

## Report
uzumaki (Discord, the Tuliprox developer; Linux, 2026-11-22): "loading the playlist is extremely slow" = the Update
Content and Add Playlist progress (owner). His Send log: Xtream, 21,180 live, 163,760 movies, 43,771 shows,
`SlowDb: upsertVod n=1610 541ms` (about 0.35 ms per movie), `StartupTiming playlistInit=+5046ms`.

## How Update Content saves movies / shows (Xtream)
`PlaylistSession._warmCategories`: up to 3 movie + 3 show categories at a time (`_categoryConcurrency`, the account's
max connections, capped at 3); each one `get_vod_streams` / `get_series` for the category, then
`CatalogDatabase.upsertVodCategory` / `upsertSeriesCategory` (one batch: delete the category's rows, insert each).
The M3U import already used `_insertMany` (many rows per INSERT); the Xtream path saved one row per statement.

On Windows / Linux every sqflite database (catalog + guide) goes through ONE background isolate of
`sqflite_common_ffi` (`databaseFactoryFfi`, a global `SqfliteIsolate`), one call at a time: a long save holds up every
read, the guide's too. macOS / iOS / Android use the plugin's native SQLite.

## Benchmarks (`tool/bench/`, not part of `flutter test`)
- `catalog_write_bench_test.dart`: saves a catalog of uzumaki's size through `CatalogDatabase` the way the warm-up
  does while a reader asks a count every 25 ms. `BENCH_MODE` shared (today) / direct (no isolate) / split (writes on
  their own isolate + connection, `databaseFactoryFfiNoIsolate`, WAL lets reads go on). `BENCH_SCALE` 0.25 etc.
- `catalog_insert_bench_test.dart`: the database alone (rows built beforehand, no isolate): one INSERT per row vs
  many per INSERT, with / without the two redundant indexes.
- Linux runs: Docker image `vesper-bench:latest` (cirruslabs flutter stable 3.44 + this code, `flutter pub get`
  done), `docker run --cpus=<n>` to stand in for a slower computer (owner's 9800X3D at 0.2 CPU ~= uzumaki's batch
  times). Scripts in the session scratchpad: `bench.sh <cpus> <mode> <scale>` copies `lib/` + `tool/bench` in.

Results (Linux container):

| | full speed | 0.2 CPU |
|---|---|---|
| per movie, Windows (no cap) / Linux | 51 / 26 us | 128 us (incl. test data) |
| database only: today | 17 us | 15.8 s first fill, biggest batch 570 ms |
| database only: fewer indexes | 14 us | 13.5 s |
| database only: many rows per INSERT (100) | 10 us | 7.1 s, biggest 120 ms |
| database only: both | 9 us | 6.5 s, biggest 120 ms (refresh 7.2 s) |
| app path (shared isolate) old -> new, summed save time | - | 21.4 s -> 15.8 s (0.5 CPU: 7.5 -> 5.3 s) |
| app path, worst read wait old -> new | - | 408 -> 303 ms (0.5 CPU: 142 -> 88 ms) |
| reads, today vs writes on their own isolate (old code) | - | p95 200 / max 481 ms vs p95 73 / max 76 ms |

Chunk 25..400 rows per INSERT: 31-35 us at 0.2 CPU; `_insertMany` uses 999 ~/ columns (Android < 11 SQLite caps a
statement at 999 bound values). Building a row in Dart (`vodRow` + search key) is ~15 us at 0.2 CPU (key ~5 us).

## What changed
- `_upsertVodCategory` / `_upsertSeriesCategory` use `_insertMany` (same INSERT OR REPLACE semantics).
- After the covering `(playlist_id, category_name)` indexes exist, `idx_vod_category`, `idx_vod_playlist`,
  `idx_series_category`, `idx_series_playlist` are dropped (every query filters by playlist + category or by
  playlist; `test/catalog_index_test.dart` checks the plans). onCreate / old migrations still make them on an empty
  table; the next open drops them.
- Send log `CatalogSync: done/total categories, N titles in X s (k at a time; downloads A s, saves B s, summed)` at
  the end of each movie + show pass: says whether downloading or saving is the slow half.

## Why the app path gains only ~25-30% (vs 2.4x for the database)
On Windows / Linux most of what is left per movie is handing the rows to the sqflite isolate (a deep copy of the
batch) and building them on the UI isolate; SQLite itself is now the smaller part. Android's plugin pays a similar
per-statement cost through its platform channel (the M3U import's 13 min -> fast on a Formuler, LOG-24KKHW), so the
gain there is likely larger; not measured.

## Next, if the progress is still slow
1. Read uzumaki's `CatalogSync:` line: if downloads dominate, the server / network is the limit (790 requests).
2. Bigger fix for computers: do a category's download + JSON parse + save in a background isolate with its own
   connection (like `M3uImport`), handing back only the first rows for the screen. Also frees the UI isolate.
3. The split writer alone (reads never wait) helps the guide / Movies pages during a sync, not the progress time.
