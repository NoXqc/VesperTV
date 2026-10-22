import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
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
}
