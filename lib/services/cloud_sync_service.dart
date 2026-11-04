import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'cloud_sync.dart';
import 'cloud_transfer.dart' show CloudTransfer;
import 'device_transfer.dart' show TransferException;
import '../utils/constants.dart';
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
    return _engine = SyncEngine(_store!, _StorageSyncData(_storage),
        newestFirst: isHistoryKey,
        keepWhenMissing: (key) => keepHistoryWhenMissing(
            key, {for (final p in _storage.getViewerProfiles()) p.id}));
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
    _lastAttempt = DateTime.now();
    notifyListeners();
    final watch = Stopwatch()..start();
    try {
      // Checked per key when the merge decides, so a sync that started
      // before the services loaded still holds what they now own.
      final result = await engine.sync(
          applyNow: (key) =>
              !_appLoaded ||
              _isFileKey(key) ||
              StorageService.isLiveSyncKey(key));
      _lastError = null;
      _lastSync = DateTime.now();
      if (result == null) return 0;
      debugPrint('Sync: ${result.pulled} in, ${result.deferred} held, '
          '${result.pushed ? 'pushed ${(result.bytes / 1024).round()} KB' : 'nothing pushed'}'
          '${result.busy ? ', busy (retry later)' : ''}, '
          '${watch.elapsedMilliseconds} ms');
      if (_appLoaded && result.applied.isNotEmpty) {
        onApplied?.call(result.applied);
      }
      return result.pulled;
    } on SyncRevoked {
      debugPrint('Sync: code was reset on another device');
      await engine.stop();
      _status = SyncStatus.revoked;
      return 0;
    } on TransferException catch (e) {
      debugPrint('Sync: failed (${e.kind.name}) after '
          '${watch.elapsedMilliseconds} ms');
      _lastError = e;
      return 0;
    } on SyncConflict {
      // Three uploads lost the race in a row: next sync tries again.
      debugPrint('Sync: lost the race 3 times, later');
      return 0;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- lifecycle

  /// How long the splash waits for the sync before the services load.
  static const coldBudget = Duration(seconds: 4);

  /// Sync on its own every this long while the app is open.
  static const _every = Duration(minutes: 5);

  /// Changes noticed by [noteLocalChange] go up at most this often (watch
  /// positions change every few seconds while playing).
  static const _changeEvery = Duration(minutes: 2);

  bool _appLoaded = false;
  DateTime? _lastAttempt;
  Timer? _periodic;
  Timer? _changeTimer;

  /// Called with the keys a live sync wrote, so the app can reload what
  /// holds them (favourites, hidden groups, positions, palette).
  void Function(Set<String> keys)? onApplied;

  /// The sync before the services load (they read storage once): every
  /// key may be written here. Waits at most [coldBudget]; a slower sync
  /// keeps going and holds what the services own from then on.
  Future<void> syncBeforeLoad() async {
    if (_status != SyncStatus.on) return;
    await syncNow().timeout(coldBudget, onTimeout: () => 0);
  }

  /// The services are up: from now on only live-safe keys are written,
  /// and sync runs on a timer, on resume and after changes.
  void startAutomatic() {
    _appLoaded = true;
    _periodic?.cancel();
    _periodic = Timer.periodic(_every, (_) => unawaited(syncNow()));
  }

  /// The app came back to the screen.
  void onResumed() {
    final last = _lastAttempt;
    if (last != null && DateTime.now().difference(last) < _changeEvery) {
      return;
    }
    unawaited(syncNow());
  }

  /// Something the user owns may have changed (favourites, positions…):
  /// syncs within [_changeEvery] if it really differs from the server's.
  void noteLocalChange() {
    if (_status != SyncStatus.on || _changeTimer != null) return;
    final last = _lastAttempt;
    final wait = last == null
        ? const Duration(seconds: 10)
        : _changeEvery - DateTime.now().difference(last);
    _changeTimer =
        Timer(wait.isNegative ? const Duration(seconds: 10) : wait, () async {
      _changeTimer = null;
      final engine = await _ensureEngine();
      if (await engine.hasLocalChanges()) await syncNow();
    });
  }

  @override
  void dispose() {
    _periodic?.cancel();
    _changeTimer?.cancel();
    super.dispose();
  }
}

/// Sync keys for files rather than prefs: `file:<cache name>`. Only the
/// Continue Watching histories (re-read by `PlaybackService.reloadForViewer`).
const _filePrefix = 'file:';

bool _isFileKey(String key) => key.startsWith(_filePrefix);

/// A Continue Watching file missing here is "unknown" (Android emptied the
/// cache folder: sync writes it back) only while its viewer still exists;
/// a deleted profile's file is a real removal, or the profile's history
/// would come back and stay on the server for good.
bool keepHistoryWhenMissing(String key, Set<String> viewerIds) {
  if (!_isFileKey(key)) return false;
  final name = key.substring(_filePrefix.length);
  const viewerPrefix = 'recently_played_vp_';
  return !name.startsWith(viewerPrefix) ||
      viewerIds.contains(name.substring(viewerPrefix.length));
}

/// Newest-first lists: Continue Watching and Media Hub Recently watched.
bool isHistoryKey(String key) =>
    _isFileKey(key) || key.startsWith(AppConstants.keyArchiveHistory);

class _StorageSyncData implements SyncData {
  _StorageSyncData(this.storage);
  final StorageService storage;

  @override
  Future<Map<String, Object?>> exportForSync() async => {
        ...storage.exportForSync(),
        for (final e in (await storage.recentlyPlayedFiles()).entries)
          '$_filePrefix${e.key}': {'t': 's', 'v': e.value},
      };

  @override
  Future<void> applySyncChanges(
      Map<String, Object?> changed, Set<String> removed) async {
    String? file(String key) {
      final name = key.substring(_filePrefix.length);
      return StorageService.isRecentlyPlayedFile(name) ? name : null;
    }

    for (final e in changed.entries) {
      if (!_isFileKey(e.key)) continue;
      final name = file(e.key);
      final v = e.value is Map ? (e.value as Map)['v'] : null;
      if (name != null && v is String) await storage.writeCacheFile(name, v);
    }
    for (final key in removed.where(_isFileKey)) {
      final name = file(key);
      if (name != null) await storage.deleteCacheFile(name);
    }
    await storage.applySyncChanges({
      for (final e in changed.entries)
        if (!_isFileKey(e.key)) e.key: e.value
    }, removed.where((k) => !_isFileKey(k)).toSet());
  }
}
