import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nox_iptv/services/cloud_sync.dart';
import 'package:nox_iptv/services/cloud_transfer.dart';
import 'package:nox_iptv/services/device_transfer.dart';
import 'package:nox_iptv/services/phone_pairing_service.dart'
    show kRelayAppHeaders;

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
  late final engine = SyncEngine(store, this);

  @override
  Map<String, Object?> exportForSync() => Map.of(values);

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

  test('a link code hands over the secret; Transfer can\'t open it', () async {
    if (relay == null) return markTestSkipped('python not found');
    final secret = newSyncSecret();
    final link = await uploadSyncLink(secret);
    expect(await downloadSyncLink(link.code), secret);
    await expectLater(
        downloadCloudTransfer(link.code),
        throwsA(isA<TransferException>()
            .having((e) => e.kind, 'kind', TransferError.invalid)));
  });
}
