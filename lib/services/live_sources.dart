import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../widgets/live_source_drawer.dart';
import 'dispatcharr.dart';
import 'playlist_manager.dart';

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
  final app = <LiveSourceRow>[
    for (final c in manager.liveSourcesFor(playing))
      (
        c,
        LiveSourceEntry(
          channel: c,
          playlist: manager.playlistNameFor(c.playlistId).trim(),
          current: c.url == playing.url,
        )
      ),
  ];
  var canAdd = !manager.activeViewerRestricted;
  if (app.isEmpty) return (rows: app, canAdd: canAdd);
  final mode = Dispatcharr.instance.sources;
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
    final url = DispatcharrApi.streamUrl(server, s.hash, format: format);
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
      // X-API-Key header as its API.
      httpHeaders: {
        ...own.httpHeaders,
        if (key != null && key.isNotEmpty) 'X-API-Key': key,
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

/// Plays [source], picked in the live Sources list while [playing] plays,
/// through [play] (the player's own way to open a source of the playing
/// channel). A Dispatcharr stream, for an admin account, is a switch of
/// the channel on the server instead ([Dispatcharr.switchChannelTo]): the
/// player stays on (or goes back to) the channel. Returns the message to
/// show, or null.
Future<String?> playPickedLiveSource(Channel playing, Channel source,
    Future<void> Function(Channel source) play) async {
  final channel = await Dispatcharr.instance.switchChannelTo(source);
  if (channel == null) {
    await play(source);
    return null;
  }
  if (playing.url != channel.url) await play(channel);
  return tr(
      'Dispatcharr switched the channel to {stream}.', {'stream': source.name});
}
