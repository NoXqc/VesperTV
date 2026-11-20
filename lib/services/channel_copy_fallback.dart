import '../models/channel.dart';
import '../utils/channel_name_matching.dart';

/// Automatic inline failover for a live channel (`TSN 1 4K` fails ->
/// `TSN 1 FHD` -> `TSN 1 HD`), see `dev-notes/iptv-editor-plan.md`.
/// Candidates come from `PlaylistManager.failoverCandidatesFor` (editor
/// fallbacks, the manual channel link, then quality copies found with
/// [channelCopyKey], the same identity Sports uses).
///
/// The requested channel keeps its id/name/EPG: only the URL is swapped
/// (`channel.copyWith(url: copy.url)`), so the guide, zapping, history and
/// favourites still see the channel the viewer picked.
class ChannelCopyFallback {
  String? _channelId;
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _tried = {};

  /// Failures per stream URL this run of the app: a copy that keeps failing
  /// sinks below its working siblings (reliability counts, not only labels).
  static final Map<String, int> _failures = {};

  /// A failed attempt is forgotten after this, so a later press on the same
  /// channel tries the best copy again.
  static const _window = Duration(minutes: 2);

  static void recordFailure(String url) {
    if (url.isEmpty) return;
    _failures[url] = (_failures[url] ?? 0) + 1;
    if (_failures.length > 500) _failures.remove(_failures.keys.first);
  }

  static int failuresOf(String url) => _failures[url] ?? 0;

  // A quality word on its own (letters, digits, _ and + glue words
  // together, as the old upper-case/split/set version read them). One scan,
  // nothing allocated per word: the editor ranks every channel of a
  // playlist when it opens (~110 ms per 47k names before, on a PC).
  static final _qualityWord = RegExp(
      r'(?<![\w+])(8K|4K|UHD|FHD|1080P|HD|720P|SD)(?![\w+])',
      caseSensitive: false);

  /// Higher = better. Unlabelled sits between SD and HD: most providers'
  /// plain name is their HD feed.
  static int qualityRank(String name) {
    var rank = -1;
    for (final m in _qualityWord.allMatches(name)) {
      final r = switch (m[1]!.toUpperCase()) {
        '8K' => 6,
        '4K' || 'UHD' => 5,
        'FHD' || '1080P' => 4,
        'HD' || '720P' => 3,
        _ => 1,
      };
      if (r > rank) rank = r;
      if (rank == 6) break;
    }
    return rank < 0 ? 2 : rank;
  }

  /// Copies of [channel] in [pool], best first, [channel] itself excluded.
  /// [rank] defaults to the name label ([qualityRank]); the editor passes
  /// one that prefers measured quality.
  static List<Channel> copiesOf(Channel channel, Iterable<Channel> pool,
      {int Function(Channel)? rank}) {
    // Displayed names: playlist editor renames group copies too.
    final key = channelCopyKey(channel.name);
    if (key.isEmpty) return const [];
    final score = rank ?? (Channel c) => qualityRank(c.sourceName);
    // Most of a big pool fails the probe word: the player's Sources drawer
    // ran channelCopyKey on every channel of every playlist and took
    // seconds to open on a box (owner, 2026-11-16).
    final probe = channelCopyProbe(key);
    final copies = [
      for (final c in pool)
        if (c.id != channel.id &&
            c.url != channel.url &&
            c.url.isNotEmpty &&
            channelCopyMayMatch(c.name, probe) &&
            channelCopyKey(c.name) == key)
          c
    ];
    int value(Channel c) => score(c) * 10 - failuresOf(c.url).clamp(0, 9);
    copies.sort((a, b) => value(b).compareTo(value(a)));
    return copies;
  }

  /// The next untried candidate after [channel] failed, or null when none
  /// is left (each one is tried once per window: no loops).
  Channel? next(Channel channel, List<Channel> candidates, {DateTime? now}) {
    if (!channel.isLive || channel.transientPlayback) return null;
    final at = now ?? DateTime.now();
    if (_channelId != channel.id || at.difference(_startedAt) > _window) {
      _channelId = channel.id;
      _startedAt = at;
      _tried.clear();
    }
    _tried.add(channel.url);
    recordFailure(channel.url);
    for (final c in candidates) {
      if (_tried.add(c.url)) return c;
    }
    return null;
  }
}
