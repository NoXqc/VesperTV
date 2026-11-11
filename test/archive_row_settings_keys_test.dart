import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/archive_row_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Customize Media Hub: Left / Right walk a row's buttons in order (hide,
/// pin, up, down, rename). Flutter's own search jumped between hide and the
/// pen only (owner photo, 2026-11-11).
const _source = ArchiveSource(
  manifestUrl: 'https://example.com/manifest.json',
  name: 'Rows',
  catalogs: [ArchiveCatalog(type: ArchiveType.movie, id: 'a', name: 'A')],
);

class _Rows extends ArchiveService {
  _Rows(super.storage);
  @override
  List<ArchiveSource> get sources => [_source];
  @override
  List<ArchiveRow> rows(ArchiveType type, {bool includeHidden = false}) => [
        for (final id in ['first', 'second'])
          ArchiveRow(
              source: _source,
              catalog: ArchiveCatalog(type: type, id: id, name: 'Row $id'),
              items: const [
                ArchiveMeta(id: 'tt1', type: ArchiveType.movie, name: 'One')
              ]),
      ];
}

String? get _tool => FocusManager.instance.primaryFocus?.context
    ?.findAncestorWidgetOfExactType<IconButton>()
    ?.tooltip;

void main() {
  testWidgets('Left / Right reach pin, up and down', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final service = _Rows(storage);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ArchiveService>.value(value: service),
        Provider<StorageService>.value(value: storage),
      ],
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () =>
                          showArchiveRowSettings(context, ArchiveType.movie),
                      child: const Text('Open'))))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(_tool, 'Hide row');
    for (final want in [
      'Pin row',
      'Move up',
      'Move down',
      'Rename row',
      'Rename row'
    ]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_tool, want);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_tool, 'Move down');
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
