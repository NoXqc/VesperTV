import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/profile_copy.dart';
import 'package:nox_iptv/utils/favorite_live_sort.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Supply the live favourites that enabled playlists would expose, without
// downloading catalogs. Exercise the real ordering, persistence and moves.
class FavoritePlaylist extends PlaylistManager {
  FavoritePlaylist(StorageService storage, this.favorites)
      : super(storage, CatalogDatabase());

  List<Channel> favorites;

  @override
  List<Channel> get favoriteLiveChannelsWithGroups => [...favorites];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late FavoritePlaylist playlist;

  Channel ch(String playlist, String name, {bool starred = true}) => Channel(
        id: '$playlist::$name',
        rawId: name,
        playlistId: playlist,
        name: name,
        group: 'Live',
        url: 'https://example.com/live',
        isFavorite: starred,
      );

  List<String> ids({bool mix = false}) => playlist
      .orderedFavoriteLiveChannels(mixPlaylists: mix)
      .map((c) => c.id)
      .toList();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    playlist = FavoritePlaylist(storage, [
      ch('a', 'Zulu'),
      ch('a', 'Group channel', starred: false),
      ch('b', 'Alpha'),
    ]);
  });

  tearDown(() => playlist.dispose());

  test('defaults stay unchanged until a move, including mixed A-Z', () {
    expect(ids(), ['a::Zulu', 'a::Group channel', 'b::Alpha']);
    expect(ids(mix: true), ['b::Alpha', 'a::Zulu', 'a::Group channel']);
    expect(storage.getFavoriteLiveOrder(), isEmpty);
  });

  test('moves across playlists and includes favourited-group channels',
      () async {
    final channel = playlist.favorites.last;
    expect(await playlist.moveFavoriteLiveChannel(channel, -1), 1);
    expect(ids(), ['a::Zulu', 'b::Alpha', 'a::Group channel']);
    expect(await playlist.moveFavoriteLiveChannel(channel, -1), 0);
    expect(await playlist.moveFavoriteLiveChannel(channel, -1), isNull);
    expect(ids(), ['b::Alpha', 'a::Zulu', 'a::Group channel']);
    expect(await playlist.moveFavoriteLiveChannel(channel, 1), 1);
    expect(ids(), ['a::Zulu', 'b::Alpha', 'a::Group channel']);
    // Favourite moves never write provider channel order.
    expect(storage.getChannelOrder('a'), isEmpty);
    expect(storage.getChannelOrder('b'), isEmpty);
  });

  test('manual order wins over mixed sorting and survives restart', () async {
    await playlist.moveFavoriteLiveChannel(playlist.favorites.first, -1,
        mixPlaylists: true);
    expect(ids(mix: true), ['a::Zulu', 'b::Alpha', 'a::Group channel']);
    final freshStorage = StorageService();
    await freshStorage.init();
    final fresh = FavoritePlaylist(freshStorage, playlist.favorites);
    expect(
        fresh.orderedFavoriteLiveChannels().map((c) => c.id), ids(mix: true));
    fresh.dispose();
  });

  test('unavailable channels keep their place; new favourites append',
      () async {
    await playlist.moveFavoriteLiveChannel(playlist.favorites.last, -1);
    final hidden = playlist.favorites.removeAt(1);
    await playlist.moveFavoriteLiveChannel(playlist.favorites.last, -1);
    playlist.favorites.add(hidden);
    playlist.favorites.add(ch('b', 'New'));
    expect(ids(), ['b::Alpha', 'a::Zulu', 'a::Group channel', 'b::New']);
    expect(await playlist.moveFavoriteLiveChannel(playlist.favorites.last, 1),
        isNull);
  });

  test('composite ids and viewer scoping survive backup and transfer',
      () async {
    playlist.favorites = [ch('a', 'Same'), ch('b', 'Same')];
    await playlist.moveFavoriteLiveChannel(playlist.favorites.last, -1);
    expect(ids(), ['b::Same', 'a::Same']);
    final transfer = storage.exportForTransfer();
    final backup = storage.exportForBackup();
    await storage.setActiveViewerId('other');
    playlist.applyActiveViewer();
    expect(ids(), ['a::Same', 'b::Same']);
    await playlist.moveFavoriteLiveChannel(playlist.favorites.last, -1);
    await playlist.moveFavoriteLiveChannel(playlist.favorites.last, 1);
    expect(ids(), ['a::Same', 'b::Same']);
    await storage.setActiveViewerId('main');
    playlist.applyActiveViewer();
    expect(ids(), ['b::Same', 'a::Same']);
    await storage.setFavoriteLiveOrder([]);
    await storage.importForTransfer(transfer);
    expect(ids(), ['b::Same', 'a::Same']);
    await storage.setFavoriteLiveOrder([]);
    await storage.importForBackup(backup);
    expect(ids(), ['b::Same', 'a::Same']);
  });
  test('an AI app puts one favourite anywhere, the others keep their order',
      () async {
    playlist.favorites = [
      for (final n in ['CNN', 'TSN', 'CP24', 'RDS Info']) ch('a', n)
    ];
    final rds = playlist.favorites.last;
    expect(await playlist.placeFavoriteLiveChannel(rds, 0), 0);
    expect(ids(), ['a::RDS Info', 'a::CNN', 'a::TSN', 'a::CP24']);
    expect(await playlist.placeFavoriteLiveChannel(rds, 99), 3);
    expect(ids(), ['a::CNN', 'a::TSN', 'a::CP24', 'a::RDS Info']);
    expect(await playlist.placeFavoriteLiveChannel(rds, 1), 1);
    expect(ids(), ['a::CNN', 'a::RDS Info', 'a::TSN', 'a::CP24']);
    expect(await playlist.placeFavoriteLiveChannel(ch('x', 'Gone'), 0), isNull);
  });

  test('an AI app orders favourites: listed first, the rest after', () async {
    playlist.favorites = [
      for (final n in ['CNN', 'TSN', 'Seinfeld 24/7', 'CP24', 'Fox']) ch('a', n)
    ];
    await storage.setFavoriteLiveOrder(
        ['a::CNN', 'hidden::missing', 'a::TSN', 'a::Seinfeld 24/7']);
    final now = await playlist
        .orderFavoriteLiveChannels(['a::CP24', 'a::TSN', 'nope::x', 'a::CP24']);
    expect(now.map((c) => c.id),
        ['a::CP24', 'a::TSN', 'a::CNN', 'a::Seinfeld 24/7', 'a::Fox']);
    expect(ids(), now.map((c) => c.id));
    // A hidden playlist's favourite keeps its saved slot.
    expect(storage.getFavoriteLiveOrder()[1], 'hidden::missing');
  });

  test(
      'A-Z and Z-A span playlists and favourite groups without destroying original order',
      () async {
    final original = ['a::Group channel', 'b::Alpha', 'a::Zulu'];
    await storage.setFavoriteLiveOrder(original);
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.aToZ);
    expect(ids(mix: true), ['b::Alpha', 'a::Group channel', 'a::Zulu']);
    expect(storage.getFavoriteLiveOrder(), original);
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.zToA);
    expect(ids(mix: true), ['a::Zulu', 'a::Group channel', 'b::Alpha']);
    expect(
        ids(), original); // Mixed-playlist setting off ignores the sort view.
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.original);
    expect(ids(mix: true), original);
  });

  test(
      'sort uses current display names, stable ties and automatically places new favourites',
      () async {
    playlist.favorites = [ch('a', 'Same'), ch('b', 'same'), ch('b', 'Zulu')];
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.aToZ);
    expect(ids(mix: true), ['a::Same', 'b::same', 'b::Zulu']);
    playlist.favorites.add(ch('c', 'Alpha'));
    playlist.favorites.last.nameOverride = 'Zzz renamed';
    expect(ids(mix: true).last, 'c::Alpha');
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.zToA);
    expect(ids(mix: true), ['c::Alpha', 'b::Zulu', 'a::Same', 'b::same']);
    expect(storage.getChannelOrder('a'), isEmpty);
  });

  test(
      'manual move after sorting starts with visible order and retains unavailable ids',
      () async {
    await storage.setFavoriteLiveOrder(
        ['a::Zulu', 'hidden::missing', 'b::Alpha', 'a::Group channel']);
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.aToZ);
    expect(
        await playlist.moveFavoriteLiveChannel(playlist.favorites.first, -1,
            mixPlaylists: true),
        1);
    expect(playlist.favoriteLiveSort, FavoriteLiveSort.original);
    expect(ids(mix: true), ['b::Alpha', 'a::Zulu', 'a::Group channel']);
    expect(storage.getFavoriteLiveOrder()[1], 'hidden::missing');
  });

  test(
      'sort survives reopening, backup, transfer and copying Main; scoped per viewer',
      () async {
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.zToA);
    final backup = storage.exportForBackup(),
        transfer = storage.exportForTransfer();
    final reopened = StorageService();
    await reopened.init();
    expect(reopened.getFavoriteLiveSort(), 'zToA');
    expect(
        StorageService.isLiveSyncKey(AppConstants.keyFavoriteLiveSort), isTrue);
    expect(
        storage.exportForSync().containsKey(AppConstants.keyFavoriteLiveSort),
        isTrue);
    await storage.setActiveViewerId('other');
    expect(playlist.favoriteLiveSort, FavoriteLiveSort.original);
    await storage.setActiveViewerId('main');
    await storage.copyMainToViewer('other', {ProfileCopy.favourites},
        restricted: false);
    await storage.setActiveViewerId('other');
    expect(playlist.favoriteLiveSort, FavoriteLiveSort.zToA);
    await storage.setActiveViewerId('main');
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.original);
    await storage.importForBackup(backup);
    expect(playlist.favoriteLiveSort, FavoriteLiveSort.zToA);
    await playlist.setFavoriteLiveSort(FavoriteLiveSort.original);
    await storage.importForTransfer(transfer);
    expect(playlist.favoriteLiveSort, FavoriteLiveSort.zToA);
  });

  test('invalid sort value safely falls back to the original view', () async {
    await storage.setFavoriteLiveSort('unknown');
    expect(playlist.favoriteLiveSort, FavoriteLiveSort.original);
    expect(ids(mix: true), ['b::Alpha', 'a::Zulu', 'a::Group channel']);
  });
}
