import 'dart:async';
import 'package:flutter/foundation.dart';
import 'archive_service.dart';

enum ArchiveSourceStatus { loading, ready, empty, failed }

/// A metadata search, never a video connection. Rows retain their identity as
/// providers finish; completed sessions can be reused briefly by their owner.
class ArchiveStreamSession extends ChangeNotifier {
  ArchiveStreamSession({required this.isCurrent});
  final bool Function() isCurrent;
  final Map<String, ArchiveSourceStatus> statuses = {};
  final Map<String, String> names = {};
  final Map<String, List<ArchiveStreamOption>> _results = {};
  final Set<String> _excluded = {};
  String _id(ArchiveStreamOption o) => '${o.source.key}|${o.stream.identity}';
  Completer<void> _done = Completer<void>();
  Future<void> get done => _done.future;
  Future<void> Function(String)? retrySource;
  DateTime? completedAt;
  bool _disposed = false;
  bool get active => !_disposed && isCurrent();
  bool get loading => statuses.values.contains(ArchiveSourceStatus.loading);
  bool get complete => completedAt != null;
  List<ArchiveStreamOption> get options {
    if (!active) return const [];
    final seen = <String>{};
    return [
      for (final key in statuses.keys)
        for (final option in _results[key] ?? const <ArchiveStreamOption>[])
          if (!_excluded.contains(_id(option)) && seen.add(_id(option))) option,
    ];
  }

  void addSource(String key, String name) {
    statuses[key] = ArchiveSourceStatus.loading;
    names[key] = name;
  }

  void exclude(ArchiveStreamOption option) {
    if (!active || !_excluded.add(_id(option))) return;
    final key = option.source.key;
    if ((_results[key] ?? const []).every((o) => _excluded.contains(_id(o)))) {
      statuses[key] = ArchiveSourceStatus.failed;
    }
    notifyListeners();
  }

  void startRetry(String key) {
    if (!active) return;
    completedAt = null;
    if (_done.isCompleted) _done = Completer<void>();
    statuses[key] = ArchiveSourceStatus.loading;
    _results.remove(key);
    _excluded.removeWhere((id) => id.startsWith('$key|'));
    notifyListeners();
  }

  void finish(String key, List<ArchiveStreamOption> result,
      {bool failed = false}) {
    if (!active) {
      if (!_done.isCompleted) _done.complete();
      if (!_disposed) {
        completedAt = DateTime.now();
        for (final key in statuses.keys.toList()) {
          if (statuses[key] == ArchiveSourceStatus.loading) {
            statuses[key] = ArchiveSourceStatus.failed;
          }
        }
        notifyListeners();
      }
      return;
    }
    _results[key] = result;
    statuses[key] = failed
        ? ArchiveSourceStatus.failed
        : result.isEmpty
            ? ArchiveSourceStatus.empty
            : ArchiveSourceStatus.ready;
    if (!loading) {
      completedAt = DateTime.now();
      if (!_done.isCompleted) _done.complete();
    }
    notifyListeners();
  }

  void finishEmpty() {
    completedAt = DateTime.now();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_done.isCompleted) _done.complete();
    super.dispose();
  }
}
