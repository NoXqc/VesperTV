# External storage imports (2026-10-25)

Settings > Backup & restore > Import from storage adds files without replacing
existing playlists, viewer profiles or settings. The owner clarified: M3U
playlists and included Media Hub sources, not a standalone local-video library.

- Browse mounted drives on Windows / accessible storage on Android. On scoped
  Android storage use Choose a folder (system tree picker); retain its read grant
  across restarts. Older Fire OS devices without a picker can use the in-app
  browser wherever their storage permission permits reading. No device UI was
  driven during implementation.
- Import `.m3u` / `.m3u8` channel playlists as private snapshots, loaded through
  the existing M3U session path. Stream parsing avoids a whole-file allocation.
  Relative file paths resolve against the selected folder, including child
  documents inside an Android folder grant. Local media references still need
  their storage connected. HLS segment manifests are not channel catalogs.
- Media Hub manifest links can be included in M3U comments or imported from
  `.txt` / `.json`: plain link lists, source definitions, Stremio exports or the
  nested source JSON in a VesperTV backup. Configuration files are capped at
  16 MiB; M3U imports use streamed reads. No new standalone local-video library.
- Validate source manifests sequentially, skip already-added sources, save valid
  sources together through ArchiveService; report added/existing/unreachable
  counts. Custom types retain their normal Other-filter behavior. No source
  content is opened or sampled, and this flow never logs configured source URLs.
- Cancel precedes any import reads/writes. Invalid input removes only its private
  temporary files; a failed new playlist load rolls back that new entry. Existing
  setup remains intact. The external original is never modified or deleted.
- Imported M3U snapshots accompany backup/transfer payloads as streamed gzip/base64
  under `vesper_imported_playlists`, keyed by playlist ID; restored snapshots get
  fresh private paths. Other preferences/Media Hub source backup behavior stays
  unchanged. External media and Android folder permissions are not transferable.
  Restore limits expanded snapshots to 256 MiB. Deleting a playlist removes only
  its private snapshot, with canonical path containment checks.

Implementation: `StorageImportScreen`, `StorageImportService`, `LocalPlaylistFiles`,
`LocalImportStore.kt`; MainActivity method-channel/result plumbing, existing
M3U parser/local-file controller support and backup/transfer envelope helpers.
No vendored player changes or new package dependencies.

Tests use synthetic files and sources: local/HTTP entries, source-link deduplication,
nested JSON, included links, invalid-file cleanup, backup/transfer rehydration,
external-original protection, Android document references, and cancel/add UI paths.
Android Kotlin compile and full analyze/test checks precede packaging. USB hardware
and actual folder-picker acceptance remain for the owner to verify on a device.
