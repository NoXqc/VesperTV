import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nox_iptv/screens/sports_channels_screen.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/sports_channel_library.dart';
import 'package:nox_iptv/services/sports_networks.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkPlaylist extends PlaylistManager {
  NetworkPlaylist(super.storage, super.catalogDb);
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [
        Channel(
            id: 'p::tsn',
            rawId: 'tsn',
            playlistId: 'p',
            name: 'CA: TSN 1 HD',
            group: 'Sports',
            url: 'https://example.com/live'),
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  test('an older source picker cannot erase saved favourite networks',
      () async {
    final picker = SportsChannelLists(storage);
    final networks = SportsChannelLists(storage);
    networks.favoriteNetworks.add('tsn');
    await networks.save();
    await picker.setSources('league:nhl', ['p::1']);
    expect(SportsChannelLists(storage).favoriteNetworks, {'tsn'});
    // Saving favourites also keeps source updates from the other instance.
    networks.favoriteNetworks.add('espn');
    await networks.save();
    expect(SportsChannelLists(storage).sources['league:nhl']?['ids'], ['p::1']);
  });

  test('favourite additions merge and stale stores cannot resurrect removals',
      () async {
    final a = SportsChannelLists(storage);
    final b = SportsChannelLists(storage);
    a.favoriteNetworks.add('tsn');
    await a.save();
    b.favoriteNetworks.add('espn');
    await b.save();
    expect(SportsChannelLists(storage).favoriteNetworks, {'tsn', 'espn'});
    final stale = SportsChannelLists(storage);
    a.favoriteNetworks.remove('tsn');
    await a.save();
    stale.create('My list', ['p::1']);
    await stale.save();
    expect(SportsChannelLists(storage).favoriteNetworks, {'espn'});
    expect(SportsChannelLists(storage).lists.single.name, 'My list');
  });

  test('known and unknown network ids survive reload and missing channels',
      () async {
    Channel channel(String id, String name) => Channel(
        id: 'p::$id',
        rawId: id,
        playlistId: 'p',
        name: name,
        group: 'Sports',
        url: 'https://example.com/live');
    final channels = [
      channel('tsn', 'CA: TSN 1 HD'),
      channel('local', 'Local Arena HD')
    ];
    final ids = [
      ...SportsChannelLibrary.groups(channels, row: 'Sports networks'),
      ...SportsChannelLibrary.groups(channels, row: 'Other sports channels'),
    ].map((g) => g.id).toSet();
    expect(ids, contains('tsn'));
    expect(ids.any((id) => id.startsWith('own:')), isTrue);
    final store = SportsChannelLists(storage)..favoriteNetworks.addAll(ids);
    await store.save();
    final restarted = StorageService();
    await restarted.init();
    expect(SportsChannelLists(restarted).favoriteNetworks, ids);
    // No pruning when a playlist temporarily has no matching channel.
    final missing = SportsChannelLists(restarted);
    missing.tags['p::unrelated'] = {
      'Country': ['CA']
    };
    await missing.save();
    expect(SportsChannelLists(restarted).favoriteNetworks, ids);
  });

  test('favourites remain viewer-scoped through transfer and removal',
      () async {
    final main = SportsChannelLists(storage)..favoriteNetworks.add('tsn');
    await main.save();
    await storage.setActiveViewerId('kid');
    final kid = SportsChannelLists(storage)..favoriteNetworks.add('espn');
    await kid.save();
    final payload = storage.exportForTransfer();
    SharedPreferences.setMockInitialValues({});
    final received = StorageService();
    await received.init();
    await received.importForTransfer(payload);
    expect(SportsChannelLists(received).favoriteNetworks, {'tsn'});
    await received.setActiveViewerId('kid');
    expect(SportsChannelLists(received).favoriteNetworks, {'espn'});
    final remove = SportsChannelLists(received)..favoriteNetworks.clear();
    await remove.save();
    expect(SportsChannelLists(received).favoriteNetworks, isEmpty);
    await received.setActiveViewerId('main');
    expect(SportsChannelLists(received).favoriteNetworks, {'tsn'});
  });
  test('a delayed store save stays with the viewer that opened it', () async {
    final main = SportsChannelLists(storage)..favoriteNetworks.add('tsn');
    await storage.setActiveViewerId('kid');
    await main.save();
    expect(SportsChannelLists(storage).favoriteNetworks, isEmpty);
    await storage.setActiveViewerId('main');
    expect(SportsChannelLists(storage).favoriteNetworks, {'tsn'});
  });

  testWidgets('favourite row survives leaving and reopening Networks',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final playlist = NetworkPlaylist(storage, CatalogDatabase());
    final epg = EpgService(storage);
    final oldPicker = SportsChannelLists(storage);
    Future<void> open() async {
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: storage),
            ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
            ChangeNotifierProvider<EpgService>.value(value: epg),
          ],
          child: MaterialApp(
              home: SportsChannelsScreen(
            onGames: () {},
            onPreview: (_) async {},
            onFullScreen: (_) async {},
          ))));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('Favourite networks'), findsNothing);
    await tester.longPress(find.text('TSN').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourite this network'));
    await tester.pumpAndSettle();
    expect(find.text('Favourite networks'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await oldPicker.setSources('league:nhl', ['p::tsn']);
    await open();
    expect(find.text('Favourite networks'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    playlist.dispose();
    epg.dispose();
    await tester.pump();
  });
  test(
      'the channel picked for a network card is saved, and an older '
      'snapshot does not erase it', () async {
    final older = SportsChannelLists(storage);
    final networks = SportsChannelLists(storage);
    networks.networkPicks['tsn'] = 'p::tsn4';
    await networks.save();
    expect(SportsChannelLists(storage).networkPicks, {'tsn': 'p::tsn4'});
    older.favoriteNetworks.add('espn');
    await older.save();
    final now = SportsChannelLists(storage);
    expect(now.networkPicks, {'tsn': 'p::tsn4'});
    expect(now.favoriteNetworks, {'espn'});
  });

  test('a known network card uses the network logo', () {
    final espn = kSportsNetworks.firstWhere((n) => n.id == 'espn');
    final group = SportsNetworkGroup('espn', 'ESPN', espn)
      ..channels.add(Channel(
          id: 'p::ocho',
          rawId: 'ocho',
          playlistId: 'p',
          name: 'US: ESPN Ocho',
          group: 'Sports',
          url: 'https://example.com/live',
          logoUrl: 'https://example.com/ocho.png'));
    expect(group.logoUrl, endsWith('/united-states/espn-us.png'));
    final unknown = SportsNetworkGroup('x', 'X', null)
      ..channels.addAll(group.channels);
    expect(unknown.logoUrl, 'https://example.com/ocho.png');
  });
}
