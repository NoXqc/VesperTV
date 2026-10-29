import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_discovery_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/archive_detail_layout.dart';
import 'package:nox_iptv/widgets/archive_discovery_panel.dart';

class _Discovery extends ArchiveDiscoveryService {
  @override
  Future<ArchiveDiscovery> discover(
          ArchiveMeta meta, String key, String language) async =>
      const ArchiveDiscovery(collectionName: 'The collection', collection: [
        ArchiveMeta(id: 'tt2', type: ArchiveType.movie, name: 'Sequel')
      ], related: [
        ArchiveMeta(id: 'tt3', type: ArchiveType.movie, name: 'Another')
      ], cast: [
        ArchivePerson(id: 1, name: 'An actor', role: 'Lead')
      ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('stored row order is viewer-scoped and filters unknown/duplicate ids',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    expect(ArchiveDetailLayout.load(storage), ArchiveDetailLayout.defaults);
    await storage.setArchiveOptionsJson(
        'detail_rows', jsonEncode(['cast', 'invalid', 'cast']));
    expect(
        ArchiveDetailLayout.load(storage), ['cast', 'collection', 'related']);
    expect(
        storage.exportForTransfer().keys.any((k) => k.contains('detail_rows')),
        true);
    await storage.setActiveViewerId('other');
    expect(ArchiveDetailLayout.load(storage), ArchiveDetailLayout.defaults);
    await storage.setArchiveOptionsJson('detail_rows', '{broken');
    expect(ArchiveDetailLayout.load(storage), ArchiveDetailLayout.defaults);
    await storage.setActiveViewerId('main');
    expect(ArchiveDetailLayout.load(storage).first, 'cast');
  });

  for (final size in [const Size(1280, 720), const Size(390, 760)]) {
    testWidgets('actors can be first and remain reachable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.setTmdbApiKey('fixture-key');
      final hub = ArchiveService(storage);
      final entry = FocusNode();
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: storage),
            ChangeNotifierProvider.value(value: hub)
          ],
          child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ArchiveDiscoveryPanel(
                              source: const ArchiveSource(
                                  manifestUrl: 'https://fixture.test',
                                  name: 'Source'),
                              meta: const ArchiveMeta(
                                  id: 'tt1',
                                  type: ArchiveType.movie,
                                  name: 'Title'),
                              entryNode: entry,
                              onReturn: () {},
                              discovery: _Discovery())))))));
      await tester.pumpAndSettle();
      entry.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('up-cast')));
        await tester.pumpAndSettle();
      }
      final selected = tester
          .widget<IconButton>(find.byKey(const ValueKey('down-cast')))
          .focusNode;
      expect(selected!.hasFocus, true);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(ArchiveDetailLayout.load(storage).first, 'cast');
      expect(entry.hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'discovery-cast');
      final castY = tester.getTopLeft(find.text('Cast and credits')).dy;
      expect(
          castY, lessThan(tester.getTopLeft(find.text('The collection')).dy));
      expect(
          castY, lessThan(tester.getTopLeft(find.text('More like this')).dy));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(entry.hasFocus, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      entry.dispose();
      hub.dispose();
    });
  }
}
