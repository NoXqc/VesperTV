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
- groups: list a tab's groups, or hide / show whole groups by words in their
  names (simple, quick).
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
};

final _vesperHelpTool = VesperTool(
  name: 'vesper_help',
  description: 'The manual for VesperTV\'s tools: what they can do, their '
      'rules and limits, with examples. Topics: "overview", '
      '"playlist_editor". Read "playlist_editor" before using that tool.',
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
