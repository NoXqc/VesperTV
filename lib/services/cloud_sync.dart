import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'cloud_transfer.dart';
import 'device_transfer.dart' show TransferError, TransferException;
import 'phone_pairing_service.dart' show kRelayAppHeaders;
import 'sync_merge.dart';

/// Cloud sync: no account, no login (owner policy). Devices that share a
/// random **sync secret** keep one encrypted snapshot on the relay
/// (`/api/sync/<id>`, tools/pair_relay/relay.py) and merge it with their
/// own data on the device (sync_merge.dart). Design, phases and what
/// syncs: dev-notes/cloud-sync.md.
///
/// - The secret never leaves a linked device except inside a short-lived
///   **link code** upload (the Transfer vault, 10 minutes) or as the
///   **recovery code** the user writes down.
/// - The relay sees an opaque id, a hashed write token, a version number
///   and ciphertext; it deletes a sync 3 months after the last check-in.

/// Bytes of a sync secret: 128 bits, 26 recovery-code characters.
const int kSyncSecretLength = 16;

/// How long a link code stays valid on the vault.
const Duration kSyncLinkLifetime = Duration(minutes: 10);

const int _snapshotSchema = 1;
const Duration _timeout = Duration(seconds: 30);

List<int> newSyncSecret() {
  final rng = Random.secure();
  return List.generate(kSyncSecretLength, (_) => rng.nextInt(256));
}

// ------------------------------------------------------------ recovery code

/// Crockford base32: no I, L, O, U, so the code reads back unambiguously.
const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// The secret as a recovery code: "ABCD-EFGH-…" (26 characters).
String syncRecoveryCode(List<int> secret) {
  var bits = 0, value = 0;
  final out = StringBuffer();
  for (final byte in secret) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_crockford[(value >> bits) & 31]);
    }
    value &= (1 << bits) - 1;
  }
  if (bits > 0) out.write(_crockford[(value << (5 - bits)) & 31]);
  final s = out.toString();
  return [
    for (var i = 0; i < s.length; i += 4) s.substring(i, min(i + 4, s.length))
  ].join('-');
}

/// The secret a typed recovery code stands for, or null. Case, spaces and
/// dashes don't matter; O/I/L read as 0/1/1 like Crockford says.
List<int>? parseSyncRecoveryCode(String code) {
  final clean = code
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1');
  const need = (kSyncSecretLength * 8 + 4) ~/ 5;
  if (clean.length != need) return null;
  var bits = 0, value = 0;
  final out = <int>[];
  for (final ch in clean.split('')) {
    final d = _crockford.indexOf(ch);
    if (d < 0) return null;
    value = (value << 5) | d;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.add((value >> bits) & 255);
    }
    value &= (1 << bits) - 1;
  }
  return out.length == kSyncSecretLength ? out : null;
}

// --------------------------------------------------------------- link code

/// Puts [secret] on the vault under a new 16-digit code for
/// [kSyncLinkLifetime]; another device types the code to join.
/// Throws [TransferException].
Future<CloudTransfer> uploadSyncLink(List<int> secret) =>
    uploadCloudTransfer({'secret': base64Url.encode(secret)}, kSyncLinkLifetime,
        kind: 'sync-link');

/// The secret a link code holds. Throws [TransferException] (`notFound` =
/// wrong or expired code, `invalid` = a Transfer code, not a link code).
Future<List<int>> downloadSyncLink(String code) async {
  final data = await downloadCloudTransfer(code, kind: 'sync-link');
  try {
    final secret = base64Url.decode(data['secret'] as String);
    if (secret.length == kSyncSecretLength) return secret;
  } catch (_) {}
  throw const TransferException(TransferError.invalid);
}

// ------------------------------------------------------------ relay client

/// The server's copy: its version (0 = none yet) and snapshot.
class SyncRemote {
  const SyncRemote(this.version, this.snapshot);
  final int version;

  /// Null when unchanged since the version asked about (304).
  final SyncSnapshot? snapshot;
}

/// Another device uploaded since the version this one merged against.
class SyncConflict implements Exception {
  const SyncConflict(this.current);
  final int current;
}

/// Talks to `/api/sync/<id>` for one secret.
class SyncClient {
  SyncClient(this.keys, {http.Client? client})
      : _http = client ?? http.Client();

  final VaultKeys keys;
  final http.Client _http;

  static Future<SyncClient> forSecret(List<int> secret,
          {http.Client? client}) async =>
      SyncClient(await VaultKeys.fromMaster(secret), client: client);

  Uri get _uri => Uri.parse('$cloudTransferBase/api/sync/${keys.id}');

  /// The server's snapshot; version 0 + empty when there is none (new, or
  /// deleted after 3 months unused). [knownVersion]: answer "unchanged"
  /// (null snapshot) when it still matches.
  Future<SyncRemote> fetch({int? knownVersion}) async {
    final res = await _call(() => _http.get(_uri, headers: {
          ...kRelayAppHeaders,
          if (knownVersion != null && knownVersion > 0)
            'If-None-Match': '"$knownVersion"',
        }));
    if (res.statusCode == 404) return const SyncRemote(0, SyncSnapshot.empty);
    final version = _etag(res);
    if (res.statusCode == 304 && version != null) {
      return SyncRemote(version, null);
    }
    if (res.statusCode != 200 || version == null) {
      throw const TransferException(TransferError.unreachable);
    }
    final blob = res.bodyBytes;
    final keys = this.keys;
    final snapshot = await Isolate.run(() async {
      final clear = await openVaultBlob(keys, blob);
      if (clear == null) return null;
      try {
        final env = jsonDecode(utf8.decode(gzip.decode(clear)));
        if (env is! Map || env['kind'] != 'sync') return null;
        return SyncSnapshot.fromJson(env);
      } catch (_) {
        return null;
      }
    });
    if (snapshot == null) throw const TransferException(TransferError.invalid);
    return SyncRemote(version, snapshot);
  }

  /// Uploads [snapshot] over version [expected]; returns the new version.
  /// Throws [SyncConflict] when another device got there first.
  Future<int> put(SyncSnapshot snapshot, int expected) async {
    final keys = this.keys;
    final json = {
      'kind': 'sync',
      'schema': _snapshotSchema,
      ...snapshot.toJson()
    };
    final blob = await Isolate.run(() async =>
        sealVaultBlob(keys, gzip.encode(utf8.encode(jsonEncode(json)))));
    final res = await _call(() => _http.put(_uri,
        headers: {
          ...kRelayAppHeaders,
          'Content-Type': 'application/octet-stream',
          'X-Vault-Token': keys.token,
          'If-Match': '"$expected"',
        },
        body: blob));
    final version = _etag(res);
    switch (res.statusCode) {
      case 204 when version != null:
        return version;
      case 412:
        throw SyncConflict(version ?? 0);
      case 413:
      case 507:
        throw const TransferException(TransferError.tooBig);
      default:
        throw const TransferException(TransferError.unreachable);
    }
  }

  /// Removes the server's copy (Reset sync code, Stop syncing). Missing
  /// counts as removed.
  Future<void> delete() async {
    final res = await _call(() => _http.delete(_uri,
        headers: {...kRelayAppHeaders, 'X-Vault-Token': keys.token}));
    if (res.statusCode != 204 && res.statusCode != 404) {
      throw const TransferException(TransferError.unreachable);
    }
  }

  void close() => _http.close();

  static int? _etag(http.Response res) {
    final m = RegExp(r'(\d+)').firstMatch(res.headers['etag'] ?? '');
    return m == null ? null : int.parse(m.group(1)!);
  }

  static Future<http.Response> _call(
      Future<http.Response> Function() send) async {
    try {
      final res = await send().timeout(_timeout);
      if (res.statusCode == 429) {
        throw const TransferException(TransferError.unreachable);
      }
      return res;
    } on TransferException {
      rethrow;
    } catch (_) {
      throw const TransferException(TransferError.unreachable);
    }
  }
}

// ------------------------------------------------------------------ engine

/// What a device remembers about its sync (device-only, never synced or
/// transferred): the secret, the server version it last merged, that
/// snapshot (the merge base) and the dates of its unsynced changes.
class SyncState {
  const SyncState({
    required this.secret,
    this.version = 0,
    this.base,
    this.pending = const {},
    this.lastSync,
  });

  final List<int> secret;
  final int version;

  /// Null until the first successful sync (the device is joining).
  final SyncSnapshot? base;
  final Map<String, int> pending;
  final DateTime? lastSync;

  SyncState copyWith({
    int? version,
    SyncSnapshot? base,
    Map<String, int>? pending,
    DateTime? lastSync,
  }) =>
      SyncState(
        secret: secret,
        version: version ?? this.version,
        base: base ?? this.base,
        pending: pending ?? this.pending,
        lastSync: lastSync ?? this.lastSync,
      );

  Map<String, Object?> toJson() => {
        'secret': base64Url.encode(secret),
        'version': version,
        if (base != null) 'base': base!.toJson(),
        'pending': pending,
        if (lastSync != null) 'lastSync': lastSync!.millisecondsSinceEpoch,
      };

  static SyncState? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final secret = base64Url.decode(json['secret'] as String);
      if (secret.length != kSyncSecretLength) return null;
      final pending = json['pending'];
      final last = json['lastSync'];
      return SyncState(
        secret: secret,
        version: json['version'] as int? ?? 0,
        base: json['base'] == null ? null : SyncSnapshot.fromJson(json['base']),
        pending: pending is Map
            ? {
                for (final e in pending.entries)
                  if (e.value is int) '${e.key}': e.value as int
              }
            : const {},
        lastSync:
            last is int ? DateTime.fromMillisecondsSinceEpoch(last) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Where [SyncState] lives. The app's one is a file in the support folder
/// ([FileSyncStore]); the base can be a few hundred KB, too big for prefs.
abstract class SyncStore {
  Future<SyncState?> load();

  /// Null = this device stopped syncing.
  Future<void> save(SyncState? state);
}

class FileSyncStore implements SyncStore {
  FileSyncStore(this.path);
  final String path;

  @override
  Future<SyncState?> load() async {
    try {
      return SyncState.fromJson(jsonDecode(await File(path).readAsString()));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(SyncState? state) async {
    final file = File(path);
    if (state == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await tmp.rename(path);
  }
}

/// The synced data on this device: `StorageService.exportForSync` /
/// `applySyncChanges` in the app, a map in tests.
abstract class SyncData {
  Map<String, Object?> exportForSync();

  /// Writes [changed] values and removes [removed] keys.
  Future<void> applySyncChanges(
      Map<String, Object?> changed, Set<String> removed);
}

/// What one [SyncEngine.sync] did.
class SyncResult {
  const SyncResult({required this.pulled, required this.pushed});

  /// Keys changed on this device by other devices' changes.
  final int pulled;

  /// Whether this device uploaded a new snapshot.
  final bool pushed;
}

/// Runs one sync: date local changes, fetch, merge, apply, upload,
/// retrying after another device's upload (up to 3 times).
class SyncEngine {
  SyncEngine(this.store, this.data, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final SyncStore store;
  final SyncData data;
  final DateTime Function() _now;

  Future<void>? _running;

  /// Starts syncing with a new secret (first device) or a linked/recovered
  /// one (joining device). The next [sync] does the work.
  Future<void> start(List<int> secret) => store.save(SyncState(secret: secret));

  /// Stops syncing on this device (its data stays).
  Future<void> stop() => store.save(null);

  /// Null when this device doesn't sync. Overlapping calls share one run.
  Future<SyncResult?> sync({http.Client? client}) async {
    final running = _running;
    if (running != null) {
      await running;
      return const SyncResult(pulled: 0, pushed: false);
    }
    final done = Completer<void>();
    _running = done.future;
    try {
      return await _sync(client);
    } finally {
      _running = null;
      done.complete();
    }
  }

  Future<SyncResult?> _sync(http.Client? httpClient) async {
    var state = await store.load();
    if (state == null) return null;
    var local = data.exportForSync();
    state = state.copyWith(
        pending: stampLocalChanges(
            state.base, local, state.pending, _now().millisecondsSinceEpoch));
    await store.save(state);

    final client = await SyncClient.forSecret(state.secret, client: httpClient);
    try {
      var pulled = 0;
      for (var attempt = 0;; attempt++) {
        final remote = await client.fetch(
            knownVersion: state!.base == null ? null : state.version);
        // Unchanged on the server: it still holds our base.
        final remoteSnap = remote.snapshot ?? state.base!;
        // The server lost it (3 months unused): start it again from here
        // instead of reading that as "everything was removed".
        final base = remote.version == 0 ? null : state.base;
        final merged = mergeSync(
            base: base,
            local: local,
            remote: remoteSnap,
            pending: state.pending);

        final changed = <String, Object?>{};
        final removed = <String>{};
        for (final key in {...merged.values.keys, ...local.keys}) {
          final v = merged.values[key];
          if (syncValuesEqual(v, local[key])) continue;
          if (v == null) {
            removed.add(key);
          } else {
            changed[key] = v;
          }
        }
        if (changed.isNotEmpty || removed.isNotEmpty) {
          await data.applySyncChanges(changed, removed);
          pulled += changed.length + removed.length;
          local = data.exportForSync();
        }

        var version = remote.version;
        var pushed = false;
        if (remote.version == 0 ||
            !syncValuesEqual(merged.toJson(), remoteSnap.toJson())) {
          try {
            version = await client.put(merged, remote.version);
            pushed = true;
          } on SyncConflict {
            if (attempt >= 2) rethrow;
            continue;
          }
        }
        state = state.copyWith(
            version: version,
            base: merged,
            pending: const {},
            lastSync: _now());
        await store.save(state);
        return SyncResult(pulled: pulled, pushed: pushed);
      }
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
