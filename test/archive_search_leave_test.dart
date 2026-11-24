import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = ArchiveSource(
  manifestUrl: 'https://example.com/manifest.json',
  name: 'Leave search',
  catalogs: [
    ArchiveCatalog(type: ArchiveType.movie, id: 'popular', name: 'Popular')
  ],
);

/// A search without add-ons: only its query.
class _Service extends ArchiveService {
  _Service(super.storage);
  final _queries = <ArchiveType, String>{};
  @override
  List<ArchiveSource> get enabledSources => [_source];
  @override
  List<ArchiveSource> get sources => [_source];
  @override
  Future<void> open() async {}
  @override
  List<ArchiveRow> rows(ArchiveType type, {bool includeHidden = false}) => [
        ArchiveRow(source: _source, catalog: _source.catalogs.first, items: [
          const ArchiveMeta(id: 'm1', type: ArchiveType.movie, name: 'Title 1')
        ])
      ];
  @override
  bool canSearch(ArchiveType type) => true;
  @override
  Future<void> loadMore(ArchiveRow row, {bool notify = true}) async {}
  @override
  bool isFavorite(ArchiveSource source, ArchiveMeta meta) => false;
  @override
  Future<void> search(ArchiveType type, String query) async {
    _queries[type] = query;
    notifyListeners();
  }

  @override
  String? searchQuery(ArchiveType type) => _queries[type];
  @override
  void clearSearch(ArchiveType type) {
    if (_queries.remove(type) == null) return;
    // Like ArchiveService._notify: after the frame when it's mid-frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}

/// Owner, 2026-11-24: a Media Hub search was still there after leaving the
/// Media Hub and coming back. Leaving ends it; a page over it keeps it.
void main() {
  late _Service service;
  final navigator = GlobalKey<NavigatorState>();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    service = _Service(storage);
    final prefs = AppPreferences(storage)
      ..isTelevision = true
      ..layoutMode = 'auto'
      ..palette = AppConstants.cyberpunkPalettes.first;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ArchiveService>.value(value: service),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
        ],
        child: MaterialApp(
            navigatorKey: navigator,
            theme: ThemeData.dark().copyWith(platform: TargetPlatform.android),
            home: const Scaffold(body: Text('TV home')))));
  }

  Future<void> push(WidgetTester tester, Widget page) async {
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  Future<void> pop(WidgetTester tester) async {
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
  }

  testWidgets('leaving the Media Hub ends its search', (tester) async {
    await pump(tester);
    await push(tester, const ArchiveScreen());
    await service.search(ArchiveType.movie, 'alien');
    await service.search(ArchiveType.series, 'office');
    await tester.pumpAndSettle();

    // A page over it (a title, the player) keeps the search.
    await push(tester, const Scaffold(body: Text('Title page')));
    await pop(tester);
    expect(service.searchQuery(ArchiveType.movie), 'alien');

    await pop(tester);
    expect(find.text('TV home'), findsOneWidget);
    expect(service.searchQuery(ArchiveType.movie), isNull);
    expect(service.searchQuery(ArchiveType.series), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('a Media Hub opened over another keeps the first one\'s search',
      (tester) async {
    await pump(tester);
    await push(tester, const ArchiveScreen());
    await service.search(ArchiveType.movie, 'alien');
    await push(tester, const ArchiveScreen());
    await pop(tester);
    expect(service.searchQuery(ArchiveType.movie), 'alien');
    await pop(tester);
    expect(service.searchQuery(ArchiveType.movie), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
