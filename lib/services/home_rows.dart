import 'storage_service.dart';

/// The Home page's rows, in the order a new viewer gets them.
enum HomeRowKind {
  games('games', "Today's games"),
  continueWatching('continue', 'Continue Watching'),
  recentChannels('recent', 'Recent channels'),
  favourites('favourites', 'Favourite channels'),
  newMovies('new_movies', 'New movies'),
  newShows('new_shows', 'New TV shows');

  const HomeRowKind(this.id, this.title);

  /// Stored id (never rename one: saved orders use it).
  final String id;

  /// Untranslated title (`tr()` at the display site).
  final String title;
}

/// Which Home rows the active viewer sees, in their order. Stored per viewer
/// as ids, a hidden row as `-id` (`StorageService.getHomeRows`). A row added
/// in a later version (not in the saved list) is appended, shown.
class HomeRows {
  HomeRows(this.order, this.hidden);

  final List<HomeRowKind> order;
  final Set<HomeRowKind> hidden;

  List<HomeRowKind> get visible => [
        for (final k in order)
          if (!hidden.contains(k)) k
      ];

  static HomeRows parse(List<String>? saved) {
    final byId = {for (final k in HomeRowKind.values) k.id: k};
    final order = <HomeRowKind>[];
    final hidden = <HomeRowKind>{};
    for (final raw in saved ?? const <String>[]) {
      final off = raw.startsWith('-');
      final kind = byId[off ? raw.substring(1) : raw];
      if (kind == null || order.contains(kind)) continue;
      order.add(kind);
      if (off) hidden.add(kind);
    }
    for (final k in HomeRowKind.values) {
      if (!order.contains(k)) order.add(k);
    }
    return HomeRows(order, hidden);
  }

  List<String> get encoded =>
      [for (final k in order) hidden.contains(k) ? '-${k.id}' : k.id];

  static HomeRows load(StorageService storage) => parse(storage.getHomeRows());

  Future<void> save(StorageService storage) => storage.setHomeRows(encoded);

  /// Moves [kind] one place up (-1) or down (+1) among the *visible* rows,
  /// so a hidden row in between doesn't swallow the press.
  void move(HomeRowKind kind, int by) {
    final shown = visible;
    final i = shown.indexOf(kind);
    final j = i + by;
    if (i < 0 || j < 0 || j >= shown.length) return;
    final other = shown[j];
    final a = order.indexOf(kind), b = order.indexOf(other);
    order[a] = other;
    order[b] = kind;
  }

  void setHidden(HomeRowKind kind, bool hide) =>
      hide ? hidden.add(kind) : hidden.remove(kind);
}
