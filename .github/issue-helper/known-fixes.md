# Known fixes (the owner's rules for the issue helper)

The issue helper reads this file before it answers. When an issue matches an entry, it gives that
fix in its reply. Add an entry for any problem users can fix themselves: what the user sees, how to
recognise it (in the issue or the Send log), and the exact steps. Menu paths must match the app.

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
