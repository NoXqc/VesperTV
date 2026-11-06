import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/services/cloud_sync.dart';
import 'package:nox_iptv/services/cloud_sync_service.dart';
import 'package:nox_iptv/services/cloud_transfer.dart';
import 'package:nox_iptv/services/device_transfer.dart';
import 'package:nox_iptv/services/phone_pairing_service.dart'
    show kRelayAppHeaders;
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/sync_merge.dart' show SyncSnapshot;

class _MemoryStore implements SyncStore {
  SyncState? state;
  @override
  Future<SyncState?> load() async => state;
  @override
  Future<void> save(SyncState? s) async => state = s;
}

/// One device's synced preferences.
class _Device implements SyncData {
  _Device(this.values);
  final Map<String, Object?> values;
  final store = _MemoryStore();
  late final engine = SyncEngine(store, this,
      newestFirst: isHistoryKey, keepWhenMissing: (k) => k.startsWith('file:'));

  @override
  Future<Map<String, Object?>> exportForSync() async => Map.of(values);

  @override
  Future<void> applySyncChanges(
      Map<String, Object?> changed, Set<String> removed) async {
    values
      ..removeWhere((k, _) => removed.contains(k))
      ..addAll(changed);
  }
}

Map<String, Object?> l(List<String> v) => {'t': 'l', 'v': v};
Map<String, Object?> i(int v) => {'t': 'i', 'v': v};

/// Runs `tools/pair_relay/relay.py` locally (skipped without python) and
/// syncs two devices through it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Process? relay;
  Directory? vault;

  setUpAll(() async {
    HttpOverrides.global = null; // the test binding fakes HTTP otherwise
    vault = await Directory.systemTemp.createTemp('sync_vault');
    const port = 18932;
    for (final exe in ['python3', 'python']) {
      try {
        relay = await Process.start(exe, [
          'tools/pair_relay/relay.py'
        ], environment: {
          'PAIR_PORT': '$port',
          'PAIR_PAGE': 'assets/pair/pair.html',
          'PAIR_VAULT_DIR': vault!.path,
          // These include legacy requests without device ids; strict mode
          // is covered separately by the relay unittest suite.
          'PAIR_SYNC_REQUIRE_DEVICE': '0',
        });
        break;
      } on ProcessException {
        continue;
      }
    }
    cloudTransferBase = 'http://127.0.0.1:$port';
    for (var n = 0; n < 50; n++) {
      try {
        final s = await Socket.connect('127.0.0.1', port);
        s.destroy();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    relay?.kill();
    relay = null;
  });

  tearDownAll(() async {
    relay?.kill();
    await vault?.delete(recursive: true);
  });

  test('recovery code round-trips and forgives typing', () {
    final secret = newSyncSecret();
    final code = syncRecoveryCode(secret);
    expect(code.replaceAll('-', '').length, 26);
    expect(parseSyncRecoveryCode(code), secret);
    expect(
        parseSyncRecoveryCode(code.toLowerCase().replaceAll('-', ' ')), secret);
    expect(parseSyncRecoveryCode('${code}X'), isNull);
  });

  test('two devices: favourites and positions reach the other one', () async {
    if (relay == null) return markTestSkipped('python not found');
    final a = _Device({
      'fav': l(['ch1']),
      'pos_ep1': i(120),
    });
    final b = _Device({
      'fav': l(['ch9']),
    });
    final secret = newSyncSecret();
    await a.engine.start(secret);
    final first = await a.engine.sync();
    expect(first!.pushed, isTrue);

    // B joins with A's secret: lists merge, A's values arrive.
    await b.engine.start(secret);
    await b.engine.sync();
    expect(b.values['fav'], l(['ch1', 'ch9']));
    expect(b.values['pos_ep1'], i(120));

    // A picks up B's favourite; then both change things.
    await a.engine.sync();
    expect(a.values['fav'], l(['ch1', 'ch9']));
    a.values['fav'] = l(['ch1', 'ch9', 'ch2']);
    b.values['pos_ep1'] = i(900);
    b.values['fav'] = l(['ch9']); // B removed ch1
    await a.engine.sync();
    await b.engine.sync();
    await a.engine.sync();
    expect(a.values['fav'], l(['ch9', 'ch2']));
    expect(b.values['fav'], l(['ch9', 'ch2']));
    expect(a.values['pos_ep1'], i(900));

    // Nothing new: a cheap 304, no upload.
    final idle = await a.engine.sync();
    expect(idle!.pushed, isFalse);
    expect(idle.pulled, 0);
  });

  test(
      'joining identical playlists remaps ids; live join holds the migration together',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    Map<String, Object?> playlists(String id) => {
          't': 's',
          'v': jsonEncode([
            {
              'id': id,
              'mode': 'xtream',
              'xtreamServer': 'https://example.invalid',
              'xtreamUsername': 'fixture',
              'name': id
            }
          ])
        };
    for (final liveJoin in [false, true]) {
      final a = _Device({
        'nox_playlists': playlists('remote'),
        'nox_favorites': l(['remote::live_1'])
      });
      final b = _Device({
        'nox_playlists': playlists('local'),
        'nox_favorites': l(['local::live_2']),
        'nox_last_position_local::vod_3': i(42000)
      });
      final secret = newSyncSecret();
      await a.engine.start(secret);
      await a.engine.sync();
      await b.engine.start(secret);
      final result = await b.engine
          .sync(applyNow: liveJoin ? StorageService.isLiveSyncKey : null);
      if (liveJoin) {
        expect(result!.pulled, 0);
        expect(result.deferred, greaterThan(0));
        expect(b.values['nox_playlists'], playlists('local'));
        expect(b.values['nox_favorites'], l(['local::live_2']));
        await b.engine.sync(applyNow: StorageService.isLiveSyncKey);
        // Still held as one migration, including the old key's removal.
        expect(b.values['nox_playlists'], playlists('local'));
        expect(b.values['nox_favorites'], l(['local::live_2']));
        b.values['nox_favorites'] = l(['local::live_2', 'local::live_4']);
        await b.engine.sync(applyNow: StorageService.isLiveSyncKey);
        await a.engine.sync();
        expect(
            a.values['nox_favorites'], l(['remote::live_2', 'remote::live_4']));
        await b.engine.sync();
      }
      expect(b.values['nox_playlists'], playlists('remote'));
      expect(
          b.values['nox_favorites'],
          l([
            if (!liveJoin) 'remote::live_1',
            'remote::live_2',
            if (liveJoin) 'remote::live_4'
          ]));
      expect(b.values['nox_last_position_remote::vod_3'], i(42000));
      expect(b.values.containsKey('nox_last_position_local::vod_3'), isFalse);
      await a.engine.sync();
      expect(a.values, b.values);
      expect((await b.engine.sync())!.pushed, isFalse);
    }
  });

  test('an upload from another device in between is merged, not overwritten',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    final a = _Device({'x': i(1)});
    final b = _Device({'y': i(2)});
    final secret = newSyncSecret();
    await a.engine.start(secret);
    await a.engine.sync();
    await b.engine.start(secret);
    await b.engine.sync();
    // A changes while B already uploaded on top of A's version: A's
    // first PUT is stale, it re-fetches and merges.
    a.values['x'] = i(5);
    b.values['y'] = i(6);
    await b.engine.sync();
    final r = await a.engine.sync();
    expect(r!.pushed, isTrue);
    expect(a.values, {'x': i(5), 'y': i(6)});
    await b.engine.sync();
    expect(b.values, {'x': i(5), 'y': i(6)});
  });

  // +609 join on a phone (LOG-9VX59U): the isolate that seals an upload
  // copied the client's live HTTP connections and threw "object is
  // unsendable". A request still open on the same client reproduces it.
  test('upload and download while the client has a request open', () async {
    if (relay == null) return markTestSkipped('python not found');
    final client = await SyncClient.forSecret(newSyncSecret());
    final open = client.fetch();
    final version = await client.put(SyncSnapshot({'x': i(1)}, const {}), 0);
    await open;
    final pending = client.fetch();
    final remote = await client.fetch();
    await pending;
    expect(version, 1);
    expect(remote.snapshot!.values, {'x': i(1)});
    await client.delete();
  });

  test('relay: wrong token 403, stale If-Match 412, unchanged 304', () async {
    if (relay == null) return markTestSkipped('python not found');
    final client = await SyncClient.forSecret(newSyncSecret());
    final uri = Uri.parse('$cloudTransferBase/api/sync/${client.keys.id}');
    final body = List.filled(64, 1);
    Future<http.Response> put(String token, String ifMatch) => http.put(uri,
        headers: {
          ...kRelayAppHeaders,
          'X-Vault-Token': token,
          'If-Match': ifMatch
        },
        body: body);
    final token = client.keys.token;
    expect((await put(token, '"0"')).statusCode, 204);
    expect((await put(token, '"0"')).statusCode, 412);
    expect((await put('${token}x', '"1"')).statusCode, 403);
    final res = await http
        .get(uri, headers: {...kRelayAppHeaders, 'If-None-Match': '"1"'});
    expect(res.statusCode, 304);
    await client.delete();
    expect((await http.get(uri, headers: kRelayAppHeaders)).statusCode, 404);
    client.close();
  });

  test('keys a running app can\'t reload wait for the next cold start',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    Map<String, Object?> s(String v) => {'t': 's', 'v': v};
    final a = _Device({
      'fav': l(['ch1']),
      'theme': s('gold')
    });
    final b = _Device({});
    final secret = newSyncSecret();
    await a.engine.start(secret);
    await a.engine.sync();
    await b.engine.start(secret);
    await b.engine.sync();
    bool live(String k) => k == 'fav';

    a.values['fav'] = l(['ch1', 'ch2']);
    a.values['theme'] = s('red');
    await a.engine.sync();
    final r = await b.engine.sync(applyNow: live);
    expect(b.values['fav'], l(['ch1', 'ch2']));
    expect(b.values['theme'], s('gold')); // held
    expect(r!.deferred, 1);
    // B keeps syncing while held: its old theme is never pushed back.
    b.values['fav'] = l(['ch1', 'ch2', 'ch3']);
    await b.engine.sync(applyNow: live);
    await a.engine.sync();
    expect(a.values['theme'], s('red'));
    expect(a.values['fav'], l(['ch1', 'ch2', 'ch3']));
    // Cold start: the held theme is written.
    await b.engine.sync();
    expect(b.values['theme'], s('red'));
    expect(b.store.state!.deferred, isEmpty);

    // Held again, then edited here: the local edit wins.
    a.values['theme'] = s('blue');
    await a.engine.sync();
    await b.engine.sync(applyNow: live);
    expect(b.values['theme'], s('red'));
    b.values['theme'] = s('green');
    await b.engine.sync(applyNow: live);
    await a.engine.sync();
    expect(a.values['theme'], s('green'));
  });

  test('file store: saved state reads back, also in a new store', () async {
    final dir = await Directory.systemTemp.createTemp('sync_store_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/sync.json';
    final store = FileSyncStore(path);
    expect(await store.load(), isNull);
    final state = SyncState(
        secret: newSyncSecret(),
        deviceId: 'dev1',
        version: 7,
        base: SyncSnapshot({'fav': l(['ch1'])}, const {'fav': 5}),
        pending: const {'fav': 9});
    await store.save(state);
    final json = jsonEncode(state.toJson());
    expect(jsonEncode((await store.load())!.toJson()), json);
    expect(jsonEncode((await FileSyncStore(path).load())!.toJson()), json);
    await store.save(null);
    expect(await store.load(), isNull);
    expect(await FileSyncStore(path).load(), isNull);
  });

  test('the goal-alert checkpoint never syncs or transfers', () async {
    SharedPreferences.setMockInitialValues({
      'nox_favorites': ['p1::ch1'],
      'vesper_goal_phone_checkpoint': '{"a":1}',
      'vesper_goal_phone_checkpoint_kid': '{"b":2}',
    });
    final storage = StorageService();
    await storage.init();
    final synced = storage.exportForSync();
    expect(synced.containsKey('nox_favorites'), isTrue);
    expect(synced.keys.where((k) => k.startsWith('vesper_goal_phone')),
        isEmpty);
    expect(
        storage
            .exportForTransfer()
            .keys
            .where((k) => k.startsWith('vesper_goal_phone')),
        isEmpty);
  });

  test('cold start only pulls: own changes go up after the launch', () async {
    if (relay == null) return markTestSkipped('python not found');
    final a = _Device({'fav': l(['ch1'])});
    final b = _Device({});
    await a.engine.start(newSyncSecret());
    await a.engine.sync();
    await b.engine.start(a.store.state!.secret);
    await b.engine.sync();

    // Changed here, nothing new on the server: nothing uploaded yet.
    a.values['fav'] = l(['ch1', 'ch2']);
    final cold = await a.engine.sync(pushLocal: false);
    expect(cold!.pushed, isFalse);
    expect(cold.pushLater, isTrue);
    expect(await a.engine.hasLocalChanges(), isTrue);
    await b.engine.sync();
    expect(b.values['fav'], l(['ch1']));

    // The next ordinary sync sends it.
    final later = await a.engine.sync();
    expect(later!.pushed, isTrue);
    await b.engine.sync();
    expect(b.values['fav'], l(['ch1', 'ch2']));

    // Something new on the server: a cold sync pulls it (and merges).
    b.values['fav'] = l(['ch1', 'ch2', 'ch3']);
    await b.engine.sync();
    final pulled = await a.engine.sync(pushLocal: false);
    expect(pulled!.pulled, 1);
    expect(a.values['fav'], l(['ch1', 'ch2', 'ch3']));
  });

  test('app service: favourites apply live, playlists at the next launch',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    SharedPreferences.setMockInitialValues({
      'nox_favorites': ['p1::ch1'],
      'nox_playlists': '[{"id":"p1","name":"Home"}]',
      'nox_active_viewer': 'main',
    });
    final storage = StorageService();
    await storage.init();
    String playlistsJson() =>
        (storage.exportForSync()['nox_playlists'] as Map)['v'] as String;
    final store = _MemoryStore();
    final service = CloudSyncService(storage, store: store);
    await service.init();
    await service.setUp();
    expect(service.status, SyncStatus.on);
    final code = (await service.recoveryCode())!;

    // A second device joins with the recovery code, changes both.
    final other = _Device({});
    await other.engine.start(parseSyncRecoveryCode(code)!);
    await other.engine.sync();
    expect(other.values['nox_favorites'], l(['p1::ch1']));
    expect(other.values.containsKey('nox_active_viewer'), isFalse);
    other.values['nox_favorites'] = l(['p1::ch1', 'p1::ch2']);
    other.values['nox_playlists'] = {
      't': 's',
      'v': '[{"id":"p1","name":"Home renamed"}]'
    };
    await other.engine.sync();

    Set<String>? reloaded;
    service.onApplied = (keys) => reloaded = keys;
    service.startAutomatic();
    await service.syncNow();
    expect(storage.getFavorites(), {'p1::ch1', 'p1::ch2'});
    expect(reloaded, {'nox_favorites'});
    expect(playlistsJson(), contains('"Home"')); // held
    expect(service.restartNeeded, isTrue); // Sync screen: Restart now
    service.dispose();

    // Next launch: the sync before the services load writes it.
    final relaunched = CloudSyncService(storage, store: store);
    await relaunched.init();
    await relaunched.syncBeforeLoad();
    expect(playlistsJson(), contains('Home renamed'));
    relaunched.dispose();
  });

  test('Continue Watching: new titles lead, a wiped cache never deletes it',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    Map<String, Object?> history(List<String> ids) =>
        {'t': 's', 'v': '[${ids.map((id) => '{"id":"$id"}').join(',')}]'};
    List<String> idsIn(Object? tagged) => RegExp(r'"id":"([^"]+)"')
        .allMatches((tagged as Map)['v'] as String)
        .map((m) => m.group(1)!)
        .toList();
    final a = _Device({
      'file:recently_played': history(['old'])
    });
    final b = _Device({});
    final secret = newSyncSecret();
    await a.engine.start(secret);
    await a.engine.sync();
    await b.engine.start(secret);
    await b.engine.sync();
    expect(idsIn(b.values['file:recently_played']), ['old']);

    // B watches an episode, then A watches a movie.
    b.values['file:recently_played'] = history(['ep1', 'old']);
    await b.engine.sync();
    a.values['file:recently_played'] = history(['movie', 'old']);
    await a.engine.sync();
    expect(idsIn(a.values['file:recently_played']), ['movie', 'ep1', 'old']);
    await b.engine.sync();
    expect(idsIn(b.values['file:recently_played']), ['movie', 'ep1', 'old']);

    // Android empties B's cache folder: the history comes back, A keeps it.
    b.values.remove('file:recently_played');
    await b.engine.sync();
    expect(idsIn(b.values['file:recently_played']), ['movie', 'ep1', 'old']);
    await a.engine.sync();
    expect(idsIn(a.values['file:recently_played']), ['movie', 'ep1', 'old']);
  });

  test('a deleted profile history goes away everywhere', () {
    // Main's file and an existing profile's: kept when missing.
    expect(keepHistoryWhenMissing('file:recently_played', {'main'}), isTrue);
    expect(
        keepHistoryWhenMissing('file:recently_played_vp_kid', {'main', 'kid'}),
        isTrue);
    // Deleted profile: a real removal. Prefs keys never use this rule.
    expect(keepHistoryWhenMissing('file:recently_played_vp_kid', {'main'}),
        isFalse);
    expect(keepHistoryWhenMissing('nox_favorites', {'main'}), isFalse);
  });

  test('after Reset sync code, a device on the old code stops', () async {
    if (relay == null) return markTestSkipped('python not found');
    final a = _Device({'x': i(1)});
    final b = _Device({'x': i(1)});
    final old = newSyncSecret();
    await a.engine.start(old);
    await a.engine.sync();
    await b.engine.start(old);
    await b.engine.sync();
    final client = await SyncClient.forSecret(old);
    await client.revoke();
    client.close();
    b.values['x'] = i(2);
    await expectLater(b.engine.sync(), throwsA(isA<SyncRevoked>()));
  });

  test('a link code hands over the secret once; Transfer can\'t open it',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    final secret = newSyncSecret();
    final link = await uploadSyncLink(secret);
    expect(await downloadSyncLink(link.code), secret);
    await expectLater(
        downloadSyncLink(link.code),
        throwsA(isA<TransferException>()
            .having((e) => e.kind, 'kind', TransferError.notFound)));
    await expectLater(
        downloadCloudTransfer((await uploadSyncLink(secret)).code),
        throwsA(isA<TransferException>()
            .having((e) => e.kind, 'kind', TransferError.invalid)));
  });

  test(
      'device limit makes recovery/link joins full without keeping remote data',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    final secret = newSyncSecret();
    final devices = [
      for (var n = 0; n < 3; n++)
        _Device({
          'nox_favorites': l(['server::live'])
        })
    ];
    for (final device in devices) {
      await device.engine.start(secret);
      await device.engine.sync();
    }
    SharedPreferences.setMockInitialValues({
      'nox_favorites': ['local::live']
    });
    final storage = StorageService();
    await storage.init();
    final original = storage.exportForSync();
    final store = _MemoryStore();
    final service = CloudSyncService(storage, store: store);
    addTearDown(service.dispose);
    await service.init();
    final limit = isA<SyncDeviceLimit>().having((e) => e.max, 'max', 3);
    await expectLater(
        service.joinWithRecoveryCode(syncRecoveryCode(secret)), throwsA(limit));
    expect(service.status, SyncStatus.full);
    expect(service.syncing, isFalse);
    expect(store.state, isNull);
    expect(storage.exportForSync(), original);
    final link = await uploadSyncLink(secret);
    await expectLater(service.joinWithLinkCode(link.code), throwsA(limit));
    expect(service.status, SyncStatus.full);
    expect(store.state, isNull);
    expect(storage.exportForSync(), original);
    // A different code for the same secret never resets the device budget.
    await devices.first.engine.stop(leave: true);
    expect(
        await service.joinWithRecoveryCode(syncRecoveryCode(secret)), isTrue);
    expect(service.status, SyncStatus.on);
    expect(store.state!.deviceId, isNotNull);
    expect(storage.getFavorites(), {'server::live', 'local::live'});
  });

  test('service stop frees its relay slot and keeps the shared snapshot',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    SharedPreferences.setMockInitialValues({
      'nox_favorites': ['p::one']
    });
    final storage = StorageService();
    await storage.init();
    final store = _MemoryStore();
    final service = CloudSyncService(storage, store: store);
    addTearDown(service.dispose);
    await service.init();
    await service.setUp();
    final secret = List<int>.of(store.state!.secret);
    for (var n = 0; n < 2; n++) {
      final other = _Device({});
      await other.engine.start(secret);
      await other.engine.sync();
    }
    final fourth = _Device({});
    await fourth.engine.start(secret);
    await expectLater(fourth.engine.sync(), throwsA(isA<SyncDeviceLimit>()));
    await service.stop();
    expect(service.status, SyncStatus.off);
    expect(store.state, isNull);
    expect(storage.getFavorites(), {'p::one'});
    await fourth.engine.sync(); // succeeds only if stop sent the leave request
    expect(fourth.values['nox_favorites'], l(['p::one']));
  });

  test('leave is best effort when the relay refuses the request', () async {
    final device = _Device({});
    await device.engine.start(newSyncSecret());
    final id = device.store.state!.deviceId;
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'DELETE');
      expect(request.url.path, endsWith('/device'));
      expect(request.headers['X-Sync-Device'], id);
      return http.Response('', 503);
    });
    addTearDown(client.close);
    await device.engine.stop(leave: true, client: client);
    expect(calls, 1);
    expect(device.store.state, isNull);
  });

  test('reset changes the sync secret while preserving this device id',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    SharedPreferences.setMockInitialValues({
      'nox_favorites': ['p::one']
    });
    final storage = StorageService();
    await storage.init();
    final store = _MemoryStore();
    final service = CloudSyncService(storage, store: store);
    addTearDown(service.dispose);
    await service.init();
    await service.setUp();
    final old = store.state!;
    final recovery = await service.resetCode();
    expect(service.status, SyncStatus.on);
    expect(store.state!.deviceId, old.deviceId);
    expect(store.state!.secret, isNot(equals(old.secret)));
    expect(parseSyncRecoveryCode(recovery), store.state!.secret);
    final previous =
        await SyncClient.forSecret(old.secret, deviceId: old.deviceId);
    addTearDown(previous.close);
    await expectLater(previous.fetch(), throwsA(isA<SyncRevoked>()));
    expect(storage.getFavorites(), {'p::one'});
  });

  test('an old state without device gets one on sync and keeps it thereafter',
      () async {
    if (relay == null) return markTestSkipped('python not found');
    final device = _Device({'x': i(42)});
    final json = SyncState(secret: newSyncSecret()).toJson();
    expect(json.containsKey('device'), isFalse);
    device.store.state = SyncState.fromJson(json);
    expect(device.store.state!.deviceId, isNull);
    await device.engine.sync();
    final id = device.store.state!.deviceId;
    expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
    expect(device.values['x'], i(42));
    await device.engine.sync();
    expect(device.store.state!.deviceId, id);
    expect(SyncState.fromJson(device.store.state!.toJson())!.deviceId, id);
  });
}
