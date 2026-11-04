import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/sync_merge.dart';
import 'package:nox_iptv/services/sync_profile_match.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> json(Object data) => {'t': 's', 'v': jsonEncode(data)};
Map<String, Object?> list(List<String> data) => {'t': 'l', 'v': data};
Map<String, Object?> profile(String id, String name,
        {bool restricted = false}) =>
    ViewerProfile(
            id: id,
            name: name,
            colorIndex: 1,
            isRestricted: restricted,
            createdAt: DateTime(2026))
        .toJson();
Map<String, Object?> profiles(List<Map<String, Object?>> rows) =>
    {AppConstants.keyViewerProfiles: json(rows)};
List<dynamic> rows(Map<String, Object?> data) =>
    jsonDecode((data[AppConstants.keyViewerProfiles] as Map)['v'] as String)
        as List;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('case/accent/trim matches are exact, including decomposed names', () {
    for (final names in [
      [' ÉLÉONORE ', 'eleonore'],
      ['ELE\u0301ONORE', 'Éléonore'],
      [' ΠΑΙΔΙΆ ', 'παιδια'],
      ['Niños', 'NINOS'],
    ]) {
      final local = profiles([profile('local', names.first)]);
      final remote =
          profiles([profile('remote', names.last, restricted: true)]);
      final before = jsonEncode(local), serverBefore = jsonEncode(remote);
      final result = matchSyncProfiles(local, remote);
      expect(rows(result).single, rows(remote).single);
      expect(jsonEncode(local), before);
      expect(jsonEncode(remote), serverBefore);
    }
    for (final names in [
      ['Jean-Luc', 'Jean Luc'],
      ['Kid  One', 'Kid One'],
      ['Kids 🐱', 'Kids 🐶'],
      [' ', ''],
      ['Kid', 'Kids'],
    ]) {
      final local = profiles([profile('local', names.first)]);
      expect(
          identical(
              matchSyncProfiles(
                  local, profiles([profile('remote', names.last)])),
              local),
          isTrue);
    }
  });

  test('Main never remaps, nor does a non-Main viewer map into Main', () {
    final local = profiles([profile('main', 'Kids'), profile('local', 'Main')]);
    final remote =
        profiles([profile('main', 'Main'), profile('remote', 'Kids')]);
    expect(matchSyncProfiles(local, remote), local);
  });

  test('only first local name claims remote; all other data survives', () {
    final local = {
      ...profiles([profile('a', 'Kids'), profile('b', 'KÍDS')]),
      'nox_favorites__vp_a': list(['p::one']),
      'nox_favorites__vp_b': list(['p::two']),
      'file:recently_played_vp_a': json([
        {'id': 'p::one'}
      ]),
      'file:recently_played_vp_b': json([
        {'id': 'p::two'}
      ]),
    };
    final result =
        matchSyncProfiles(local, profiles([profile('remote', 'kids')]));
    expect(rows(result).map((p) => p['id']), ['remote', 'b']);
    expect(result['nox_favorites__vp_remote'], list(['p::one']));
    expect(result['nox_favorites__vp_b'], list(['p::two']));
    expect(result['file:recently_played_vp_remote'],
        local['file:recently_played_vp_a']);
    expect(result['file:recently_played_vp_b'],
        local['file:recently_played_vp_b']);
  });

  test('shared ids retain identity and ambiguous remote names are not guessed',
      () {
    final local =
        profiles([profile('local', 'Kids'), profile('remote', 'Kids')]);
    expect(
        matchSyncProfiles(local, profiles([profile('remote', 'Kids')])), local);
    final onlyLocal = profiles([profile('local', 'Kids')]);
    expect(
        matchSyncProfiles(onlyLocal,
            profiles([profile('r1', 'Kids'), profile('r2', 'KÍDS')])),
        onlyLocal);
  });

  test('all exact viewer suffixes remap; Main and overlapping ids stay intact',
      () {
    final local = {
      ...profiles([profile('local', 'Kids')]),
      'nox_favorites': list(['main::one']),
      'nox_favorites__vp_local': list(['p::one']),
      'nox_hidden_groups_p__vp_local': list(['Sport']),
      'nox_last_position_p::vod_3__vp_local': {'t': 'i', 'v': 123},
      'nox_favorites__vp_local2': list(['p::two']),
      'file:recently_played': json([
        {'id': 'p::main'}
      ]),
      'file:recently_played_vp_local': json([
        {'id': 'p::one'}
      ]),
      'file:recently_played_vp_local2': json([
        {'id': 'p::two'}
      ]),
      'unknown_local': json('local'),
    };
    final result =
        matchSyncProfiles(local, profiles([profile('remote', 'Kids')]));
    for (final key in [
      'nox_favorites',
      'nox_favorites__vp_local2',
      'file:recently_played',
      'file:recently_played_vp_local2',
      'unknown_local'
    ]) {
      expect(result[key], local[key]);
    }
    expect(result['nox_favorites__vp_remote'], list(['p::one']));
    expect(result['nox_hidden_groups_p__vp_remote'], list(['Sport']));
    expect(
        result['nox_last_position_p::vod_3__vp_remote'], {'t': 'i', 'v': 123});
    expect(result.containsKey('nox_favorites__vp_local'), isFalse);
  });

  test('explicit JSON viewer references change, other ids and strings do not',
      () {
    final data = {
      'viewerId': 'local',
      'profileId': 'local',
      'nested': [
        {
          'viewer_id': 'local',
          'profile_ids': ['local', 'other']
        }
      ],
      'id': 'local',
      'userId': 'local',
      'name': 'local',
      'password': 'local',
      'url': 'https://example.invalid/local',
      'text': '__vp_local'
    };
    final local = {
      ...profiles([profile('local', 'Kids')]),
      'fixture': json(data)
    };
    final result =
        matchSyncProfiles(local, profiles([profile('remote', 'Kids')]));
    final changed =
        jsonDecode((result['fixture'] as Map)['v'] as String) as Map;
    expect(changed['viewerId'], 'remote');
    expect(changed['profileId'], 'remote');
    expect(changed['nested'], [
      {
        'viewer_id': 'remote',
        'profile_ids': ['remote', 'other']
      }
    ]);
    for (final key in ['id', 'userId', 'name', 'password', 'url', 'text']) {
      expect(changed[key], data[key]);
    }
  });

  test(
      'orphan canonical-key collisions combine lists and retain canonical scalars',
      () {
    final local = {
      ...profiles([profile('local', 'Kids')]),
      'nox_favorites__vp_local': list(['p::one']),
      'nox_favorites__vp_remote': list(['p::two']),
      'nox_palette_id__vp_local': {'t': 's', 'v': 'aqua'},
      'nox_palette_id__vp_remote': {'t': 's', 'v': 'gold'},
    };
    final result =
        matchSyncProfiles(local, profiles([profile('remote', 'Kids')]));
    expect(result['nox_favorites__vp_remote'], list(['p::two', 'p::one']));
    expect(result['nox_palette_id__vp_remote'], {'t': 's', 'v': 'gold'});
  });

  test('missing, malformed and duplicate-id definitions remain untouched', () {
    final local = profiles([profile('local', 'Kids')]);
    for (final bad in [
      const <String, Object?>{},
      {
        AppConstants.keyViewerProfiles: {'t': 's', 'v': '{broken'}
      },
      profiles([profile('remote', 'Kids'), profile('remote', 'Kids')])
    ]) {
      expect(identical(matchSyncProfiles(local, bad), local), isTrue);
      expect(identical(matchSyncProfiles(bad, local), bad), isTrue);
    }
  });

  test(
      'StorageService join preserves per-viewer prefs and takes synced restrictions/PIN',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      ViewerProfile.fromJson(profile('local', ' Éléonore ')),
      ViewerProfile.fromJson(profile('duplicate', 'Eleonore'))
    ]);
    await storage.setParentalPin({'hash': 'local-fixture'});
    await storage.setFavorites({'p::main'});
    await storage.setActiveViewerId('local');
    await storage.setFavorites({'p::one'});
    await storage.setShownGroups('p', {'Kids'});
    await storage.setHiddenChannels('p', {'raw1'});
    await storage.setLastPosition('p::vod_1', 42000);
    await storage.setPaletteId('aqua');
    final source = storage.exportForSync();
    final remote = {
      ...profiles([
        profile('main', 'Main'),
        profile('remote', 'eleonore', restricted: true)
      ]),
      AppConstants.keyParentalPin: json({'hash': 'server-fixture'}),
      'nox_favorites__vp_remote': list(['p::two'])
    };
    final matched = matchSyncProfiles(source, remote);
    final merged = mergeSync(
        base: null,
        local: matched,
        remote: SyncSnapshot(remote, const {}),
        pending: const {});
    await storage.applySyncChanges(merged.values,
        source.keys.where((k) => !merged.values.containsKey(k)).toSet());
    expect(storage.getViewerProfiles().map((p) => p.id),
        ['main', 'remote', 'duplicate']);
    expect(
        storage
            .getViewerProfiles()
            .firstWhere((p) => p.id == 'remote')
            .isRestricted,
        isTrue);
    expect(storage.getParentalPin(), {'hash': 'server-fixture'});
    await storage.setActiveViewerId('remote');
    expect(storage.getFavorites(), {'p::two', 'p::one'});
    expect(storage.getShownGroups('p'), {'Kids'});
    expect(storage.getHiddenChannels('p'), {'raw1'});
    expect(storage.getLastPosition('p::vod_1'), 42000);
    expect(storage.getPaletteId(), 'aqua');
    await storage.setActiveViewerId('main');
    expect(storage.getFavorites(), {'p::main'});
  });
  test(
      'playlist and profile identity mappings compose, including held snapshots',
      () {
    Map<String, Object?> playlists(String id) => json([
          {
            'id': id,
            'mode': 'xtream',
            'xtreamServer': 'https://example.invalid',
            'xtreamUsername': 'fixture'
          }
        ]);
    final local = {
      ...profiles([profile('v-local', 'Kids'), profile('v-other', 'KÍDS')]),
      'nox_playlists': playlists('p-local'),
      'nox_hidden_groups_p-local__vp_v-local': list(['Sport']),
      'nox_favorites__vp_v-local': list(['p-local::live_1']),
      'file:recently_played_vp_v-local': json([
        {'id': 'p-local::vod_2', 'playlistId': 'p-local', 'rawId': 'vod_2'}
      ])
    };
    final remote = {
      ...profiles([profile('v-remote', 'Kids', restricted: true)]),
      'nox_playlists': playlists('p-remote')
    };
    final result = matchSyncJoin(local, remote);
    expect(rows(result).map((p) => p['id']), ['v-remote', 'v-other']);
    expect(result['nox_hidden_groups_p-remote__vp_v-remote'], list(['Sport']));
    expect(result['nox_favorites__vp_v-remote'], list(['p-remote::live_1']));
    expect(
        result['file:recently_played_vp_v-remote'],
        json([
          {'id': 'p-remote::vod_2', 'playlistId': 'p-remote', 'rawId': 'vod_2'}
        ]));
    // Once uploaded, the preserved duplicate is another server profile with
    // the same name. Exclude that already-shared id from alias candidates.
    final merged = mergeSync(
        base: null,
        local: result,
        remote: SyncSnapshot(remote, const {}),
        pending: const {}).values;
    expect(matchSyncJoin(merged, merged, source: local), merged);
    final repeat = matchSyncJoin(local, merged, source: local);
    expect(rows(repeat).map((p) => p['id']), ['v-remote', 'v-other']);
    expect(repeat['nox_favorites__vp_v-remote'], list(['p-remote::live_1']));
  });
}
