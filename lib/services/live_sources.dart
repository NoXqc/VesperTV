import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../widgets/live_source_drawer.dart';
import 'dispatcharr.dart';
import 'playback_service.dart' show ServerHold;
import 'playlist_manager.dart';
import 'tuliprox.dart';

/// One row of the live Sources list: the stream to play and how it shows.
typedef LiveSourceRow = (Channel, LiveSourceEntry);

/// The live Sources list of [playing], as the player's drawer shows it and
/// Vesper AI's `sources` tool lists it: the channel, its quality copies,
/// playlist editor fallbacks and the same channel in other playlists, plus
/// the streams Dispatcharr merged into it (AMD, 2026-11-17), ordered or
/// filtered by Settings > Dispatcharr > Sources in the player (2026-11-18).
/// [canAdd]: "Add another source" is offered.
Future<({List<LiveSourceRow> rows, bool canAdd})> liveSourceRows(
    PlaylistManager manager, Channel playing) async {
  final sources = manager.liveSourcesFor(playing);
  final app = <LiveSourceRow>[
    for (final c in sources)
      (
        c,
        LiveSourceEntry(
          channel: c,
          // The editor's own fallbacks say so, like Dispatcharr's and
          // Tuliprox's rows name their server (owner, 2026-11-19).
          playlist: [
            manager.playlistNameFor(c.playlistId).trim(),
            if (manager.isEditorFallback(sources.first, c)) tr('Fallback'),
          ].where((s) => s.isNotEmpty).join(' · '),
          current: c.url == playing.url,
          // What it really played at (stream test, Multiview, full
          // screen) beats what its name claims.
          quality: manager.measuredOf(c)?.label,
        )
      ),
  ];
  var canAdd = !manager.activeViewerRestricted;
  if (app.isEmpty) return (rows: app, canAdd: canAdd);
  // Server sources first / only / VesperTV's only: one setting for
  // Dispatcharr and Tuliprox (owner, 2026-11-19: like Dispatcharr's).
  final mode = Dispatcharr.instance.sources;
  // A Tuliprox failover group: the server's own sources of the channel,
  // for an admin login (owner, 2026-11-19).
  final tuliprox = mode == DispatcharrSources.vesper
      ? null
      : await _tuliproxRows(app, playing, mode);
  if (tuliprox != null) {
    return (
      rows: tuliprox,
      canAdd: mode == DispatcharrSources.only ? false : canAdd
    );
  }
  final merged = mode == DispatcharrSources.vesper
      ? null
      : await Dispatcharr.instance.streamsFor(app.first.$1);
  if (merged == null) return (rows: app, canAdd: canAdd);
  final own = app.first.$1;
  final server = Dispatcharr.instance.login.value?.server ?? '';
  final key = Dispatcharr.instance.login.value?.apiKey;
  // A picked stream plays in the channel's own format (clayts450).
  final format = dispatcharrOutputFormat(own.url);
  // Admin, on the channel itself: the stream Dispatcharr plays for it now
  // is marked, so a switch shows where the channel is.
  final onChannel = playing.url == own.url;
  final active =
      onChannel ? await Dispatcharr.instance.activeStreamOf(own) : null;
  final streams = <LiveSourceRow>[];
  for (final s in merged.streams) {
    // A stream on a Redirect profile (cillfog, Discord 2026-11-23: they
    // play as the channel but not picked here). Dispatcharr redirects
    // only channels, so a redirect = the provider's address itself when
    // this login is shown it (admins), like Dispatcharr's own redirect;
    // else Dispatcharr proxies it (skip_redirect).
    final redirect = merged.redirects.contains(s.id);
    final direct = redirect ? s.url : null;
    final url = direct ??
        DispatcharrApi.streamUrl(server, s.hash,
            format: format, skipRedirect: redirect);
    if (redirect) {
      debugPrint('Dispatcharr: stream ${s.id} is on Redirect, plays '
          '${direct != null ? 'from ${Dispatcharr.hostOf(direct)}' : 'proxied (skip_redirect)'}');
    }
    Dispatcharr.instance.notePick(url, own, s.id);
    if (app.any((r) => r.$1.url == url)) continue;
    final c = Channel(
      id: own.id,
      rawId: own.rawId,
      playlistId: own.playlistId,
      name: s.name.isEmpty ? own.name : s.name,
      group: own.group,
      url: url,
      logoUrl: own.logoUrl,
      // Signed in, so Dispatcharr's Active Connections names the user
      // instead of Anonymous (AMD, 2026-11-18): the proxy reads the same
      // X-API-Key header as its API. Never to the provider (direct).
      httpHeaders: {
        ...own.httpHeaders,
        if (direct == null && key != null && key.isNotEmpty) 'X-API-Key': key,
      },
    );
    streams.add((
      c,
      LiveSourceEntry(
        channel: c,
        playlist: [
          'Dispatcharr',
          if (merged.accounts[s.accountId] case final a?) a,
        ].join(' · '),
        current: url == playing.url || (onChannel && s.id == active),
        quality: s.quality,
      )
    ));
  }
  // The channel itself plays Dispatcharr's own order (its failover): AMD
  // took it for one of VesperTV's matches.
  final first = app.first.$2;
  final ownRow = (
    own,
    LiveSourceEntry(
      channel: own,
      playlist: [first.playlist, tr('Automatic')]
          .where((s) => s.isNotEmpty)
          .join(' · '),
      current: first.current,
    )
  );
  final rows = arrangeDispatcharrSources(
      mode, [ownRow, ...app.skip(1)], streams, (r) => r.$2.current);
  // Only Dispatcharr's: no VesperTV fallback to add either.
  if (mode == DispatcharrSources.only) canAdd = false;
  return (rows: rows, canAdd: canAdd);
}

/// The Sources rows of a Tuliprox failover group channel ([Tuliprox]):
/// the channel itself (Automatic: the server picks), then every source the
/// server has merged into it, the one on air marked, then VesperTV's own
/// matches, in [mode]'s order ([arrangeDispatcharrSources]). Null when
/// [playing] isn't one (or this login can't see them).
Future<List<LiveSourceRow>?> _tuliproxRows(
    List<LiveSourceRow> app, Channel playing, DispatcharrSources mode) async {
  final own = app.first.$1;
  if (Tuliprox.instance.login.value == null || playing.url != own.url) {
    return null;
  }
  final group = await Tuliprox.instance.groupFor(own);
  if (group == null || group.members.length < 2) return null;
  final first = app.first.$2;
  final rows = <LiveSourceRow>[
    (
      own,
      LiveSourceEntry(
        channel: own,
        playlist: [first.playlist, tr('Automatic')]
            .where((s) => s.isNotEmpty)
            .join(' · '),
        current: first.current,
      )
    ),
  ];
  for (final m in group.members) {
    final c = Channel(
      id: own.id,
      rawId: own.rawId,
      playlistId: own.playlistId,
      name: m.title.isEmpty ? own.name : m.title,
      group: own.group,
      url: Tuliprox.instance.notePick(own, group.uid, m),
      logoUrl: own.logoUrl,
      httpHeaders: own.httpHeaders,
    );
    rows.add((
      c,
      LiveSourceEntry(
        channel: c,
        playlist: ['Tuliprox', if (m.input.isNotEmpty) m.input].join(' · '),
        current: m.vid == group.currentVid,
      )
    ));
  }
  // rows = the channel itself, then the server's members.
  return arrangeDispatcharrSources(mode, [rows.first, ...app.skip(1)],
      rows.skip(1).toList(), (r) => r.$2.current);
}

/// Plays [source], picked in the live Sources list while [playing] plays,
/// through [play] (the player's own way to open a source of the playing
/// channel). A Dispatcharr stream, for an admin account, is a switch of
/// the channel on the server instead ([Dispatcharr.switchChannelTo]): the
/// player stays on (or goes back to) the channel. Staying on it, the
/// player reconnects to it a few seconds later ([reconnect] after
/// [Dispatcharr.reconnectDelay], the channel held by
/// [Dispatcharr.holdChannel]), or the new stream would only show once the
/// buffered video has played (AMD, 2026-11-21: 29-42 s). Returns the
/// message to show, or null.
Future<String?> playPickedLiveSource(
    Channel playing, Channel source, Future<void> Function(Channel source) play,
    {void Function(String name)? onServerSwitch,
    Future<void> Function(Duration after, String name, ServerHold hold)?
        reconnect}) async {
  // A Tuliprox source: the server splices it into the open stream, the
  // player keeps its connection (no play).
  if (Tuliprox.instance.isPick(source)) {
    try {
      final name = await Tuliprox.instance.switchTo(source) ?? source.name;
      // The picture follows once the buffer has played: the player
      // watches for it and says when it changed ([onServerSwitch]).
      onServerSwitch?.call(name);
      return tr('Changing source to {stream}…', {'stream': name});
    } catch (e) {
      debugPrint('Tuliprox: switch refused ($e)');
      return tr("Tuliprox didn't switch the source.");
    }
  }
  final channel = await Dispatcharr.instance.switchChannelTo(source);
  if (channel == null) {
    await play(source);
    return null;
  }
  if (playing.url != channel.url) {
    await play(channel);
  } else if (reconnect != null) {
    unawaited(() async {
      final after = await Dispatcharr.instance.reconnectDelay();
      await reconnect(after, source.name, Dispatcharr.instance.holdChannel);
    }());
  }
  return tr(
      'Dispatcharr switched the channel to {stream}.', {'stream': source.name});
}
