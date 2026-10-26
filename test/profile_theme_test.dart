import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/profile_copy.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/tv_theme.dart';

List<ViewerProfile> profiles() => [
      ViewerProfile.main(),
      for (final id in ['alice', 'bob'])
        ViewerProfile(
            id: id,
            name: id,
            colorIndex: 0,
            isRestricted: false,
            createdAt: DateTime(2026))
    ];
String scoped(String id) =>
    '${AppConstants.keyPaletteId}${AppConstants.viewerKeySuffix}$id';
Map<String, Object> seed() => {
      AppConstants.keyViewerProfiles:
          jsonEncode(profiles().map((p) => p.toJson()).toList())
    };

class ThemeStorage extends StorageService {
  @override
  Future<String?> readCacheFile(String name) async => null;
}

class ThemePlayback extends PlaybackService {
  ThemePlayback(this.store, PlaylistManager manager, this.events)
      : super(store, manager);
  final StorageService store;
  final List<String> events;
  @override
  Future<void> stop() async {
    events.add('stop:${store.getActiveViewerId()}');
  }

  @override
  Future<void> reloadForViewer() async {
    events.add('reload:${store.getActiveViewerId()}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'upgrade snapshots shared colour once and never rewrites Main or explicit viewer colours',
      () async {
    SharedPreferences.setMockInitialValues({
      ...seed(),
      AppConstants.keyPaletteId: 'habs',
      scoped('bob'): 'purple_magenta',
      AppConstants.keyActiveViewerId: 'alice'
    });
    final storage = StorageService();
    await storage.init();
    expect(storage.getPaletteId(), 'habs');
    final raw = await SharedPreferences.getInstance();
    expect(raw.getString(AppConstants.keyPaletteId), 'habs');
    expect(raw.getString(scoped('bob')), 'purple_magenta');
    await storage.setPaletteId('neon_green');
    await storage.setActiveViewerId('main');
    await storage.setPaletteId('red_blue');
    final reopened = StorageService();
    await reopened.init();
    await reopened.setActiveViewerId('alice');
    expect(reopened.getPaletteId(), 'neon_green');
    await reopened.setActiveViewerId('bob');
    expect(reopened.getPaletteId(), 'purple_magenta');
  });

  test(
      'each profile defaults independently and persists its own selection across restart',
      () async {
    SharedPreferences.setMockInitialValues(seed());
    final storage = StorageService();
    await storage.init();
    await storage.setPaletteId('habs');
    await storage.setActiveViewerId('alice');
    expect(storage.getPaletteId(), 'minimal');
    await storage.setPaletteId('red_blue');
    await storage.setActiveViewerId('bob');
    expect(storage.getPaletteId(), 'minimal');
    await storage.setPaletteId('neon_green');
    final reopened = StorageService();
    await reopened.init();
    expect(reopened.getPaletteId(), 'neon_green');
    await reopened.setActiveViewerId('main');
    expect(reopened.getPaletteId(), 'habs');
    await reopened.setActiveViewerId('alice');
    expect(reopened.getPaletteId(), 'red_blue');
  });

  test(
      'new profiles after upgrade start with default even after another restart',
      () async {
    SharedPreferences.setMockInitialValues(
        {...seed(), AppConstants.keyPaletteId: 'habs'});
    final storage = ThemeStorage();
    await storage.init();
    final list = profiles()
      ..add(ViewerProfile(
          id: 'new',
          name: 'New',
          colorIndex: 0,
          isRestricted: false,
          createdAt: DateTime(2026)));
    await storage.copyMainToViewer('new', ProfileCopy.values.toSet(),
        restricted: false);
    await storage.setViewerProfiles(list);
    final reopened = StorageService();
    await reopened.init();
    await reopened.setActiveViewerId('new');
    expect(reopened.getPaletteId(), 'minimal');
    await reopened.setActiveViewerId('alice');
    expect(reopened.getPaletteId(), 'habs');
  });

  for (final backup in [false, true]) {
    test('${backup ? 'backup' : 'transfer'} retains independent themes',
        () async {
      SharedPreferences.setMockInitialValues(seed());
      final storage = StorageService();
      await storage.init();
      await storage.setPaletteId('habs');
      await storage.setActiveViewerId('alice');
      await storage.setPaletteId('red_blue');
      final payload =
          backup ? storage.exportForBackup() : storage.exportForTransfer();
      SharedPreferences.setMockInitialValues({});
      final dest = StorageService();
      await dest.init();
      if (backup) {
        await dest.importForBackup(payload);
      } else {
        await dest.importForTransfer(payload);
      }
      final reopened = StorageService();
      await reopened.init();
      await reopened.setActiveViewerId('main');
      expect(reopened.getPaletteId(), 'habs');
      await reopened.setActiveViewerId('alice');
      expect(reopened.getPaletteId(), 'red_blue');
    });
  }

  test('legacy backup migrates shared theme on next startup', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final legacy = {
      for (final entry
          in {...seed(), AppConstants.keyPaletteId: 'habs'}.entries)
        entry.key: {'t': 's', 'v': entry.value}
    };
    await storage.importForBackup(legacy);
    final reopened = StorageService();
    await reopened.init();
    await reopened.setActiveViewerId('alice');
    expect(reopened.getPaletteId(), 'habs');
  });

  test('deleting a viewer removes only their palette', () async {
    SharedPreferences.setMockInitialValues({
      ...seed(),
      AppConstants.keyPaletteId: 'habs',
      scoped('alice'): 'red_blue'
    });
    final storage = StorageService();
    await storage.init();
    await storage.deleteViewerData('alice');
    final raw = await SharedPreferences.getInstance();
    expect(raw.getString(scoped('alice')), isNull);
    expect(raw.getString(AppConstants.keyPaletteId), 'habs');
    expect(raw.getString(scoped('bob')), 'habs');
  });

  test('legacy alias and invalid palette fallback apply per viewer', () async {
    SharedPreferences.setMockInitialValues({
      ...seed(),
      AppConstants.keyPaletteId: 'red_blue',
      scoped('alice'): 'green_orange',
      scoped('bob'): 'unknown'
    });
    final storage = StorageService();
    await storage.init();
    await storage.setActiveViewerId('alice');
    final prefs = AppPreferences(storage);
    await prefs.init();
    expect(prefs.palette.id, 'habs');
    await storage.setActiveViewerId('bob');
    prefs.reloadPaletteForViewer();
    expect(prefs.palette.id, 'minimal');
    prefs.dispose();
  });

  testWidgets(
      'switch applies viewer theme immediately without changing device settings',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({
      ...seed(),
      AppConstants.keyRefinedFinish: true,
      AppConstants.keyPaletteId: 'habs',
      scoped('alice'): 'red_blue',
      scoped('bob'): 'purple_magenta'
    });
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    final layout = prefs.layoutMode;
    final compat = prefs.compatVideo;
    final manager = PlaylistManager(storage, CatalogDatabase());
    final events = <String>[];
    final playback = ThemePlayback(storage, manager, events);
    final viewers =
        ViewerProfileService(storage, manager, playback, onViewerChanged: () {
      events.add('theme:${storage.getActiveViewerId()}');
      prefs.reloadPaletteForViewer();
    });
    addTearDown(() {
      viewers.dispose();
      playback.dispose();
      manager.dispose();
      prefs.dispose();
    });
    late BuildContext page;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: prefs,
        child: Consumer<AppPreferences>(
            builder: (_, p, __) => MaterialApp(
                  theme: ThemeData(
                      colorScheme:
                          buildPaletteColorScheme(p.palette, Brightness.dark)),
                  home: Builder(builder: (ctx) {
                    page = ctx;
                    return const Scaffold(body: Text('Profile'));
                  }),
                ))));
    final mainColour = Theme.of(page).colorScheme.primary;
    expect(await viewers.switchTo(page, 'alice'), isTrue);
    await tester.pumpAndSettle();
    expect(prefs.palette.id, 'red_blue');
    expect(prefs.refinedFinish, isFalse);
    expect(Theme.of(page).colorScheme.primary, isNot(mainColour));
    expect(events, ['stop:main', 'reload:alice', 'theme:alice']);
    prefs.setPalette(
        AppConstants.cyberpunkPalettes.firstWhere((p) => p.id == 'neon_green'));
    await tester.pumpAndSettle();
    expect(await viewers.switchTo(page, 'bob'), isTrue);
    await tester.pumpAndSettle();
    expect(prefs.palette.id, 'purple_magenta');
    expect(await viewers.switchTo(page, 'main'), isTrue);
    await tester.pumpAndSettle();
    expect(prefs.palette.id, 'habs');
    expect(prefs.refinedFinish, isTrue);
    expect(Theme.of(page).colorScheme.primary, mainColour);
    expect(await viewers.switchTo(page, 'alice'), isTrue);
    await tester.pumpAndSettle();
    expect(prefs.palette.id, 'neon_green');
    expect(prefs.layoutMode, layout);
    expect(prefs.compatVideo, compat);
    final before = events.length;
    expect(await viewers.switchTo(page, 'missing'), isFalse);
    expect(await viewers.switchTo(page, 'alice'), isTrue);
    expect(events.length, before);
    await tester.pumpWidget(const SizedBox());
  });
}
