import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_playback.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';

class _History extends ArchiveService {
  _History() : super(StorageService());
  int removals = 0;
  @override
  Future<void> removeFromHistory(ArchiveSource source, ArchiveMeta meta) async {
    removals++;
  }
}

void main() {
  for (final confirm in [false, true]) {
    testWidgets(
        'history removal ${confirm ? 'confirms' : 'cancels'} before writing',
        (tester) async {
      const source = ArchiveSource(
          manifestUrl: 'https://example.com/manifest.json', name: 'Source');
      const meta =
          ArchiveMeta(id: 'one', type: ArchiveType.movie, name: 'Movie');
      const row = ArchiveRow(
          source: source,
          catalog: ArchiveCatalog(
              type: ArchiveType.movie, id: 'history', name: 'History'),
          items: [meta],
          itemSources: [source]);
      final service = _History();
      final prefs = AppPreferences(StorageService())
        ..layoutMode = 'auto'
        ..palette = AppConstants.cyberpunkPalettes.first;
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<ArchiveService>.value(value: service),
            ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () =>
                              holdArchiveTitle(context, row, source, meta),
                          child: const Text('Hold')))))));
      await tester.tap(find.text('Hold'));
      await tester.pumpAndSettle();
      expect(service.removals, 0);
      expect(find.text('Remove "Movie" from history?'), findsOneWidget);
      await tester.tap(find.text(confirm ? 'Remove from history' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(service.removals, confirm ? 1 : 0);
      expect(find.text('Hold'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
