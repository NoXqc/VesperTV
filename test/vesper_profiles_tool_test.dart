import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/de.dart';
import 'package:nox_iptv/l10n/el.dart';
import 'package:nox_iptv/l10n/es.dart';
import 'package:nox_iptv/l10n/fr.dart';
import 'package:nox_iptv/l10n/it.dart';
import 'package:nox_iptv/l10n/pl.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Host implements VesperHost {
  bool answer = true;
  final questions = <String>[];
  @override
  Future<bool> confirm(String question, Map<String, Object?> args) async {
    var s = question;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    questions.add(s);
    return answer;
  }

  @override
  Future<void> playChannel(Channel channel) async {}
  @override
  Future<void> openSeries(XtreamSeries series) async {}
  @override
  Future<bool> openSection(String section, {String? query}) async => true;
  @override
  void showMessage(String text) {}
}

/// The TV's profiles and PIN pad: [pinAnswer] is what the viewer "types".
class _Profiles implements VesperProfileControl {
  _Profiles(this.list);
  final List<ViewerProfile> list;
  String activeId = ViewerProfile.mainId;
  @override
  bool pinSet = true;
  bool pinAnswer = true;
  bool newPinAnswer = true;
  int pinAsked = 0;
  int newPinAsked = 0;
  final switches = <(String, bool)>[];

  @override
  List<ViewerProfile> get profiles => list;
  @override
  ViewerProfile get active => list.firstWhere((p) => p.id == activeId);
  @override
  Future<bool> askPin() async {
    pinAsked++;
    return pinAnswer;
  }

  @override
  Future<bool> newPin() async {
    newPinAsked++;
    if (newPinAnswer) pinSet = true;
    return newPinAnswer;
  }

  @override
  Future<bool> switchTo(String id, {bool unlocked = false}) async {
    switches.add((id, unlocked));
    activeId = id;
    return true;
  }

  @override
  Future<ViewerProfile> create(String name,
      {required bool kid, required int colour}) async {
    final p = ViewerProfile(
        id: 'vp${list.length}',
        name: name,
        colorIndex: colour,
        isRestricted: kid,
        createdAt: DateTime(2026));
    list.add(p);
    return p;
  }

  @override
  Future<void> rename(String id, String name) async =>
      list.firstWhere((p) => p.id == id).name = name;
  @override
  Future<bool> delete(String id) async {
    list.removeWhere((p) => p.id == id);
    return true;
  }
}

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
  Future<void> deleteCacheFile(String name) async {
    final f = File('${dir.path}/$name.json');
    if (await f.exists()) await f.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistManager manager;
  late StorageService storage;
  late VesperToolbox box;
  late _Host host;
  late _Profiles profiles;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_profiles_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="k1" group-title="KIDS",Treehouse',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="k2" group-title="Kids Cartoons",Cartoon Network',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="s1" group-title="SPORTS",TSN 1',
      'http://x/3.ts',
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
    final prefs = AppPreferences(storage);
    await prefs.init();
    host = _Host();
    profiles = _Profiles([
      ViewerProfile.main(),
      ViewerProfile(
          id: 'vp1',
          name: 'Emma',
          colorIndex: 1,
          isRestricted: true,
          createdAt: DateTime(2026)),
      ViewerProfile(
          id: 'vp2',
          name: 'Dad',
          colorIndex: 2,
          isRestricted: false,
          createdAt: DateTime(2026)),
    ]);
    box = VesperToolbox(
      playlist: manager,
      playback: PlaybackService(storage, manager),
      epg: EpgService(storage),
      storage: storage,
      prefs: prefs,
      host: host,
      profiles: profiles,
    );
  });

  test('list names the kids profile and the active one', () async {
    final r = await box.call('profiles', {'action': 'list'});
    final list = r['profiles'] as List;
    expect(list, hasLength(3));
    expect(list[1], containsPair('kids', true));
    expect(list[0], containsPair('active', true));
    expect(r['pin_set'], isTrue);
  });

  test('leaving a kids profile needs the PIN on the TV', () async {
    profiles.activeId = 'vp1';
    profiles.pinAnswer = false;
    final no =
        await box.call('profiles', {'action': 'switch', 'profile': 'main'});
    expect(no['error'], contains('PIN'));
    expect(profiles.switches, isEmpty);
    profiles.pinAnswer = true;
    final yes =
        await box.call('profiles', {'action': 'switch', 'profile': 'Main'});
    expect(yes['active'], 'Main', reason: '$yes');
    expect(profiles.switches.single, ('main', true));
  });

  test('switching into a kids profile needs no PIN', () async {
    final r =
        await box.call('profiles', {'action': 'switch', 'profile': 'emma'});
    expect(r['active'], 'Emma');
    expect(profiles.pinAsked, 0);
  });

  test('allowing groups to a kid asks the PIN even from Main', () async {
    final preview = await box.call('parental', {
      'action': 'allow_groups',
      'profile': 'Emma',
      'contains': 'kids',
      'preview': true,
    });
    expect(preview['groups'], unorderedEquals(['KIDS', 'Kids Cartoons']));
    expect(profiles.pinAsked, 0, reason: 'a preview changes nothing');
    expect(storage.getShownGroupsFor('vp1', 'p'), isEmpty);

    profiles.pinAnswer = false;
    final no = await box.call('parental',
        {'action': 'allow_groups', 'profile': 'Emma', 'contains': 'kids'});
    expect(no['error'], contains('nothing changed'));
    expect(storage.getShownGroupsFor('vp1', 'p'), isEmpty);

    profiles.pinAnswer = true;
    final yes = await box.call('parental',
        {'action': 'allow_groups', 'profile': 'Emma', 'contains': 'kids'});
    expect(yes['changed'], 2, reason: '$yes');
    expect(storage.getShownGroupsFor('vp1', 'p'), {'KIDS', 'Kids Cartoons'});
    // Main's own view is untouched.
    expect(storage.getShownGroups('p'), isEmpty);
  });

  test('blocking groups from a parent profile needs no PIN', () async {
    await storage.setShownGroupsFor('vp1', 'p', {'KIDS', 'Kids Cartoons'});
    final r = await box.call('parental',
        {'action': 'block_groups', 'profile': 'Emma', 'contains': 'cartoons'});
    expect(r['blocked'], ['Kids Cartoons'], reason: '$r');
    expect(profiles.pinAsked, 0);
    expect(storage.getShownGroupsFor('vp1', 'p'), {'KIDS'});
    final status = await box.call('parental', {'action': 'status'});
    final kid = (status['kids_profiles'] as List).single as Map;
    expect(kid['allowed_groups'], ['KIDS']);
  });

  test('allow_groups refuses a normal profile', () async {
    final r = await box.call('parental',
        {'action': 'allow_groups', 'profile': 'Dad', 'contains': 'kids'});
    expect(r['error'], contains('not a kids profile'));
  });

  test('a kids profile without a PIN gets one set on the TV first', () async {
    profiles.pinSet = false;
    profiles.newPinAnswer = false;
    final no = await box
        .call('profiles', {'action': 'create', 'name': 'Leo', 'kids': true});
    expect(no['error'], contains('PIN'));
    expect(profiles.list, hasLength(3));
    profiles.newPinAnswer = true;
    final yes = await box
        .call('profiles', {'action': 'create', 'name': 'Leo', 'kids': true});
    expect((yes['created'] as Map)['kids'], isTrue, reason: '$yes');
    expect(profiles.newPinAsked, 2);
  });

  test('delete: never Main, always asked on the TV, PIN for a kid', () async {
    final main =
        await box.call('profiles', {'action': 'delete', 'profile': 'Main'});
    expect(main['error'], contains('cannot be deleted'));
    host.answer = false;
    final no =
        await box.call('profiles', {'action': 'delete', 'profile': 'Emma'});
    expect(no['error'], contains('said no'));
    expect(host.questions.single, contains('Delete the profile Emma'));
    host.answer = true;
    final yes =
        await box.call('profiles', {'action': 'delete', 'profile': 'Emma'});
    expect(yes['deleted'], 'Emma');
    expect(profiles.pinAsked, 1);
  });

  test('change_pin asks the current PIN, then a new one, on the TV', () async {
    final r = await box.call('parental', {'action': 'change_pin'});
    expect(r['pin_changed'], isTrue);
    expect(profiles.pinAsked, 1);
    expect(profiles.newPinAsked, 1);
  });

  test('no tool takes a PIN', () {
    for (final t in vesperTools) {
      final props = (t.schema['properties'] as Map?) ?? const {};
      for (final key in props.keys) {
        expect('$key'.toLowerCase(), isNot(contains('pin')), reason: t.name);
      }
    }
  });

  test('the profiles manual names every action', () {
    final manual = vesperHelpTopics['profiles']!;
    for (final name in ['profiles', 'parental']) {
      final tool = vesperTools.firstWhere((t) => t.name == name);
      final actions =
          ((tool.schema['properties'] as Map)['action'] as Map)['enum'] as List;
      for (final a in actions) {
        expect(manual, contains('- $a'), reason: '$name $a');
      }
    }
  });

  test('every new TV prompt is translated', () {
    const texts = [
      'An AI app wants {game} to play on {channel} in {tab}.',
      'An AI app wants to set the channels of {count} games in {tab}.',
      'An AI app wants to switch to the profile {name}.',
      'An AI app wants to create the kids profile {name}.',
      'An AI app wants to create the profile {name}.',
      'An AI app wants to rename the profile {name} to {new}.',
      'Delete the profile {name}? Its favourites and history are deleted '
          'too.',
      'An AI app wants to let {name} see {count} groups ({words}).',
      'An AI app wants to block {count} groups ({words}) for {name}.',
      'An AI app wants to change the parental PIN.',
    ];
    for (final (name, dictionary) in [
      ('fr', kFr),
      ('de', kDe),
      ('es', kEs),
      ('it', kIt),
      ('el', kEl),
      ('pl', kPl),
    ]) {
      expect([
        for (final t in texts)
          if (!dictionary.containsKey(t)) t
      ], isEmpty, reason: name);
    }
  });
}
