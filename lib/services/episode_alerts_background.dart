import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import 'archive_service.dart';
import 'episode_alert_lookup.dart';
import 'episode_alerts.dart';
import 'storage_service.dart';

/// Foreground integration only; WorkManager owns the persistent schedule.
class EpisodeAlertsBackground with WidgetsBindingObserver {
  EpisodeAlertsBackground(this.alerts, {this.onOpen});
  final bool Function()? onOpen;
  final EpisodeAlerts alerts;
  static const channel = MethodChannel('vespertv/episode_background');
  bool _disposed = false;
  bool _openingTap = false;

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    WidgetsBinding.instance.addObserver(this);
    alerts.beforeCheck = alerts.refreshFromDisk;
    alerts.canCheck =
        () async => await channel.invokeMethod<bool>('isForeground') ?? false;
    try {
      await channel.invokeMethod<void>('schedule');
      debugPrint(await diagnostics());
    } catch (_) {
      debugPrint('EpisodeAlertsBg: scheduler unavailable');
    }
  }

  static Future<String> diagnostics() async {
    try {
      return await channel.invokeMethod<String>('diagnostics') ??
          'EpisodeAlertsBg: lastRun=never';
    } catch (_) {
      return 'EpisodeAlertsBg: status unavailable';
    }
  }

  Future<bool> get pendingTap async {
    try {
      return await channel.invokeMethod<bool>('hasTap') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openPending() async {
    if (_disposed || _openingTap) return false;
    _openingTap = true;
    try {
      if (!await pendingTap) return false;
      await alerts.refreshFromDisk();
      if (_disposed || onOpen?.call() != true) return false;
      await channel.invokeMethod<void>('clearTap');
      return true;
    } catch (_) {
      return false;
    } finally {
      _openingTap = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed && state == AppLifecycleState.resumed) {
      unawaited(alerts.refreshFromDisk().catchError((Object _) {}));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(openPending().catchError((Object _) => false));
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    alerts.beforeCheck = null;
    alerts.canCheck = null;
  }
}

class EpisodeBackgroundResult {
  const EpisodeBackgroundResult(this.result, {this.shows = 0, this.fresh = 0});
  final String result;
  final int shows;
  final int fresh;
  Map<String, Object> toJson() =>
      {'result': result, 'shows': shows, 'new': fresh};
}

/// No UI, catalog initialization, EPG, playback, SQLite or global viewer switch.
/// The same EpisodeAlerts.checkAll handles baselines and notice deduplication.
class EpisodeBackgroundRunner {
  EpisodeBackgroundRunner({
    required this.storage,
    required this.canRun,
    required this.lookup,
    required this.notify,
    this.persist,
  });

  final StorageService storage;
  final Future<bool> Function() canRun;
  final Future<EpisodeStatus?> Function(StorageService, FollowedShow) lookup;
  final Future<void> Function(EpisodeNotice) notify;
  final Future<void> Function(StorageService, String, String)? persist;

  Future<EpisodeBackgroundResult> run() async {
    if (!await canRun()) {
      return const EpisodeBackgroundResult('skipped(foreground)');
    }
    var total = 0, due = 0, fresh = 0, errors = 0;
    final notified = <(String, int, int)>{};
    for (final viewer in storage.getViewerProfiles()) {
      if (!await canRun()) {
        return EpisodeBackgroundResult('skipped(foreground)',
            shows: total, fresh: fresh);
      }
      final scoped = StorageService();
      await scoped.init(viewerId: viewer.id, migrate: false);
      final alerts = EpisodeAlerts(scoped);
      try {
        total += alerts.shows.length;
        due += alerts.shows
            .where((s) => EpisodeAlerts.isDue(s, DateTime.now()))
            .length;
        alerts.canCheck = canRun;
        if (persist case final save?) {
          alerts.persist = (viewer, data) => save(scoped, viewer, data);
        }
        alerts.lookup = (show) async {
          try {
            final answer =
                await lookup(scoped, show).timeout(const Duration(seconds: 45));
            if (answer == null) errors++;
            return answer;
          } catch (_) {
            errors++;
            return null;
          }
        };
        alerts.systemNotify = (notice) async {
          if (notified.add((notice.showKey, notice.season, notice.episode))) {
            fresh++;
            await notify(notice);
          }
        };
        await alerts.checkAll();
      } catch (_) {
        return EpisodeBackgroundResult(
            await canRun() ? 'error' : 'skipped(foreground)',
            shows: total,
            fresh: fresh);
      } finally {
        alerts.dispose();
      }
    }
    final result = !await canRun()
        ? 'skipped(foreground)'
        : total == 0
            ? 'skipped(no_follows)'
            : due == 0
                ? 'skipped(recent)'
                : errors > 0
                    ? 'error'
                    : 'ok';
    return EpisodeBackgroundResult(result, shows: total, fresh: fresh);
  }
}

/// Invoked directly by EpisodeAlertsWorker, never calls the normal app main().
@pragma('vm:entry-point')
void episodeAlertsBackgroundMain() {
  // Provider errors may contain private URLs; the worker reports only counts
  // and a fixed result code, and does not rotate or append to the UI log file.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    const bridge = EpisodeAlertsBackground.channel;
    final archives = <ArchiveService>[];
    final lookups = <StorageService, EpisodeAlertLookup>{};
    try {
      final storage = StorageService();
      await storage.init(migrate: false);
      await storage.reloadPreferences();
      await L10n.apply(storage.getLanguage());
      final runner = EpisodeBackgroundRunner(
        storage: storage,
        canRun: () async => await bridge.invokeMethod<bool>('canRun') ?? false,
        lookup: (scoped, show) {
          final lookup = lookups.putIfAbsent(scoped, () {
            final archive = ArchiveService(scoped);
            archives.add(archive);
            return EpisodeAlertLookup.background(scoped, archive);
          });
          return lookup.lookup(show);
        },
        notify: EpisodeAlertLookup.notify,
        persist: (scoped, viewer, data) async {
          final saved = await bridge.invokeMethod<bool>('commit', {
            'key': scoped.episodeAlertsKey(viewer),
            'expected': scoped.getEpisodeAlerts(viewerId: viewer),
            'data': data,
            'viewer': viewer,
          });
          if (saved != true) throw StateError('checkpoint invalidated');
          await scoped.reloadPreferences();
        },
      );
      final outcome = await runner.run();
      await bridge.invokeMethod<void>('finish', outcome.toJson());
    } catch (_) {
      // A foreground transition or changed preference invalidates a commit.
      final allowed = await bridge.invokeMethod<bool>('canRun') ?? false;
      await bridge.invokeMethod<void>('finish', {
        'result': allowed ? 'error' : 'skipped(foreground)',
        'shows': 0,
        'new': 0,
      });
    } finally {
      for (final archive in archives) {
        archive.dispose();
      }
    }
  }, (error, stack) {},
      zoneSpecification:
          ZoneSpecification(print: (self, parent, zone, line) {}));
}
