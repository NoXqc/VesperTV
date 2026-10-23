# Profile cards, photos and starting from Main (Codex, 2026-10-23)

Implements PROPOSAL.md sections 1–4; section 4b is the preceding season-watched
commit. Local work only, version unchanged at 1.0.37+418. Native builds and real
Formuler/phone/Windows acceptance remain for the owner.

Home profiles are portrait cards in a non-lazy horizontal scroller. Focus grows
the card and adds a white border; active is theme gold. OK switches as before;
hold OK/touch long-press opens the new editor. The Add card opens creation directly
and focuses the newly created card on return without switching viewers. Editing
and adding from a restricted active viewer use the existing PIN gate. The held
key is swallowed until a fresh press on the editor route. Existing switchTo and
applyActiveViewer behavior is unchanged.

Creation shows a live preview beside the form on wide screens, above it on phones:
name, colour, Kids/PIN, optional photo with Skip, Main-copy choices, Create.
Kids status is fixed at creation. Editing offers inline name save, photo/colour,
Kids PIN, one summary row per playlist leading to the existing visibility screens,
switch, and a visible Delete row. Main/active deletion is disabled with a reason.
The existing visibility screens still require switching to the edited viewer.
The unused profile_picker_screen.dart is removed.

Photos use PairingKind.photo and PhonePairPanel on the LAN only. The phone page
centre-crops and downsizes to 512 JPEG in its canvas before sending. Local files
on Windows/phones use Flutter's file_selector (no broad storage permission).
Both paths accept JPEG/PNG up to 2 MiB, decode-check dimensions (maximum 16 MP),
crop/resize and write canonical 512 JPEG in an isolate. Files are in app support
profiles/<id>.jpg, never preferences. photoVersion defaults to zero in old JSON;
changes evict the file image cache. Deletion removes the photo and pending file.
No cloud avatar host or relay deployment is involved. Explicit user-initiated
Backup/Transfer include base64 photos; internet Transfer retains its existing
encryption. Missing or invalid photos restore to the colour/initial fallback.

Main copying is opt-in and happens before the new viewer is persisted/opened.
ProfileCopy's single allowlist table uses AppConstants, excludes all viewer-suffixed
keys and cannot copy credentials/device settings. Favourites includes live order,
movies/shows, favourite groups and Hub favourites. History includes all position,
duration/fraction keys, last channel, Hub history and the recently-played cache.
Sports includes leagues/order, star, teams, picks, networks/lists and spoilers.
Visibility includes hidden groups/channels/playlists, own groups and manual order;
it is unavailable for Kids and never copies an allowlist. Home copies row layout.
Everything/None affect these five choices only; defaults are None.

Two prerequisite isolation fixes overlap Claude's pending checkout: Hub history,
favourites and recent-search keys now use _vk (Main unchanged), and PlaybackService
clears its previous list when a new viewer has no recently-played file. The transfer
Archive filter recognises suffixed keys. Review these overlaps when integrating
Claude's work; his checkout was not edited. No attempt was made to investigate
the separate startup empty-channels report.

Tests cover each copy option/Main independence, photos/files/backward compatibility,
backup/transfer, real LAN rejection and upload, empty-history reload, phone/wide
layouts, remote/touch hold, editing, no-switch creation, PIN gate and season menu.
The LAN handler drains oversized bodies without buffering them, so a rejected
upload receives HTTP 400 and the session can accept a subsequent valid photo.

Season marking sets every loaded episode of that season through one local helper,
clears fraction markers, uses duration or a 1 ms stand-in, refreshes once and shows
one snackbar. Single-season shows also have a chip. TrackerSync sends one season
history request per connected account (Trakt/Simkl), with exact episode numbers.
The same screen handles IPTV and Media Hub; no title matching was added.
