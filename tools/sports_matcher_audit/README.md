# Sports matcher audit (development only)

Nothing in this directory is imported by the app. No production matcher change,
build, installation, account alteration or stream playback is part of this workflow.
The committed measurements are in `dev-notes/sports-matcher-audit/`.

## Run on the owner's Windows checkout

From repository root, after `flutter pub get`:

```powershell
python tools/sports_matcher_audit/collect.py --owner --config C:\private\audit-accounts.json
python tools/sports_matcher_audit/owner_visibility.py
python tools/sports_matcher_audit/run.py
python tools/sports_matcher_audit/report.py
```

The optional private JSON file is an array of objects with `label`, `server`,
`username`, `password` and optional `epgUrl`. Use anonymous stable labels, never
put credentials in arguments or committed files. `--owner` reads only local playlist
configuration, selecting enabled profiles and the saved `dom OG` Strong8K test account.
`owner_visibility.py` reads active-viewer hide settings and generates an additional
visible-only catalogue. It does not edit the installed app's settings or EPG database.
This audit's Main viewer had no own groups; custom moves/kid allowlists need additional
reconstruction before claiming parity on another profile. M3U-only collection is not
implemented: the measured owner/test profiles are Xtream.

`collect.py` requests only `get_live_streams` and XMLTV, and visibility reconstruction
requests `get_live_categories`. It never calls `/live/` or opens a playback URL.
It streams XMLTV into a local SQLite file, restricted to known ids and a rolling
−7/+8 day window. It intentionally preserves more history than the app. XMLTV
timestamps must include seconds and a numeric offset. Multiple title/description
languages use the first entry; the app parser can concatenate repeated tags, so
multilingual duplicate-tag parity is not guaranteed. Failed sources are recorded
without exception bodies/URLs; inaccessible accounts have no fabricated results.

Snapshots, login config, generated runner, network JSON, logs and intermediate data
stay in ignored `.dart_tool/matcher-audit/`. Channel snapshots contain no playback
URLs, account responses, server URLs or authentication fields. Programme descriptions
are retained for the experiments. Keep snapshots local; do not add this directory to Git.
Rerunning the collector replaces each snapshot; `run.py` reuses captured schedule JSON.
To measure a fresh schedule, move/remove only the audit's `schedule` cache yourself.
The scripts do not delete application data or run against the live EPG database.

## How the runner stays tied to real code

`run.py` copies `lib/services/sports_channel_matcher.dart` into an ignored runner,
rewrites relative imports to package imports, appends `runner.dart.inc`, and runs it
with `flutter test`. The baseline implementation is otherwise unchanged. SHA-256
of the source is saved in `matcher.sha256`. Private helper access works because the
diagnostic code is appended to the same Dart library. Do not hand-edit the generated copy.

The adapter subclasses EpgService and executes the production query predicates,
400-term LIKE chunks and column-to-programme conversion against snapshot SQLite.
Baseline description fields do not affect matching. SportsService reads real ESPN/CFL
payloads through its existing testing constructor; picks use isolated mock preferences.
The fixed fixture range is Oct 19–25, 2026, in the machine's local timezone (Toronto
for these results); change the range in `runner.dart.inc` for another audit.

Modes, all confined to this runner:

- `baseline`: original matcher and title SQL against raw provider coverage.
- `normalized`: normalized whole-window title retrieval, same final matching rules.
- `description`: naive title/description concatenation, intentionally includes negative examples.
- `guarded-description`: excludes identified multiplex/replay/news patterns, requires one
  simultaneous fixture and explicit compatible sport. An experimental precision screen.
- `network-aliases`: supplements original results with five curated broadcaster aliases;
  preserves network score, per-broadcaster cap, region exclusions and final eight limit.
  Requires US tagging and exact canonical network identity (optional provider `(D)`
  decoration). Excludes Plus/alternate/dated event services and USA Network West;
  allows the generic US/East USA service. Separate from the production map.
- `app-window`: baseline plus the installed app's −2h/+36h ingestion retention at capture time.

Each day is run with limit 8 and unlimited. A cache assertion requires seven scans,
not fourteen. Unlimited output still has production's per-network cap. The second
test exercises wrong-sport, replay and multiplex description counterexamples, raw SQL
accent loss, middle-channel rename stale indexing, and country/alternate alias guards.

`report.py` exports baseline per-game channels and evidence, empty results, channel
deltas and aggregate markdown. The primary summary labels reflect this captured run;
adjust its `primary` set for different sources. Alias/description additions are proposals
requiring adjudication, not a certified live broadcast ground truth. No tune/probe is done.
