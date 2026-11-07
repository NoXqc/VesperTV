import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/cloud_sync.dart';
import 'package:nox_iptv/services/cloud_sync_service.dart';
import 'package:nox_iptv/services/cloud_transfer.dart';

class _Store implements SyncStore {
  SyncState? state;
  @override
  Future<SyncState?> load() async => state;
  @override
  Future<void> save(SyncState? value) async => state = value;
}

class _Device implements SyncData {
  _Device(this.values);
  final Map<String, Object?> values;
  final store = _Store();
  late final engine = SyncEngine(store, this, newestFirst: isHistoryKey);

  @override
  Future<Map<String, Object?>> exportForSync() async => Map.of(values);
  @override
  Future<void> applySyncChanges(
      Map<String, Object?> changed, Set<String> removed) async {
    values
      ..removeWhere((key, _) => removed.contains(key))
      ..addAll(changed);
  }
}

Map<String, Object?> _json(Object value) => {'t': 's', 'v': jsonEncode(value)};
Map<String, Object?> _list(List<String> value) => {'t': 'l', 'v': value};
Map<String, Object?> _profile(String id, String name,
        {bool restricted = false}) =>
    {
      'id': id,
      'name': name,
      'isRestricted': restricted,
      'colorIndex': 0,
      'createdAt': 1
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Process relay;
  late Directory folder;

  setUpAll(() async {
    HttpOverrides.global = null;
    folder = await Directory.systemTemp.createTemp('vesper-profile-join-');
    final reservation =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reservation.port;
    await reservation.close();
    // macOS and Linux only ship python3.
    relay = await Process.start(Platform.isWindows ? 'python' : 'python3', [
      'tools/pair_relay/relay.py'
    ], environment: {
      'PAIR_HOST': '127.0.0.1',
      'PAIR_PORT': '$port',
      'PAIR_VAULT_DIR': folder.path,
      'PAIR_PAGE': 'assets/pair/pair.html',
    });
    relay.stdout.drain<void>();
    relay.stderr.drain<void>();
    cloudTransferBase = 'http://127.0.0.1:$port';
    for (var attempt = 0; attempt < 50; attempt++) {
      try {
        final socket = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(milliseconds: 200));
        socket.destroy();
        return;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    fail('The disposable local relay did not start');
  });

  tearDownAll(() async {
    relay.kill();
    await relay.exitCode;
    await folder.delete(recursive: true);
  });

  test(
      'raw device joins encrypted relay without duplicate profiles or lost viewer data',
      () async {
    final remote = _Device({
      'nox_viewer_profiles': _json([
        _profile('main', 'Main'),
        _profile('remote', 'Éléonore', restricted: true)
      ]),
      'nox_parental_pin': _json({'hash': 'server-fixture'}),
      'nox_favorites__vp_remote': _list(['p::server']),
      'file:recently_played_vp_remote': _json([
        {'id': 'p::server', 'playlistId': 'p'}
      ]),
    });
    final joining = _Device({
      'nox_viewer_profiles': _json([
        _profile('main', 'Main'),
        _profile('local', ' ELEONORE '),
        _profile('duplicate', 'Eleonore')
      ]),
      'nox_parental_pin': _json({'hash': 'local-fixture'}),
      'nox_favorites__vp_local': _list(['p::local']),
      'nox_favorites__vp_duplicate': _list(['p::duplicate']),
      'nox_last_position_p::local__vp_local': {'t': 'i', 'v': 42000},
      'file:recently_played_vp_local': _json([
        {'id': 'p::local', 'playlistId': 'p'}
      ]),
    });
    final secret = newSyncSecret();
    await remote.engine.start(secret);
    await remote.engine.sync();
    final initial = Map<String, Object?>.of(joining.values);
    await joining.engine.start(secret);
    await joining.engine.sync();
    final rows = jsonDecode(
        (joining.values['nox_viewer_profiles'] as Map)['v'] as String) as List;
    expect(rows.map((p) => p['id']), ['main', 'remote', 'duplicate']);
    expect(rows[1]['isRestricted'], isTrue);
    expect(
        joining.values['nox_parental_pin'], _json({'hash': 'server-fixture'}));
    expect(joining.values['nox_favorites__vp_remote'],
        _list(['p::server', 'p::local']));
    expect(
        joining.values['nox_favorites__vp_duplicate'], _list(['p::duplicate']));
    expect(joining.values['nox_last_position_p::local__vp_remote'],
        {'t': 'i', 'v': 42000});
    final history = jsonDecode((joining.values['file:recently_played_vp_remote']
        as Map)['v'] as String) as List;
    expect(history.map((p) => p['id']), ['p::server', 'p::local']);
    expect(initial.containsKey('nox_favorites__vp_local'), isTrue);
    await remote.engine.sync();
    expect(remote.values, joining.values);
    expect((await joining.engine.sync())!.pushed, isFalse);
  });
  test(
      'live join keeps the profile migration held through idle syncs and local edits',
      () async {
    final remote = _Device({
      'nox_viewer_profiles': _json([
        _profile('main', 'Main'),
        _profile('remote', 'Kids', restricted: true)
      ]),
      'nox_favorites__vp_remote': _list(['p::server']),
    });
    final joining = _Device({
      'nox_viewer_profiles': _json([
        _profile('main', 'Main'),
        _profile('local', 'KÍDS'),
        _profile('duplicate', 'Kids')
      ]),
      'nox_favorites__vp_local': _list(['p::local']),
      'file:recently_played_vp_local': _json([
        {'id': 'p::local'}
      ]),
    });
    final original = Map<String, Object?>.of(joining.values);
    final secret = newSyncSecret();
    await remote.engine.start(secret);
    await remote.engine.sync();
    await joining.engine.start(secret);
    bool live(String key) =>
        key.startsWith('nox_favorites') || key.startsWith('file:');
    final first = await joining.engine.sync(applyNow: live);
    expect(first!.pulled, 0);
    expect(first.deferred, greaterThan(0));
    expect(joining.values, original);
    expect(joining.store.state!.deferred.containsKey('nox_viewer_profiles'),
        isTrue);
    await joining.engine.sync(applyNow: live);
    expect(joining.values, original);
    joining.values['nox_favorites__vp_local'] = _list(['p::local', 'p::new']);
    await joining.engine.sync(applyNow: live);
    // The loaded services still use the local profile id until cold start.
    expect(joining.values['nox_favorites__vp_local'],
        _list(['p::local', 'p::new']));
    expect(joining.values.containsKey('nox_favorites__vp_remote'), isFalse);
    await joining.engine.sync();
    final profiles = jsonDecode(
        (joining.values['nox_viewer_profiles'] as Map)['v'] as String) as List;
    expect(profiles.map((p) => p['id']), ['main', 'remote', 'duplicate']);
    expect(profiles[1]['isRestricted'], isTrue);
    expect(joining.values['nox_favorites__vp_remote'],
        _list(['p::server', 'p::local', 'p::new']));
    expect(joining.values.containsKey('nox_favorites__vp_local'), isFalse);
    expect(
        joining.values.containsKey('file:recently_played_vp_local'), isFalse);
    expect(
        joining.values['file:recently_played_vp_remote'],
        _json([
          {'id': 'p::local'}
        ]));
    expect(joining.store.state!.deferred, isEmpty);
    await remote.engine.sync();
    expect(remote.values, joining.values);
  });
}
