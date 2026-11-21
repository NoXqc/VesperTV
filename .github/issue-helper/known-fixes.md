# Known fixes (the owner's rules for the issue helper)

Optional. The issue helper finds fixes on its own: it searches the app's settings, each playlist's
options and the player's buttons for something that fixes or avoids the problem, and matches them to
the Send log (issue-helper.yml). This file only holds fixes the owner has already confirmed, so they
are given the same way every time. Nothing needs to be added for the helper to suggest a setting.

## Live channels stutter or freeze with HLS on (owner, 2026-11-21)
- **The user sees:** live channels stutter, freeze every few seconds, or the picture and sound
  glitch, on a playlist where HLS is turned on.
- **In the Send log:** `StreamFormat: HLS (playlist setting)` near the channel, often with many
  `Unexpected start code prefix` lines (the provider's HLS pieces are damaged; plain TS is fine).
- **Kind:** user_error (setting). Not an automatic fix.
- **Reply with:** please turn HLS off for that playlist:
  1. Settings > Playlists & sources > Playlist Manager
  2. Pick the playlist
  3. Turn off **Live stream format: HLS**
  It applies from the next channel you open. (Only Xtream playlists have this switch.)
