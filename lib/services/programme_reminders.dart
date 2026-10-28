import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import 'storage_service.dart';

String programmeKey(Channel channel, EpgProgram programme) =>
    '${channel.id}|${programme.start.toUtc().millisecondsSinceEpoch}';

class ProgrammeReminder {
  ProgrammeReminder(
      {required this.key,
      required this.title,
      required this.channelName,
      required this.start,
      required this.stop,
      this.earlySent = false,
      this.startSent = false});
  final String key, title, channelName;
  final DateTime start, stop;
  bool earlySent, startSent;
  DateTime get early => start.subtract(const Duration(minutes: 5));
  DateTime get expires => start.add(const Duration(minutes: 2));
  Map<String, Object> toJson() => {
        'key': key,
        'title': title,
        'channel': channelName,
        'start': start.toUtc().toIso8601String(),
        'stop': stop.toUtc().toIso8601String(),
        'early': earlySent,
        'started': startSent
      };
  static ProgrammeReminder? parse(Object? raw) {
    if (raw is! Map ||
        raw['key'] is! String ||
        raw['title'] is! String ||
        raw['channel'] is! String) {
      return null;
    }
    final start = DateTime.tryParse('${raw['start']}');
    final stop = DateTime.tryParse('${raw['stop']}');
    if (start == null || stop == null || !stop.isAfter(start)) return null;
    return ProgrammeReminder(
        key: raw['key'],
        title: raw['title'],
        channelName: raw['channel'],
        start: start.toUtc(),
        stop: stop.toUtc(),
        earlySent: raw['early'] == true,
        startSent: raw['started'] == true);
  }
}

class ProgrammeNotice {
  const ProgrammeNotice(this.reminder, {required this.atStart});
  final ProgrammeReminder reminder;
  final bool atStart;
  bool validAt(DateTime now) => atStart
      ? !now.isBefore(reminder.start) &&
          now.isBefore(reminder.expires) &&
          now.isBefore(reminder.stop)
      : !now.isBefore(reminder.early) &&
          now.isBefore(reminder.start) &&
          now.difference(reminder.early) <= const Duration(minutes: 1);
}

/// Viewer/device-local, foreground reminders. Never tunes a channel or takes focus.
class ProgrammeReminders extends ChangeNotifier {
  ProgrammeReminders(this.storage, {DateTime Function()? now})
      : now = now ?? DateTime.now {
    loadViewer();
  }
  final StorageService storage;
  final DateTime Function() now;
  final Map<String, ProgrammeReminder> _entries = {};
  String? viewerId;
  bool _disposed = false;
  Future<void> _write = Future.value();

  void loadViewer() {
    final id = storage.getActiveViewerId();
    if (viewerId == id) return;
    viewerId = id;
    _entries.clear();
    try {
      final raw =
          jsonDecode(storage.getProgrammeReminders(viewerId: id) ?? '[]');
      if (raw is List) {
        for (final value in raw) {
          final reminder = ProgrammeReminder.parse(value);
          if (reminder != null && reminder.expires.isAfter(now())) {
            _entries[reminder.key] = reminder;
          }
        }
      }
    } catch (_) {/* A stale/corrupt preference must not prevent startup. */}
  }

  bool isSet(Channel channel, EpgProgram programme) {
    loadViewer();
    return _entries.containsKey(programmeKey(channel, programme));
  }

  bool isCurrent(ProgrammeReminder reminder) =>
      identical(_entries[reminder.key], reminder);
  Future<void> _save() {
    final viewer = viewerId!;
    final data = jsonEncode(_entries.values.map((r) => r.toJson()).toList());
    _write = _write
        .catchError((Object _) {})
        .then((_) => storage.setProgrammeReminders(data, viewerId: viewer));
    return _write;
  }

  Future<bool> toggle(Channel channel, EpgProgram programme) async {
    loadViewer();
    final key = programmeKey(channel, programme);
    final old = _entries.remove(key);
    if (old == null) {
      if (!channel.isLive ||
          channel.transientPlayback ||
          !programme.start.isAfter(now()) ||
          !programme.stop.isAfter(programme.start)) {
        throw StateError('Programme is no longer upcoming');
      }
      _entries[key] = ProgrammeReminder(
          key: key,
          title: programme.title,
          channelName: channel.name,
          start: programme.start.toUtc(),
          stop: programme.stop.toUtc(),
          earlySent: !programme.start
              .subtract(const Duration(minutes: 5))
              .isAfter(now()));
    }
    final viewer = viewerId;
    try {
      await _save();
    } catch (_) {
      if (viewerId == viewer) {
        if (old == null) {
          _entries.remove(key);
        } else {
          _entries[key] = old;
        }
      }
      rethrow;
    }
    if (!_disposed && viewerId == viewer) notifyListeners();
    return old == null;
  }

  List<ProgrammeNotice> poll() {
    loadViewer();
    final time = now();
    final notices = <ProgrammeNotice>[];
    var changed = false;
    for (final entry in _entries.values.toList()) {
      if (!time.isBefore(entry.expires) || !time.isBefore(entry.stop)) {
        _entries.remove(entry.key);
        changed = true;
        continue;
      }
      if (!entry.earlySent && !time.isBefore(entry.early)) {
        entry.earlySent = true;
        changed = true;
        final notice = ProgrammeNotice(entry, atStart: false);
        if (notice.validAt(time)) notices.add(notice);
      }
      if (!entry.startSent && !time.isBefore(entry.start)) {
        entry.startSent = true;
        changed = true;
        notices.add(ProgrammeNotice(entry, atStart: true));
      }
    }
    if (changed) {
      unawaited(_save().catchError((Object _) {
        debugPrint('ProgrammeReminders: could not save delivery state');
      }));
    }
    return notices;
  }

  DateTime? get nextDeadline {
    DateTime? next;
    for (final entry in _entries.values) {
      final date = !entry.earlySent
          ? entry.early
          : !entry.startSent
              ? entry.start
              : entry.expires;
      if (next == null || date.isBefore(next)) next = date;
    }
    return next;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
