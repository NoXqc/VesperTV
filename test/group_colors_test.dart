import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/group_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Hold OK on a group > Colour… (owner, 2026-11-25: "a red contour and red
/// lettering to my Sports group"): saved per playlist and viewer like the
/// group star, follows a rename, own groups too.
class _DirStorage extends StorageService {
  _DirStorage(this.dir);
  final Directory dir;
  @override
  Future<String> rawCachePath(String name, String ext) async =>
      '${dir.path}/$name.$ext';
  @override
  Future<String?> cacheFilePath(String name) async {
    final f = File('${dir.path}/$name.json');
    return await f.exists() ? f.path : null;
  }

  @override
  Future<void> writeCacheFile(String name, String content) =>
      File('${dir.path}/$name.json').writeAsString(content);

  @override
  Future<void> deleteCacheFile(String name) async {
    final f = File('${dir.path}/$name.json');
    if (await f.exists()) await f.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistManager manager;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_group_colors_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="tsn1" group-title="SPORTS",TSN 1',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="cnn" group-title="NEWS",CNN',
      'http://x/2.ts',
      '',
    ].join('\n'));
    storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    manager = PlaylistManager(storage, catalog);
    addTearDown(manager.dispose);
    await manager.addPlaylist(PlaylistProfile(
        id: 'p',
        name: 'Home',
        mode: 'm3u',
        m3uUrl: Uri.file(file.path).toString(),
        sortOrder: 0,
        createdAt: DateTime(2026)));
    await manager.loadPlaylist('p');
  });

  test('presets: stable ids, distinct colours, unknown ids are no colour', () {
    final ids = [for (final c in GroupColor.presets) c.id];
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, hasLength(8));
    expect({for (final c in GroupColor.presets) c.color}, hasLength(8));
    expect(GroupColor.of('red'), GroupColor.presets.first.color);
    expect(GroupColor.of('mauve'), isNull, reason: 'a later version\'s id');
    expect(GroupColor.of(null), isNull);
  });

  test('a live group\'s colour is saved, redraws the TV tab, follows a rename',
      () async {
    final before = manager.liveViewSignature();
    await manager.setGroupColor('p', 'SPORTS', 'red');
    expect(manager.groupColorOf('p', 'SPORTS'), 'red');
    expect(manager.groupColorOf('p', 'NEWS'), isNull);
    expect(manager.liveViewSignature(), isNot(before),
        reason: 'the groups column shows it at once');
    expect(storage.getGroupColors('p'), {'SPORTS': 'red'});

    expect(await manager.renameLiveGroup('p', 'SPORTS', 'Sport'), 'Sport');
    expect(manager.groupColorOf('p', 'Sport'), 'red');
    expect(manager.groupColorOf('p', 'SPORTS'), isNull);

    final set = manager.liveViewSignature();
    await manager.setGroupColor('p', 'Sport', null);
    expect(manager.groupColorOf('p', 'Sport'), isNull);
    expect(manager.liveViewSignature(), isNot(set));
    expect(storage.getGroupColors('p'), isEmpty);
  });

  test('colours are each viewer\'s own', () async {
    await manager.setGroupColor('p', 'SPORTS', 'blue');
    await storage.setActiveViewerId('kid');
    manager.applyActiveViewer();
    expect(manager.groupColorOf('p', 'SPORTS'), isNull);
    await manager.setGroupColor('p', 'SPORTS', 'green');
    await storage.setActiveViewerId(AppConstants.mainViewerId);
    manager.applyActiveViewer();
    expect(manager.groupColorOf('p', 'SPORTS'), 'blue');
  });

  test('own groups keep their colour through a rename, lose it on delete',
      () async {
    final title = await manager.createUserGroup('Mine');
    await manager.setGroupColor(null, title, 'pink');
    expect(manager.groupColorOf(null, title), 'pink');
    expect(manager.groupColorOf('p', title), isNull);

    expect(await manager.renameUserGroup(title, 'Ours'), 'Ours');
    expect(manager.groupColorOf(null, 'Ours'), 'pink');
    expect(storage.getGroupColors(GroupColor.ownScope), {'Ours': 'pink'});

    await manager.deleteUserGroup('Ours');
    expect(manager.groupColorOf(null, 'Ours'), isNull);
    expect(storage.getGroupColors(GroupColor.ownScope), isEmpty);
  });

  test('synced while the app runs, kept with the group star', () {
    expect(StorageService.isLiveSyncKey('${AppConstants.keyGroupColors}_p'),
        isTrue);
  });
}
