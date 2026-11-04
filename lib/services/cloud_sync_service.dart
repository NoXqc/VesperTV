import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'cloud_sync.dart';
import 'cloud_transfer.dart' show CloudTransfer;
import 'device_transfer.dart' show TransferException;
import 'storage_service.dart';

/// What Settings > Sync shows (dev-notes/cloud-sync.md).
enum SyncStatus {
  /// This device doesn't sync.
  off,

  /// Linked; [CloudSyncService.lastSync] says when it last worked.
  on,

  /// The sync code was reset on another device: link this one again.
  revoked,
}

/// The app's cloud sync: owns the [SyncEngine], keeps its state in the
/// support folder, and is what the Settings > Sync screen calls. Every
/// action throws [TransferException] when the relay can't be reached
/// (same errors and messages as Transfer).
///
/// When to sync (start, resume, after changes, every 5 minutes) and
/// applying other devices' changes to the running app are wired by the
/// app, not the screen.
class CloudSyncService extends ChangeNotifier {
  CloudSyncService(this._storage, {SyncStore? store}) : _store = store;

  final StorageService _storage;
  SyncStore? _store;
  SyncEngine? _engine;

  SyncStatus _status = SyncStatus.off;
  SyncStatus get status => _status;

  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;

  bool _syncing = false;
  bool get syncing => _syncing;

  /// The last sync's error, cleared by the next success.
  TransferException? _lastError;
  TransferException? get lastError => _lastError;

  Future<SyncEngine> _ensureEngine() async {
    final existing = _engine;
    if (existing != null) return existing;
    _store ??= FileSyncStore(
        '${(await getApplicationSupportDirectory()).path}/cloud_sync.json');
    return _engine = SyncEngine(_store!, _StorageSyncData(_storage));
  }

  /// Reads the saved state; call once at startup.
  Future<void> init() async {
    final engine = await _ensureEngine();
    final state = await engine.store.load();
    _status = state == null ? SyncStatus.off : SyncStatus.on;
    _lastSync = state?.lastSync;
    notifyListeners();
  }

  /// First device: a new sync from this device's data.
  Future<void> setUp() async {
    final engine = await _ensureEngine();
    await engine.start(newSyncSecret());
    _status = SyncStatus.on;
    await syncNow();
  }

  /// Joins the sync a 16-digit link code points to (shown on a linked
  /// device). Throws [TransferException] (`notFound` = wrong or expired).
  Future<void> joinWithLinkCode(String code) async {
    final secret = await downloadSyncLink(code);
    await _join(secret);
  }

  /// Joins with a recovery code. False when the code isn't valid (typo);
  /// a valid code whose sync was deleted after 3 months unused starts a
  /// new one from this device.
  Future<bool> joinWithRecoveryCode(String code) async {
    final secret = parseSyncRecoveryCode(code);
    if (secret == null) return false;
    await _join(secret);
    return true;
  }

  Future<void> _join(List<int> secret) async {
    final engine = await _ensureEngine();
    await engine.start(secret);
    _status = SyncStatus.on;
    await syncNow();
  }

  /// A 16-digit code (10 minutes) for linking another device; null when
  /// this device doesn't sync.
  Future<CloudTransfer?> createLinkCode() async {
    final state = await (await _ensureEngine()).store.load();
    if (state == null) return null;
    return uploadSyncLink(state.secret);
  }

  /// The recovery code ("ABCD-EFGH-…"); null when not syncing. The screen
  /// asks for the profile PIN first when one is set.
  Future<String?> recoveryCode() async {
    final state = await (await _ensureEngine()).store.load();
    return state == null ? null : syncRecoveryCode(state.secret);
  }

  /// Reset sync code: a new secret holds the data from now on, the old one
  /// is marked reset so devices still on it stop (they must be linked
  /// again). Returns the new recovery code.
  Future<String> resetCode() async {
    final engine = await _ensureEngine();
    final old = await engine.store.load();
    if (old != null) {
      final client = await SyncClient.forSecret(old.secret);
      try {
        await client.revoke();
      } finally {
        client.close();
      }
    }
    final secret = newSyncSecret();
    await engine.start(secret);
    _status = SyncStatus.on;
    await syncNow();
    return syncRecoveryCode(secret);
  }

  /// Stops syncing on this device; its data stays, the other devices keep
  /// syncing.
  Future<void> stop() async {
    await (await _ensureEngine()).stop();
    _status = SyncStatus.off;
    _lastSync = null;
    _lastError = null;
    notifyListeners();
  }

  /// One sync now. Returns how many settings changed here from other
  /// devices (0 when not syncing or on error; see [lastError]).
  Future<int> syncNow() async {
    if (_status != SyncStatus.on) return 0;
    final engine = await _ensureEngine();
    _syncing = true;
    notifyListeners();
    try {
      final result = await engine.sync();
      _lastError = null;
      _lastSync = DateTime.now();
      return result?.pulled ?? 0;
    } on SyncRevoked {
      await engine.stop();
      _status = SyncStatus.revoked;
      return 0;
    } on TransferException catch (e) {
      _lastError = e;
      return 0;
    } on SyncConflict {
      // Three uploads lost the race in a row: next sync tries again.
      return 0;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}

class _StorageSyncData implements SyncData {
  _StorageSyncData(this.storage);
  final StorageService storage;

  @override
  Map<String, Object?> exportForSync() => storage.exportForSync();

  @override
  Future<void> applySyncChanges(
          Map<String, Object?> changed, Set<String> removed) =>
      storage.applySyncChanges(changed, removed);
}
