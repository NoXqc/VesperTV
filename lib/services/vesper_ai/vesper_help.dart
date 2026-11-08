part of 'vesper_tools.dart';

// `vesper_help`: the manual an AI reads before using a tool in depth. It is
// served by the app, so it always matches what this TV's version can do.
// Keep each topic in step with its tool. English only (it's for the model).

/// Topic -> manual text (public for the docs-in-step test).
const vesperHelpTopics = <String, String>{
  'overview': '''
VesperTV tools act on the viewer's TV right now.
- search / play / guide / now_playing / player / open / recent / favorites /
  watchlist / sports_today / play_game / show_message: watching.
- groups: list a tab's groups, list one live group's channels with their
  guide (action channels), or hide / show whole groups by words in their
  names (simple, quick).
- game_channel: save which channel a Sports Trak game card plays. Read
  topic "sports" first.
- profiles / parental: viewer profiles, kids profiles and the parental PIN.
  Read topic "profiles" first.
- playlist_editor: finer playlist clean-up (single channels, rules, renames,
  fallbacks), every change undoable. Read topic "playlist_editor" first.
- settings: read or change the app's settings (playback, startup, look and
  language, guide, tabs, Sports Trak); clear histories (searches and
  channels, Continue Watching, Media Hub, the watch list); update_guide
  reloads the TV guide. action list first: only its keys can be set, with
  set's changes array for several at once (one OK on the TV).
Changes asked by an AI app may need the viewer to press OK on the TV; if
they say no, the tool returns an error saying so. Kids / restricted profiles
cannot change playlists or settings, or clear history.''',
  'playlist_editor': '''
PLAYLIST EDITOR (tool playlist_editor)

What it edits: the TV's editor layer over each playlist (the same one as
Settings > Playlists & guide > Playlist editor on the TV and its phone/PC
page). The provider's playlist is never changed. Live TV channels only (not
movies / shows). Edits are per viewer profile.

Always:
1. Look first: action "list" (rules, counts, fallbacks, recent AI changes)
   or "find_channels" (ids you need for single-channel actions).
2. For anything that hides or renames many channels, run it with
   preview: true, tell the viewer the counts and a few examples, then run
   the same call without preview.
3. Every change returns change_id. Tell the viewer it can be undone.

Ids: channel ids look like "playlistId::rawId" (from find_channels). A ref
from the search tool ("l12") also works. "playlist" = playlist name or id;
omitted, bulk actions apply to every enabled playlist.

Actions
- list [playlist]: per playlist: live_channels, hidden_by_editor_now,
  hidden_on_tv (the TV's own Hide channel list, not editable here),
  rules (numbered n), fallbacks, group_renames, hide_lower_copies,
  hide_separators, measured_dead; plus ai_changes (latest 10, with ids).
- find_channels query [only] [playlist]: up to 30 matches with id, name,
  provider_name (when renamed), group, hidden_by (tv / editor /
  combine_playlists), has_guide, test (last stream test), fallbacks.
  only = hidden | visible | no_guide | dead (query may be empty with only).
- hide_no_guide [playlist]: hides visible channels that have no guide data
  right now. A one-time snapshot: channels added later are not hidden.
  Refused while the guide updates or when none is loaded; a playlist whose
  channels all lack guide data is skipped (its guide is not loaded).
- hide_dead [playlist]: hides channels a stream test or real playback
  measured dead in the last 30 days. It does not run tests (the viewer runs
  them from the editor page: they use the provider connection).
- hide_channels channel_ids[]: hides those channels by hand (at most
  2000 per call).
- show_channels channel_ids[]: shows them again, also over rules / copy
  collapsing ("always shown"). Channels hidden on the TV itself
  (hidden_by "tv") are not shown by this; the viewer does that in Settings.
- add_rule rule_type find [replace] [regex] [field] [playlist]: re-applied
  on every content update, so new channels follow it too.
    * hide: hides every channel whose name (field "name", default) or group
      (field "group") contains find.
    * replace: in channel NAMES only, every match of find becomes replace
      ("" deletes it). Spaces are tidied after; a name that would become
      empty keeps the provider's name. Hand renames win over rules.
  find is case-insensitive, at most 300 characters. regex: true = a
  Dart/JavaScript-style regular expression (unicode, case-insensitive);
  otherwise plain text. A hide rule that would hide every channel of a
  playlist is refused. At most 100 rules per playlist.
- remove_rule rule_index (n from list; needs playlist when several) or
  find (removes rules with exactly that find text, all playlists).
- rename channel_id new_name, or renames: [{channel_id, new_name}] (at
  most 500). Empty new_name = back to the provider's name.
- rename_group group new_name, or renames: [{group, new_name}]: live
  groups. Groups given the same name merge into one. Empty = original.
- add_fallback channel_id fallback_id: when channel_id fails to play, the
  TV tries its fallbacks in order (at most 10), before the automatic copies
  of the same channel. The fallback may be in another playlist.
- remove_fallback channel_id [fallback_id]: one, or all of them.
- set_option option value: hide_lower_copies (keep only the best quality
  copy of a channel visible; the others stay as automatic fallbacks) or
  hide_separators (hide "##### SPORTS #####"-style divider rows).
- undo [change_id]: takes back one AI change (default: the latest). Parts
  the viewer or a later change touched since are left as they are now
  (reported as kept). preview: true works here too.

Examples
- "Hide every channel without EPG": hide_no_guide preview:true, report,
  then hide_no_guide.
- "Remove all CA affixes": find_channels query "CA" to see how they look,
  then add_rule rule_type "replace", regex true, find
  "^\\s*CA\\s*[:|\\-]+\\s*|\\s*[\\[(]\\s*CA\\s*[\\])]|\\s+CA\\s*\$", replace "",
  preview:true first (check rename_examples for false hits such as
  "CANAL+" or "CARTOON"; anchor the pattern so it only hits the affix).
- "Use channel A as fallback for channel B": find_channels for both, ask
  which copy if several match (4K / FHD / HD, other playlists), then
  add_fallback channel_id <B id> fallback_id <A id>.
- "Hide the French groups": add_rule rule_type "hide" field "group" find
  "FR|" (or the groups tool to hide whole groups once).
- "Undo that": undo.

groups tool vs playlist_editor: groups hides whole groups once (Settings >
Playlists list); playlist_editor rules keep working on new content and
work on single channels.''',
  'sports': '''
SPORTS TRAK (tools sports_today, play_game, game_channel)

Sports Trak shows the games of the leagues the viewer added (Sports Trak >
Edit leagues; a league that is not there cannot be asked for). Each card
plays the channel Sports Trak matched to it, or the one the viewer (or you,
with game_channel) picked.

sports_today [league] [team] [day]: games with a ref ("g4"), start time
(the TV's local time), state, networks (the TV networks the league lists,
e.g. "ESPN", "TNT", "NBA TV", "MSGB") and the matched channel with
matched_by:
- viewer_pick: the viewer chose it. Never replace it unless they ask.
- guide / channel_name: the guide or the channel's name names this game
  (evidence says what it read). Usually right.
- guide_series_guess, name_guess, team_channel_guess, network_guess: only
  the league, a team's channel or a broadcaster matched, not the game. These
  are the ones worth checking.
No channel = nothing matched.

play_game team [list: true]: every channel Sports Trak found for a team's
game today, best first, without playing when list is true.

groups action channels group "<name>": the live channels of one group with
the guide's now / next (title, day, start, end). Use it for a provider's
event group ("NBA League Pass", "NHL Center Ice", "PPV"). Event channels
are often renamed with the game ("NBA 03: Celtics vs. Knicks @ 7:30 PM
ET"); Sports Trak reads those names, so they are usually matched already.

game_channel picks [{game, channel}] (at most 40, one OK on the TV): saves
the channel for those games, like the viewer's own pick. It lasts about a
week. Rules:
1. Only pick a channel whose name, group or guide (now / next, at the game's
   time) names that game or both teams, or a channel of a network the game
   lists (networks) when the viewer has it.
2. Feeds named only by a number ("NBA LP 07") with no guide say nothing
   about the game: do not guess. Say which games stay unmatched instead.
3. A web search (if you have one) can tell which network shows a game; it
   cannot tell which numbered feed of the viewer's provider carries it.
4. Times in the guide and in sports_today are the TV's local time; channel
   names often say ET.
5. Tell the viewer what you saved and what you could not match.

Example "match every NBA game tonight with League Pass":
sports_today league "NBA" -> groups action channels group "NBA League Pass"
-> for each game without a viewer_pick / guide / channel_name match, find
the feed whose name or guide names both teams -> game_channel with those
picks -> report.''',
  'profiles': '''
PROFILES AND PARENTAL CONTROLS (tools profiles, parental)

Each viewer profile has its own favourites, history, hidden groups and
Sports Trak teams. Main always exists and cannot be deleted. A kids profile
(kids: true, fixed when created) sees ONLY the groups allowed to it: a new
kids profile sees nothing until groups are allowed. One parental PIN (4
digits) guards every kids profile.

The PIN: you never see, ask for, say or type it. When it is needed the TV
shows its own PIN pad and the viewer types it there (2 minutes, then it is
cancelled). Never ask the viewer to tell you the PIN. There is no way to
remove the PIN or to turn a kids profile into a normal one.

When the TV asks for the PIN:
- On a kids profile (the one on screen): every change, switching away
  included.
- From any profile: allowing groups to a kids profile, deleting a kids
  profile, changing the PIN.
- Not for: listing, switching INTO a kids profile, blocking groups from a
  parent's profile, creating a normal profile from a parent's.
If the PIN is not entered, the tool says nothing changed: tell the viewer.

profiles
- list: the profiles (kids, main, active) and pin_set.
- switch profile: the TV changes viewer (what plays stops).
- create name [kids]: a kids profile needs a PIN; when none is set the TV
  asks for a new one. Then allow groups to it (parental allow_groups).
- rename profile name.
- delete profile: never Main or the one on screen; always asked on the TV.

parental
- status: pin_set, each kids profile and its allowed groups.
- allow_groups profile contains [tab] [preview]: allows the groups whose
  names hold contains (e.g. "Kids", "Disney", "Cartoon") to that kids
  profile. Run with preview: true first and show the viewer the list: a
  word can catch adult groups ("Adult Cartoons", "XXX Disney" names exist).
  Leave out anything that looks adult.
- block_groups profile contains [tab] [preview]: takes groups back.
- change_pin: the TV asks the current PIN, then a new one twice.

Example "make a profile for Emma that only sees the kids channels":
profiles create name "Emma" kids true -> parental allow_groups profile
"Emma" contains "kids" preview true -> show the list, drop doubtful ones by
using more precise words -> allow_groups without preview (PIN on the TV).''',
};

final _vesperHelpTool = VesperTool(
  name: 'vesper_help',
  description: 'The manual for VesperTV\'s tools: what they can do, their '
      'rules and limits, with examples. Topics: "overview", '
      '"playlist_editor", "sports", "profiles". Read the topic before '
      'playlist_editor, game_channel, profiles or parental.',
  schema: {
    'type': 'object',
    'properties': {
      'topic': {
        'type': 'string',
        'enum': vesperHelpTopics.keys.toList(),
      },
    },
    'required': ['topic'],
  },
  run: (box, args, caller) async {
    final topic = _str(args, 'topic');
    final text = vesperHelpTopics[topic];
    if (text == null) {
      return {
        'error': 'Unknown topic. Topics: ${vesperHelpTopics.keys.join(', ')}.'
      };
    }
    return {'topic': topic, 'manual': text};
  },
);
