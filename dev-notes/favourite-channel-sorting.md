# Mixed favourite channel sorting (Codex, 2026-11-07)

Hold OK on a live channel inside Favourites, with Mix playlists in Favourites
enabled, offers Sort favourites: Name A–Z, Name Z–A, Revert to original order.
The same getter feeds the plain list and Timeline, including filtered guide rows.
Movies/TV Shows, provider groups and the Mix playlists setting are unchanged.

`FavoriteLiveSort` is stored in `vesper_favorite_live_sort`, scoped per viewer.
Original (also the fallback for missing/unknown values) keeps existing behavior:
manual `vesper_favorite_live_order` wins, else the pre-existing mixed default.
Choosing A–Z/Z–A sorts all currently visible favourite channels by display name,
including favourited-group channels. Equal folded names retain their source order.
It never changes the saved manual list or provider/group order, so Revert restores
that arrangement even after restart. New favourites automatically enter the chosen
alphabetical view. Mix off ignores the stored alphabetical mode without deleting it.

Move Up / Down while an alphabetical view is active snapshots the displayed order
into the manual order, preserving unavailable ids in their saved slots, swaps the
two visible neighbours, and returns to Original/manual mode. Both writes use the
captured viewer id. A no-op move at a boundary changes neither mode nor order.

Storage reads happen on use; no extra AppPreferences cache. The key is eligible
for live cloud sync and ProfileCopy.favourites, plus existing Backup/Transfer rules.
The sort popup checks viewer, selected group and mixing before applying a choice.
Cancelling has no effect. After applying, the first visible row receives focus;
Timeline respects its current filter. No playback or native changes.

Tests extend `favorite_live_order_test.dart` and `tv_favourites_entry_test.dart`:
reversible cross-playlist/group ordering, stable ties/renames/new favourites,
manual moves from sorting with unavailable ids, restart/Backup/Transfer/profile
copy, malformed values, both layouts' actual visual row order and hold menus,
mixing-off/provider-group exclusions, cancel and viewer-switch guards.

New UI strings are in EN/FR/ES/IT/EL/DE. The remote guide and generated help index
are updated locally. Real-device appearance/navigation still needs owner testing.
