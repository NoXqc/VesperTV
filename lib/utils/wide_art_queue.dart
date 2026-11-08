import 'dart:async';

/// Wide (16:9) browse cards need a landscape backdrop, which an IPTV movie
/// only gets from its own info request (get_vod_info: the same one the hero
/// makes on focus, saved for next time). This runs those for the cards on
/// screen, a few at a time and newest first, so a fast scroll past
/// hundreds of posters never fires hundreds of requests: a card asks only
/// after sitting on screen for [dwell], and leaving cancels it if it hasn't
/// started yet.
class WideArtQueue {
  WideArtQueue._();
  static final WideArtQueue instance = WideArtQueue._();

  static const dwell = Duration(milliseconds: 450);
  static const _parallel = 2;

  // Insertion-ordered (a map literal is a LinkedHashMap).
  final _waiting = <String, _Job>{};
  final Map<String, Future<String?>> _running = {};

  /// Ids already asked this session that had no backdrop: never re-asked.
  final Set<String> _none = {};
  int _active = 0;

  /// Null when [id] was asked already and had none.
  Future<String?>? request(String id, Future<String?> Function() load) {
    if (_none.contains(id)) return null;
    final running = _running[id];
    if (running != null) return running;
    final waiting = _waiting.remove(id);
    // Re-added at the end: the most recent card goes first.
    final job = waiting ?? _Job(load);
    _waiting[id] = job;
    _pump();
    return job.done.future;
  }

  /// The card left the screen before its turn.
  void cancel(String id) {
    final job = _waiting.remove(id);
    if (job != null && !job.done.isCompleted) job.done.complete(null);
  }

  void _pump() {
    while (_active < _parallel && _waiting.isNotEmpty) {
      final id = _waiting.keys.last;
      final job = _waiting.remove(id)!;
      _active++;
      final future = () async {
        try {
          return await job.load();
        } catch (_) {
          return null;
        }
      }();
      _running[id] = future;
      unawaited(
        future.then((url) {
          if (url == null || url.isEmpty) _none.add(id);
          if (!job.done.isCompleted) job.done.complete(url);
        }).whenComplete(() {
          _running.remove(id);
          _active--;
          _pump();
        }),
      );
    }
  }
}

class _Job {
  _Job(this.load);
  final Future<String?> Function() load;
  final done = Completer<String?>();
}
