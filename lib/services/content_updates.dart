import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import 'catalog_database.dart';
import 'epg_service.dart';
import 'playlist_manager.dart';
import 'storage_service.dart';

/// Settings > Profiles & startup > Startup > Update while VesperTV is
/// closed (Android, opt-in, device-only). An hourly WorkManager job
/// (`ContentUpdateWorker.kt`) refreshes the guide and the playlists due for
/// a full sync while the app isn't on screen, on their usual schedules
/// (Settings > EPG refresh interval, each playlist's Update content every).
///
/// - The app's own engine is still alive (Back > Exit only hides the app):
///   the job asks it to update itself ([attachApp], `runInApp`).
/// - Otherwise a headless engine runs [contentUpdateBackgroundMain]. It
///   stops when the app comes on screen or after [budget], and the app
///   waits for it at launch ([waitForBackgroundRun]).
class ContentUpdates {
  ContentUpdates._();

  static const channel = MethodChannel('vespertv/content_updates');

  /// Android gives a background job 10 minutes; what's left when this runs
  /// out stays due for the next run (the guide first, then each playlist).
  static const budget = Duration(minutes: 8);

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Schedules or cancels the hourly job. Called when the switch changes and
  /// at every launch (an update or a restore may have lost it).
  static Future<void> schedule(StorageService storage) async {
    if (!supported) return;
    try {
      await saveNextDue(storage, force: true);
      await channel
          .invokeMethod<void>('schedule', {'on': storage.getContentUpdates()});
    } catch (e) {
      debugPrint('ContentUpdates: scheduler unavailable: $e');
    }
  }

  /// The job reads this natively and skips the run (no engine started) when
  /// nothing is due yet. [force]: 0, so the next run checks for itself.
  static Future<void> saveNextDue(StorageService storage,
      {bool force = false}) async {
    if (!storage.getContentUpdates()) return;
    await storage.setContentUpdatesNextDue(
        force ? null : ContentDue.next(storage, DateTime.now()));
  }

  /// Send log: whether it's on, when the job last looked, its last runs.
  static Future<String> diagnostics() async {
    try {
      return await channel.invokeMethod<String>('diagnostics') ??
          'ContentUpdateBg: status unavailable';
    } catch (_) {
      return 'ContentUpdateBg: status unavailable';
    }
  }

  /// At launch, before the databases open: a headless run that is still
  /// going stops within a second or two once the app is on screen (the job
  /// checks every second). Waits at most [max]; the two engines share the
  /// databases' native connection, so starting anyway is safe, only busier.
  static Future<void> waitForBackgroundRun(StorageService storage,
      {Duration max = const Duration(seconds: 5)}) async {
    if (!supported) return;
    final watch = Stopwatch()..start();
    var waited = false;
    try {
      while (await channel.invokeMethod<bool>('isRunning') == true) {
        waited = true;
        if (watch.elapsed >= max) {
          debugPrint('ContentUpdates: background run still going after '
              '${max.inSeconds} s, starting anyway');
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } catch (_) {
      return;
    }
    if (!waited) return;
    debugPrint('ContentUpdates: waited ${watch.elapsedMilliseconds} ms for '
        'the background run to stop');
    // It may have saved sync times after this engine read the preferences.
    await storage.reloadPreferences();
  }

  static AppLifecycleListener? _lifecycle;

  /// The app's own engine, once it's ready: the job runs the update here
  /// while the app is hidden instead of starting a second engine. Also
  /// keeps the next-due time current each time the app goes away (it may
  /// have updated by itself, or a schedule may have changed).
  static void attachApp({
    required StorageService storage,
    required Future<bool> Function() refreshGuide,
    required Future<(int, int)> Function() syncPlaylists,
  }) {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'runInApp') throw MissingPluginException();
      final outcome = await ContentUpdateRunner(
        storage: storage,
        refreshGuide: refreshGuide,
        syncPlaylists: syncPlaylists,
      ).run();
      debugPrint('ContentUpdates: in the app ${outcome.describe()}');
      await saveNextDue(storage);
      return outcome.toJson();
    });
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(
        onHide: () => unawaited(saveNextDue(storage).catchError((_) {})));
    unawaited(schedule(storage));
  }
}

/// What's due, from the saved times alone (no catalog loaded): a run with
/// nothing due ends before opening anything.
class ContentDue {
  ContentDue._();

  /// Never done: due now.
  static final _overdue = DateTime.fromMillisecondsSinceEpoch(0);

  /// When the guide is next due; null when no enabled playlist has one.
  static DateTime? guide(StorageService storage) {
    final hasGuide =
        storage.getPlaylists().any((p) => p.enabled && p.guideUrls.isNotEmpty);
    if (!hasGuide) return null;
    final last = storage.getEpgLastUpdated();
    return last == null
        ? _overdue
        : last.add(Duration(minutes: storage.getRefreshInterval()));
  }

  /// Playlist id -> when its full sync is next due. Only enabled Xtream
  /// playlists sync (`PlaylistSession.needsFullSync`).
  static Map<String, DateTime> playlists(StorageService storage) => {
        for (final p in storage.getPlaylists())
          if (p.enabled && p.isXtream)
            p.id: storage.getLastFullSyncAt(p.id)?.add(p.syncInterval) ??
                _overdue,
      };

  static bool guideDue(StorageService storage, DateTime now) =>
      !(guide(storage)?.isAfter(now) ?? true);

  static int playlistsDue(StorageService storage, DateTime now) =>
      playlists(storage).values.where((at) => !at.isAfter(now)).length;

  /// The earliest of them; null when there's nothing to update.
  static DateTime? next(StorageService storage, DateTime now) {
    DateTime? first;
    for (final at in [guide(storage), ...playlists(storage).values]) {
      if (at != null && (first == null || at.isBefore(first))) first = at;
    }
    return first;
  }
}

class ContentUpdateOutcome {
  const ContentUpdateOutcome(this.result,
      {this.guide = 'not_due', this.synced = 0, this.due = 0});

  /// ok, partial, nothing_due, stopped(app_opened|time), error.
  final String result;

  /// updated, failed, stopped, not_due.
  final String guide;
  final int synced;
  final int due;

  Map<String, Object> toJson() =>
      {'result': result, 'guide': guide, 'synced': synced, 'due': due};

  String describe() => 'result=$result guide=$guide playlists=$synced/$due';
}

/// One run: the guide first (the most visible), then each due playlist.
/// Shared by the app's own engine and the headless one.
class ContentUpdateRunner {
  ContentUpdateRunner({
    required this.storage,
    required this.refreshGuide,
    required this.syncPlaylists,
    this.prepare,
    this.stopReason,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final StorageService storage;
  final Future<bool> Function() refreshGuide;
  final Future<(int, int)> Function() syncPlaylists;

  /// Loads what the steps need, only when something is due (headless).
  final Future<void> Function()? prepare;

  /// Why to stop now (the app opened, time's up), or null to go on.
  final String? Function()? stopReason;
  final DateTime Function() now;

  bool get _stopped => stopReason?.call() != null;

  Future<ContentUpdateOutcome> run() async {
    final at = now();
    final guideDue = ContentDue.guideDue(storage, at);
    final playlistsDue = ContentDue.playlistsDue(storage, at);
    if (!guideDue && playlistsDue == 0) {
      return const ContentUpdateOutcome('nothing_due');
    }
    await prepare?.call();
    var guide = guideDue ? 'stopped' : 'not_due';
    if (guideDue && !_stopped) {
      final ok = await refreshGuide();
      guide = ok ? 'updated' : (_stopped ? 'stopped' : 'failed');
    }
    var synced = 0, due = playlistsDue;
    if (playlistsDue > 0 && !_stopped) {
      (synced, due) = await syncPlaylists();
    }
    final reason = stopReason?.call();
    return ContentUpdateOutcome(
      reason != null
          ? 'stopped($reason)'
          : guide == 'failed' || synced < due
              ? 'partial'
              : 'ok',
      guide: guide,
      synced: synced,
      due: due,
    );
  }
}

/// Invoked by ContentUpdateWorker.kt when the app's own engine is gone
/// (never the normal main()): no UI, player or Media Hub, only the
/// preferences, the two databases and the network. See [ContentUpdates].
/// Lives in this file because main.dart imports it: a release build leaves
/// out any library the app doesn't import, and the engine then can't find
/// the entry point.
///
/// The databases are never closed here: sqflite keeps one native
/// connection per file for the whole process, which the app's engine
/// reuses if it starts meanwhile.
@pragma('vm:entry-point')
void contentUpdateBackgroundMain() {
  // Provider errors may contain private URLs: nothing is printed, the job
  // reports only a fixed result and counts.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    const bridge = ContentUpdates.channel;
    final started = DateTime.now();
    // app_opened (the app came on screen: the lease ends natively) or
    // android (the job was stopped). Asked every second, so a step stops
    // within one batch or category.
    String? stoppedBy;
    final watch = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        stoppedBy ??= await bridge.invokeMethod<String>('stopReason');
      } catch (_) {}
    });
    String? stopReason() =>
        stoppedBy ??
        (DateTime.now().difference(started) >= ContentUpdates.budget
            ? 'time'
            : null);
    PlaylistManager? manager;
    EpgService? epg;
    try {
      final storage = StorageService();
      await storage.init(migrate: false);
      await L10n.apply(storage.getLanguage());
      final outcome = await ContentUpdateRunner(
        storage: storage,
        stopReason: stopReason,
        prepare: () async {
          final m = manager = PlaylistManager(storage, CatalogDatabase());
          await m.init();
        },
        refreshGuide: () async {
          final m = manager!;
          final service = epg = EpgService(storage)
            ..catchupDaysProvider = m.catchupDaysByEpgId
            ..beforeRefresh = m.ensureLiveChannelsLoaded
            ..shouldStop = () => stopReason() != null;
          await m.ensureLiveChannelsLoaded();
          return service.refreshOnce(m.epgSources());
        },
        syncPlaylists: () =>
            manager!.runDueCatalogSync(stop: () => stopReason() != null),
      ).run();
      await ContentUpdates.saveNextDue(storage);
      await bridge.invokeMethod<void>('finish', outcome.toJson());
    } catch (e) {
      await bridge.invokeMethod<void>('finish', {
        'result': switch (stopReason()) {
          final String reason => 'stopped($reason)',
          null => 'error(${e.runtimeType})',
        },
      });
    } finally {
      watch.cancel();
      epg?.dispose();
      manager?.dispose();
    }
  }, (error, stack) {},
      zoneSpecification:
          ZoneSpecification(print: (self, parent, zone, line) {}));
}
