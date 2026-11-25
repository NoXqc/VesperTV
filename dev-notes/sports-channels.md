# Sports Channels

Sports Trak's Channels view uses visible live channels from PlaylistManager;
no stream probing, second player or game metadata is required for manual lists.
Create list offers manual selection or provider-group selection. Search/group
filters preserve multi-selection; lazy fixed-height rows have no 200-result cap.
Save stores composite channel IDs per viewer in vesper_sports_channel_lists.
Transfer/Backup include the key; deleting a viewer removes it by the standard suffix.
Missing references are retained but never resolved by name or shown to restricted
viewers. Lists are independent of favourites/UserGroups and support shared members.
Edit list manages selection, name, order and confirmed deletion.

OK starts the shared Sports preview, again opens the same session full screen;
hold OK adds to a list or chooses a quality version. Versions keep country,
region, number and plus-service distinctions. Network rows are conservative
suggestions based on visible names/groups, not claims of game broadcast rights.

Host tests are metadata/widget tests. Actual remote/touch/Windows playback needs
owner device checks; no Formuler automation or build/install is part of this work.

Phase 2 adds faceted filters (OR within one facet, AND between facets), Unknown,
bulk country/network/sport/league overrides and updating lists. Membership is
saved-filter matches plus explicit IDs minus exclusions, intersected with visible
live channels. Tags are inferred conservatively and cached per Channel object;
manual tags override inference. Facet choices and results use lazy lists.
Keep this list updated records group/search/facet rules; manual selection remains
the default. Clearing or changing a filter never clears existing selections.
Game menus offer Add sources from All channels/My lists, scoped to game (7-day
expiry), team or league; they use separate references from the preferred pick.
User choices retain their own label. More sources exposes unlimited matcher
results through the lazy picker rather than truncating at eight distinct feeds.

## Find games in hidden groups (owner, 2026-11-25)
Settings > Sports Trak > Channels > **Find games in hidden groups** (`vesper_sports_hidden_groups`, per viewer,
off): Sports Trak's channels also come from the live groups the viewer hid (a group hidden to keep the TV tidy,
e.g. event channels or another country, still carries its games). One source for every Sports Trak place:
`PlaylistManager.sportsChannels()` (= `visibleChannels(category: 'tv')` when off; on = + `PlaylistSession
.liveChannelsOfHiddenGroups()`, deduped by id, cached under `tv/sports` in `_visibleCache`) and
`sportsHiddenChannels()` (the "only on a hidden channel" list: with the switch on, only channels hidden one by one,
`hiddenLiveChannels(groups: false)`). Used by Sports Trak's matching / saved sources / Add sources / auto team
recording, Networks (`sports_channels_screen`), My Teams preferred channel, Multiview Live now, the player's This
game, the game reminder's play and Vesper's game tools (`vesper_tools` game matches, `game_channel` pick check).
Never on a kids profile (`sportsSearchesHiddenGroups` checks `_activeViewerRestricted`). Channels hidden one by one
and merge duplicates stay out. The TV itself is unchanged. The shared matcher re-indexes when the list changes
(its prepare signature); coming back from Settings re-matches (`didPopNext` -> `_load`). `test/sports_hidden_groups_test.dart`.
Owner box test (1000, all channels hidden, sources still found): "add a small hidden channel tag": `HiddenChannelTag`
(`widgets/hidden_channel_tag.dart`, eye-off + "Hidden", muted) on a channel `PlaylistManager.isInHiddenGroup` says is in a
hidden group: the game menu rows, Pick the channel results, the player's This game list and Multiview's game chooser.

### Cost (owner: "double check if that would affect how slow or fast sports trak gets", 2026-11-25)
Measured on the PC (flutter test, JIT) with a synthetic big provider: 6,040 shown channels, 60,300 in hidden groups,
30 games. Off = exactly the old lists (`sportsChannels()` returns `visibleChannels`), so nothing changes.
| | off | on |
|---|---|---|
| index (once per list change: launch, playlist / event-channel refresh, hiding a group) | 35-64 ms | ~300 ms |
| unchanged re-check (every rematch: signature over both lists) | 3 ms | 3 ms |
| match 30 games, first pass | ~190 ms | ~60-90 ms |
| match again (same list) | 13 ms (was ~155-185 ms) | ~60-80 ms |
The first-pass "off" cost is "only on a hidden channel" for games without a channel: a scan of every hidden name per
game, and it was redone on every match (the snapshot also threw its normalized hidden names away). Now
`_hiddenHits` (per game, per prepare) and `_hiddenNames` are kept on the shared matcher until the next prepare: repeat
passes 155 ms -> 13 ms for everyone with big hidden groups. With the switch on the index grows with the hidden groups
(~4.5 us/channel on the PC; a TV box is several times slower, in 400-channel slices with a yield between them, so
the remote keeps working) and games list more copies (the list stays capped). `test/sports_hidden_name_cache_test.dart`.
