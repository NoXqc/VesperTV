import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/profile_copy.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/profile_photos.dart';
import 'package:nox_iptv/services/phone_pairing_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/services/parental_pin.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/screens/settings/profile_editor_screen.dart';
import 'package:nox_iptv/widgets/profile_card.dart';
import 'package:nox_iptv/utils/constants.dart';

class MemoryStorage extends StorageService {
  MemoryStorage({super.photos});
  final cache = <String, String>{};
  @override
  Future<String?> readCacheFile(String name) async => cache[name];
  @override
  Future<void> writeCacheFile(String name, String content) async {
    cache[name] = content;
  }

  @override
  Future<void> deleteCacheFile(String name) async {
    cache.remove(name);
  }
}

Uint8List samplePhoto() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 60)));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('photo version is backward compatible and survives copies and JSON', () {
    final main = ViewerProfile.main();
    final old = main.toJson()..remove('photoVersion');
    expect(ViewerProfile.fromJson(old).photoVersion, 0);
    expect(
        ViewerProfile.fromJson(main.copyWith(photoVersion: 3).toJson())
            .photoVersion,
        3);
    expect(
        main
            .copyWith(name: 'Renamed', photoVersion: 3)
            .copyWith(colorIndex: 2)
            .photoVersion,
        3);
  });
  final examples = <String, Object>{
    AppConstants.keyFavorites: ['a::1'],
    AppConstants.keyFavoriteSeries: ['a::show'],
    AppConstants.keyFavoriteLiveOrder: ['a::1'],
    AppConstants.keyArchiveFavorites: '[1]',
    '${AppConstants.keyFavoritedGroups}_a': ['News'],
    AppConstants.keyArchiveHistory: '[2]',
    '${AppConstants.keyLastPositionPrefix}a::episode': 55,
    '${AppConstants.keyLastDurationPrefix}a::episode': 100,
    AppConstants.keyLastChannelId: 'a::1',
    AppConstants.keySportsLeagues: ['nhl'],
    AppConstants.keySportsAddedLeagues: ['nhl'],
    AppConstants.keySportsFavoriteLeague: 'nhl',
    AppConstants.keySportsFollowedTeams: ['x'],
    AppConstants.keySportsChannelPicks: '{}',
    AppConstants.keySportsHideScores: true,
    AppConstants.keySportsChannelLists: '{"favorites":["tsn"]}',
    '${AppConstants.keyHiddenGroups}_a': ['Adult'],
    '${AppConstants.keyHiddenChannels}_a': ['9'],
    '${AppConstants.keyGroupOrder}_tv_a': ['News'],
    '${AppConstants.keyChannelOrder}_a': '{}',
    '${AppConstants.keyHiddenPlaylistGroups}_tv': ['a'],
    AppConstants.keyMyGroups: '[]',
    AppConstants.keyHomeRows: ['sports'],
  };
  for (final option in [null, ...ProfileCopy.values]) {
    test(
        'copy ${option?.name ?? 'None'} reads Main and creates independent keys',
        () async {
      final seed = <String, Object>{
        ...examples,
        AppConstants.keyPlaylists: '[]',
        AppConstants.keyArchiveSources: 'private source stays shared',
        AppConstants.keyLayoutMode: 'tv',
        '${AppConstants.keyFavorites}${AppConstants.viewerKeySuffix}other': [
          'other'
        ]
      };
      SharedPreferences.setMockInitialValues(seed);
      final storage = MemoryStorage();
      await storage.init();
      storage.cache['recently_played'] = '[1]';
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
      final options = option == null ? <ProfileCopy>{} : {option};
      await storage.copyMainToViewer('vp_test', options, restricted: false);
      for (final entry in before.entries) {
        expect(prefs.get(entry.key), entry.value);
      }
      for (final entry in examples.entries) {
        expect(prefs.get('${entry.key}${AppConstants.viewerKeySuffix}vp_test'),
            copyMainKey(entry.key, options) ? entry.value : null,
            reason: entry.key);
      }
      expect(
          prefs.containsKey(
              '${AppConstants.keyPlaylists}${AppConstants.viewerKeySuffix}vp_test'),
          false);
      expect(storage.cache['recently_played_vp_vp_test'],
          option == ProfileCopy.history ? '[1]' : null);
      await storage.setActiveViewerId('vp_test');
      await storage.setFavorites({'new'});
      await storage.setArchiveFavoritesJson('new');
      await storage.setActiveViewerId('main');
      expect(storage.getFavorites(), {'a::1'});
      expect(storage.getArchiveFavoritesJson(), '[1]');
    });
  }
  test(
      'Everything copies each allowlisted key, Kids never copy visibility or allowlists',
      () async {
    SharedPreferences.setMockInitialValues({
      ...examples,
      '${AppConstants.keyShownGroups}_a': ['Adult']
    });
    final storage = MemoryStorage();
    await storage.init();
    await storage.copyMainToViewer('kid', ProfileCopy.values.toSet(),
        restricted: true);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getStringList('${AppConstants.keyFavorites}__vp_kid'), ['a::1']);
    expect(
        prefs.containsKey('${AppConstants.keyHiddenGroups}_a__vp_kid'), false);
    expect(
        prefs.containsKey('${AppConstants.keyShownGroups}_a__vp_kid'), false);
    await expectLater(storage.copyMainToViewer('main', {}, restricted: false),
        throwsArgumentError);
  });
  test('photo normalization validates, crops to 512 JPEG and rejects bad files',
      () {
    final photo = ProfilePhotos.normalize(samplePhoto());
    final decoded = img.decodeJpg(photo)!;
    expect((decoded.width, decoded.height), (512, 512));
    expect(() => ProfilePhotos.normalize(Uint8List(2 * 1024 * 1024 + 1)),
        throwsFormatException);
    expect(() => ProfilePhotos.normalize(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
    expect(
        () => ProfilePhotos.normalize(Uint8List.fromList([255, 216, 255, 0])),
        throwsFormatException);
  });
  test(
      'photo service add/change/remove/delete and Backup/Transfer restore files, never prefs',
      () async {
    final root = await Directory.systemTemp.createTemp('vesper-profile-test-');
    addTearDown(() => root.delete(recursive: true));
    SharedPreferences.setMockInitialValues({});
    final storage = MemoryStorage(photos: ProfilePhotos(directory: root));
    await storage.init();
    final manager = PlaylistManager(storage, CatalogDatabase());
    final playback = PlaybackService(storage, manager);
    final viewers = ViewerProfileService(storage, manager, playback);
    final p = await viewers.createProfile(
        name: 'A', colorIndex: 0, isRestricted: false, photo: samplePhoto());
    expect(p.photoVersion, 1);
    expect(await (await viewers.photoFile(p.id)).exists(), true);
    await viewers.setPhoto(p.id, samplePhoto());
    expect(viewers.profiles.last.photoVersion, 2);
    final backup = await storage.withProfilePhotos(storage.exportForBackup());
    final transfer =
        await storage.withProfilePhotos(storage.exportForTransfer());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isNot(contains('vesper_profile_photos')));
    for (final payload in [backup, transfer]) {
      final dest = Directory('${root.path}/restored');
      final restored = MemoryStorage(photos: ProfilePhotos(directory: dest));
      await restored.init();
      await restored.importForTransfer(payload);
      expect(await (await restored.profilePhotos.file(p.id)).exists(), true);
      expect(restored.getViewerProfiles().last.photoVersion, 2);
    }
    await viewers.removePhoto(p.id);
    expect(viewers.profiles.last.photoVersion, 0);
    expect(await (await viewers.photoFile(p.id)).exists(), false);
    await viewers.setPhoto(p.id, samplePhoto());
    expect(await viewers.deleteProfile(p.id), true);
    expect(await (await viewers.photoFile(p.id)).exists(), false);
    expect(await viewers.deleteProfile('main'), false);
    await storage.importForBackup({}); // Old backup, no photos.
    expect(storage.getViewerProfiles().single.photoVersion, 0);
  });
  test('LAN photo parser rejects oversized, MIME-spoofed and other payloads',
      () {
    final png = samplePhoto();
    expect(PairingKind.photo.isWifiOnly, true);
    expect(
        PairingResult.fromJson({
          'mode': 'photo',
          'mime': 'image/png',
          'photo': base64Encode(png)
        })!
            .photo,
        png);
    expect(
        PairingResult.fromJson({
          'mode': 'photo',
          'mime': 'image/jpeg',
          'photo': base64Encode(png)
        }),
        null);
    expect(
        PairingResult.fromJson(
            {'mode': 'photo', 'mime': 'image/png', 'photo': 'X' * 2800001}),
        null);
    expect(
        PairingResult.fromJson({
          'mode': 'photo',
          'mime': 'text/plain',
          'photo': base64Encode([1, 2, 3])
        }),
        null);
  });
  test('empty profile reload does not retain Main recently played', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = MemoryStorage();
    await storage.init();
    storage.cache['recently_played'] = jsonEncode([
      Channel(
              id: 'a',
              rawId: 'a',
              playlistId: 'p',
              name: 'A',
              group: '',
              url: 'https://example.test')
          .toJson()
    ]);
    final playback =
        PlaybackService(storage, PlaylistManager(storage, CatalogDatabase()));
    await playback.init();
    expect(playback.recentlyPlayed, hasLength(1));
    await storage.setActiveViewerId('vp_empty');
    await playback.reloadForViewer();
    expect(playback.recentlyPlayed, isEmpty);
  });
  testWidgets('portrait fallback, restricted badge, remote hold and touch hold',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var holds = 0, taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProfileCard(
                profile: ViewerProfile.main().copyWith(name: 'Alice'),
                label: 'Alice',
                focusNode: node,
                onTap: () => taps++,
                onHold: () => holds++))));
    node.requestFocus();
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(holds, 1);
    expect(taps, 0);
    await tester.longPress(find.byType(ProfileCard));
    expect(holds, 2);
  });
  for (final width in [360.0, 1280.0]) {
    testWidgets(
        'create form at $width defaults None, preview and Skip are present',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = MemoryStorage();
      await storage.init();
      final manager = PlaylistManager(storage, CatalogDatabase()),
          prefs = AppPreferences(storage);
      final playback = PlaybackService(storage, manager),
          viewers = ViewerProfileService(
              storage, manager, PlaybackService(storage, manager));
      await prefs.init();
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MultiProvider(providers: [
        Provider.value(value: storage),
        Provider.value(value: ParentalPin(storage)),
        ChangeNotifierProvider.value(value: manager),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: playback),
        ChangeNotifierProvider.value(value: viewers)
      ], child: const MaterialApp(home: AddProfileScreen())));
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsNWidgets(5));
      expect(
          tester
              .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
              .every((w) => w.value == false),
          true);
      await tester.enterText(find.byType(TextField), 'Family');
      await tester.pump();
      expect(find.text('Family'), findsWidgets);
      expect(find.text('Skip'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
