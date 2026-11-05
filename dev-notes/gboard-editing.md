# TV text editing and Gboard (Codex, 2026-11-04)

Owner report: on Google TV Streamer, holding a CMU/EMU game, choosing a
different channel, selecting ESPN2, then trying to insert a space caused
continuous Left movement, reportedly even after Home. A second report mentioned
Add Playlist. No Google TV/Gboard device was connected for this investigation.

## Verified locally

The shared `TvTextFieldGate` treated any arrow received while typing on a
non-Amazon device as evidence that the keyboard had closed. It immediately made
the field read-only, hid the keyboard and moved focus. Its selection-action
overrides also converted editing intents into focus traversal while typing.
Both inset and zero-inset widget regressions failed against that behavior.

An arrow reaching Flutter does not prove keyboard dismissal. Android exposes
[`InputMethodService.sendDownUpKeyEvents`](https://developer.android.com/reference/android/inputmethodservice/InputMethodService#sendDownUpKeyEvents(int))
for IMEs to forward key pairs to their input connection. Flutter also calls
[all raw hardware-key handlers](https://api.flutter.dev/flutter/services/HardwareKeyboard/addHandler.html)
regardless of their return values, so screen-level handlers must yield too.

## Behavior

- While editing a gated TV field, arrows and selection intents remain available
  for editing. `TvTextFieldGate.isEditing` and `TvNavigationActivator` make the
  affected screen handlers/shortcuts yield: Sports channel picker, Add Playlist,
  Search, Multiview channel picker, Channel linking and EPG channel matching.
- After a positive keyboard inset disappears, or the field loses focus (including
  submission to another control), the field becomes read-only again and arrows
  navigate as before. Fire OS's existing no-extra-hide handling is retained.
- For overlay keyboards that never report an inset or focus loss, Back delivered
  to the app ends editing and hides the keyboard before leaving the page. If the
  IME consumes the first Back without reporting dismissal, a second Back is
  needed before arrows resume navigation. Arrows are no longer used to guess
  that dismissal happened. OK/Select can reopen the keyboard.
- Backgrounding ends editing and cancels delayed hides. Deferred hides/focus
  recovery run only on the current route while resumed. `inactive` alone does
  not end editing: the TV IME may temporarily own window focus.
- Phone/desktop fields retain normal editing. No native input injection,
  keyboard polling, keyboard replacement, logging of text, or new permissions.

## Verification and remaining device check

`tv_text_field_gate_test.dart` covers inset/no-inset cursor movement, held Left
repeat/release, explicit Back recovery, background lifecycle and delayed-hide
cancellation, plus existing read-only traversal and phone behavior.
`add_playlist_gboard_left_test.dart` covers editing arrows followed by Back and
pane navigation. `sports_mode_test.dart` opens the actual game menu/picker,
selects ESPN2, inserts the space, keeps Down in editing, then reaches results
after editing ends, with and without an inset.

These are Flutter widget simulations, not execution of Gboard. They establish
an app-side conflict, not the cause of repeating Left outside the app. No native
player/Android controller changes were made. Physical Google TV Streamer or
Chromecast QA is still required; also recheck Fire OS overlay-keyboard recovery.

Device check: repeat the reported game-menu flow, move the caret through ESPN2,
insert a space, move around Gboard and release the remote buttons; dismiss with
Back and navigate to a result. Repeat in Add Playlist and Search. Try Home during
editing, then return: the keyboard should not reopen by itself. If continuous
Left persists outside VesperTV, capture device/Android/Gboard versions and key
down/up timing without text, credentials or tokens, and investigate separately.
