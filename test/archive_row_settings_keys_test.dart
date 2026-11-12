import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/archive_row_settings.dart';
import 'package:nox_iptv/widgets/glass_menu.dart';
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
  var order = ['first', 'second', 'third'];
  @override
  Future<void> moveRow(ArchiveType type, String key, int step) async {
    final i = order.indexWhere((id) => key.endsWith(id));
    final j = i + step;
    if (i < 0 || j < 0 || j >= order.length) return;
    order = [...order]
      ..[i] = order[j]
      ..[j] = order[i];
    notifyListeners();
  }

  @override
  List<ArchiveSource> get sources => [_source];
  @override
  List<ArchiveRow> rows(ArchiveType type, {bool includeHidden = false}) => [
        for (final id in order)
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

  testWidgets('a moved row keeps the arrow focused', (tester) async {
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
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    expect(_tool, 'Move down');
    final before = FocusManager.instance.primaryFocus;
    State frame() => tester.state(find.ancestor(
        of: find.byWidgetPredicate((w) =>
            w is IconButton &&
            w.focusNode == FocusManager.instance.primaryFocus),
        matching: find.byType(GlassFocusFrame)));
    final frameBefore = frame();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(service.order.first, 'second');
    expect(_tool, 'Move down');
    final now = FocusManager.instance.primaryFocus!;
    expect(now, same(before));
    final row = now.context!.findAncestorWidgetOfExactType<ListTile>()!;
    expect((row.title as Text).data, 'Row first');
    // The row (and its focus outline's state) moved, not rebuilt unfocused.
    expect(frame(), same(frameBefore));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(service.order, ['second', 'third', 'first']);
    expect(FocusManager.instance.primaryFocus, same(before));
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
