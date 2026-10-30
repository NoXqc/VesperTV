# Sports Trak preferred channel countries (Codex, 2026-10-29)

Settings has a new Sports Trak category, initially containing Preferred channel
countries. Multiple countries can be selected with equal priority; No country
preference restores the existing automatic order. The setting belongs to the
viewer, copies with Main's Sports data, and travels in Backup/Transfer.

## Ranking boundary

No guide search, team/event-name matching, time/date guard, broadcaster mapping,
hidden-channel rule, candidate-admission rule or match score was changed. The
preference reorders candidates after matching and before the distinct-copy limit.
No preference, or no candidate from a preferred country, returns the usual order.

With a matching preference, precedence is: explicit game/team/series pick;
manually added sources; game-name/time-aligned guide evidence; unconfirmed
team-channel, series-channel and broadcaster suggestions. Within each comparable
group, selected countries precede other/unknown countries, with the existing
quality preference and stable ordering retained inside each country group.
Thus a generic Canadian broadcaster cannot outrank a US channel whose guide
names the game; a Canadian HD match can precede a foreign 4K match when both
have game evidence. Other countries remain candidates/fallbacks. The existing
result limit still applies; no new broadcaster is assumed to carry a game.

ChannelMatch.gameEvidence records evidence already found, independently of the
highest-scoring displayed reason. Adding the flag retains existing scores,
reasons and details, including score ties. SportsChannelPicks.orderMatches is
also used after SportsScreen merges manually added sources, preventing the
existing quality sort from undoing the country preference in cards or menus.

## Country identification

Manual Country tags from Sports Networks override inference, including an explicit
Unknown. Next come a country prefix on the channel, a prefix/full country name
on its group, then unambiguous Canadian brands (TSN/TSN+, Sportsnet, RDS, TVA
Sports) or the existing separate US SportsNet classification. GB/USA/CAFR and
similar known aliases normalize to existing country codes. Leading decorations
and flags are tolerated when followed by a country tag. Unlabelled Sky, DAZN,
beIN and Eurosport remain unknown because their names alone span countries.

The classifier is used only for this preference. Existing Sports Networks smart
list/filter inference is unchanged, so enabling the new feature cannot add
channels to a previously saved smart source list through new inferred tags.
Country labels are a provider-metadata preference, not a broadcast-rights check.

Country/tag data is snapshotted once per match batch, rather than decoded for
every card or sort comparison. The default path skips optional manual-tag parsing.
Settings uses the standard category navigation and TvMenuTile controls; profile
generation guards prevent an old editor writing into a newly selected viewer.

## Validation and remaining checks

test/sports_country_preferences_test.dart checks Canadian networks/US SportsNet,
ambiguous brands, aliases/group tags/manual corrections, unchanged candidates and
scores/guide queries, French football preferences, wrong-game exclusion, explicit
picks, confidence/quality ordering, fallback/default identity and profile/copy/
Backup/Transfer scope. test/sports_country_settings_test.dart covers the new
category on TV/phone, D-pad selection/Back, multi-select/reset, all five UI
languages, large text, stable focus and stale-profile writes.

No device build/install, native-player change, version bump or publication.
Real-provider ranking and physical-box interaction still need the normal owner
smoke check. Main implementation: sports_channel_countries.dart,
SportsChannelPicks.orderMatches, sports_country_settings_screen.dart.

## Preferred playlist (Codex, 2026-10-30)

Settings > Sports Trak > Preferred playlist adds a single optional playlist
choice by stable ID, per viewer. No playlist preference resets only this
setting. Enabled playlists are selectable; a disabled/deleted saved choice
is reported as unavailable and other valid matches remain usable. This does
not change the global Live TV playlist order or enable channels/playlists.

The existing evidence tiers above are preserved. Within each tier, preference
is now playlist first, then country, then the usual quality/stable order.
Explicit game/team/series picks remain ahead of automatic preferences, and
a generic preferred-playlist broadcaster cannot replace a confirmed game
on another playlist. No preferred-playlist candidate preserves the country
ranking; with neither preference set, the previous order is unchanged.

Before the existing three-suggestion caps for broadcaster/series fallbacks,
a stable partition places eligible preferred-playlist feeds first. Thus
the preference can affect which fallback copies survive those caps, but
not name/date/time/region checks, EPG queries, scores or candidate eligibility.
The caps and hidden-channel rules still apply. The post-merge Sports screen
ordering uses the same preference so added sources cannot undo it.

Storage key: keySportsPreferredPlaylist. Included in ProfileCopy.sports and
the existing Backup/Transfer payload. The editor uses TvMenuTile and guards
writes against viewer changes. Country wording now explains playlist priority.
Tests: sports_playlist_preferences_test.dart covers EPG ranking/candidate
identity/scores/query count, both capped fallback paths, explicit and manual
picks, evidence, reset/no-match identity, profile copy and Backup/Transfer,
TV/phone D-pad navigation, all five languages and large text/stale viewers.
Remote guide/help index updated locally. APK529 predates this change; no
new build/install requested here. Formuler installation remains on hold.
