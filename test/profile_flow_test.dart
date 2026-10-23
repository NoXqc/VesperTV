import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/series_details.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/services/parental_pin.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/screens/settings/profile_editor_screen.dart';
import 'package:nox_iptv/screens/series_detail_screen.dart';
import 'package:nox_iptv/widgets/profile_card.dart';
import 'package:nox_iptv/widgets/detail_header.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';

class Fixture {
  final storage = StorageService();
  late final manager = PlaylistManager(storage, CatalogDatabase());
  late final playback = PlaybackService(storage, manager);
  late final viewers = ViewerProfileService(storage, manager, playback);
  late final prefs = AppPreferences(storage);
  late final pin = ParentalPin(storage);
  Future<void> init() async {
    SharedPreferences.setMockInitialValues({});
    await storage.init();
    await prefs.init();
  }

  Widget wrap(Widget home) => MultiProvider(providers: [
        Provider.value(value: storage),
        Provider.value(value: pin),
        ChangeNotifierProvider.value(value: manager),
        ChangeNotifierProvider.value(value: playback),
        ChangeNotifierProvider.value(value: viewers),
        ChangeNotifierProvider.value(value: prefs)
      ], child: MaterialApp(home: home));
}

Future<void> hold(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pump();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'hold Home card opens edit, name/colour save immediately and Main cannot be deleted',
      (tester) async {
    final f = Fixture();
    await f.init();
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(f.wrap(Builder(
        builder: (ctx) => Scaffold(
            body: ProfileCard(
                profile: f.viewers.active,
                label: 'Main',
                focusNode: node,
                onTap: () {},
                onHold: () => openProfileEditor(ctx, 'main'))))));
    await hold(tester, node);
    expect(find.byType(ProfileDetailScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Household');
    await tester.ensureVisible(find.text('Save name'));
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();
    expect(f.viewers.active.name, 'Household');
    final colours = find.byType(ProfileColourRow);
    final swatch =
        find.descendant(of: colours, matching: find.byType(InkWell)).at(2);
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(f.viewers.active.colorIndex, 2);
    final delete = find.byWidgetPredicate(
        (w) => w is TvMenuTile && w.title == 'Delete profile');
    expect(tester.widget<TvMenuTile>(delete).enabled, false);
    expect(find.text('Main cannot be deleted'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'create returns id, stays on Main and defaults to an empty profile',
      (tester) async {
    final f = Fixture();
    await f.init();
    String? returned;
    await tester.pumpWidget(f.wrap(Builder(
        builder: (ctx) => Scaffold(
            body: TextButton(
                onPressed: () async {
                  returned = await Navigator.push<String>(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const AddProfileScreen()));
                },
                child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump();
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(f.viewers.profiles, hasLength(2));
    expect(returned, f.viewers.profiles.last.id);
    expect(f.viewers.active.id, 'main');
    expect(f.storage.getFavorites(), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('restricted active viewer must pass PIN before editor opens',
      (tester) async {
    final f = Fixture();
    await f.init();
    await f.pin.setPin('1234');
    final kid = ViewerProfile(
        id: 'kid',
        name: 'Kids',
        colorIndex: 0,
        isRestricted: true,
        createdAt: DateTime(2026));
    await f.storage.setViewerProfiles([ViewerProfile.main(), kid]);
    await f.storage.setActiveViewerId('kid');
    // Construct the service only after its initial state is persisted.
    expect(f.viewers.active.isRestricted, true);
    await tester.pumpWidget(f.wrap(Builder(
        builder: (ctx) => Scaffold(
            body: TextButton(
                onPressed: () => openProfileEditor(ctx, 'main'),
                child: const Text('Edit'))))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);
    expect(find.byType(ProfileDetailScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('season chip menu marks only its season then offers unwatched',
      (tester) async {
    final f = Fixture();
    await f.init();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Channel ep(String id) => Channel(
        id: id,
        rawId: 'xt_ep_$id',
        playlistId: 'p',
        name: id,
        group: '',
        url: 'https://example.test');
    final one = ep('one'), two = ep('two'), other = ep('other');
    await tester.pumpWidget(f.wrap(SeriesDetailScreen(
        series: XtreamSeries(
            seriesId: 1, playlistId: 'p', name: 'Show', categoryId: 'c'),
        showFavorite: false,
        loadEpisodes: () async => (
              episodes: {
                1: [one, two],
                2: [other]
              },
              plot: null,
              details: const SeriesDetails()
            ))));
    await tester.pumpAndSettle();
    final chip = find.byWidgetPredicate(
        (w) => w is DetailPillButton && w.label == 'Season 1');
    await tester.ensureVisible(chip);
    await tester.longPress(chip);
    await tester.pumpAndSettle();
    expect(find.text('Mark season watched'), findsOneWidget);
    await tester.tap(find.text('Mark season watched'));
    await tester.pumpAndSettle();
    expect(f.storage.isFullyWatched('one'), true);
    expect(f.storage.isFullyWatched('two'), true);
    expect(f.storage.getLastPosition('other'), 0);
    await tester.longPress(chip);
    await tester.pumpAndSettle();
    expect(find.text('Mark season unwatched'), findsOneWidget);
    await tester.tap(find.text('Mark season unwatched'));
    await tester.pumpAndSettle();
    expect(f.storage.getLastPosition('one'), 0);
    expect(f.storage.getLastPosition('two'), 0);
    await tester.pumpWidget(const SizedBox());
  });
}
