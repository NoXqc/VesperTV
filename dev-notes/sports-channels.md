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
