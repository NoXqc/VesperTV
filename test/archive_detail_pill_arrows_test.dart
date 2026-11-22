import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_detail_screen.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/detail_header.dart';

/// German Fire TV user (video 2026-11-21): on a TV-sized Media Hub title page
/// the German labels wrap the buttons onto three rows, and Right on Trailer
/// (end of row 1) jumped by screen position to a poster far below instead of
/// going on to the next button.
void main() {
  const source =
      ArchiveSource(manifestUrl: 'https://fixture.test', name: 'AIOStreams');
  const meta = ArchiveMeta(
      id: 'tt1',
      type: ArchiveType.movie,
      name: 'Fixture movie',
      posterUrl: 'https://fixture.test/poster.jpg',
      description: 'A description long enough to take a few lines on the '
          'page, like the real one in the video.');

  tearDown(() => L10n.apply('en'));

  Future<void> pumpPage(WidgetTester tester) async {
    // An Android TV box: 960 x 540 logical.
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await L10n.apply('de');
    final storage = StorageService();
    await storage.init();
    // Started earlier: Resume + Restart, as in the video.
    await storage.setLastPosition(
        ArchiveService.channelId(source, meta.id, episode: false), 600000);
    final hub = ArchiveService(storage);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: hub),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const ArchiveDetailScreen(source: source, preview: meta),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  List<DetailPillButton> pillsOf(WidgetTester tester) => tester
      .widgetList<DetailPillButton>(find.byType(DetailPillButton))
      .toList();

  String? focusedLabel(List<DetailPillButton> pills) {
    final focus = FocusManager.instance.primaryFocus;
    for (final pill in pills) {
      if (pill.focusNode == focus) return pill.label;
    }
    return null;
  }

  testWidgets('Right walks the wrapped buttons in order, never to a poster',
      (tester) async {
    await pumpPage(tester);
    final pills = pillsOf(tester);
    final labels = [for (final p in pills) p.label];
    expect(labels, contains('Merkliste'));
    // The case from the video: the buttons take more than one row.
    final tops = {
      for (final p in pills) tester.getTopLeft(find.byWidget(p)).dy.round()
    };
    expect(tops.length, greaterThan(1));

    pills.first.focusNode.requestFocus();
    await tester.pump();
    final walked = [focusedLabel(pills)];
    for (var i = 1; i < pills.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      walked.add(focusedLabel(pills));
    }
    expect(walked, labels);

    // Right on the last button stays there.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focusedLabel(pills), labels.last);

    // And Left walks back to the first.
    for (var i = 1; i < pills.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
    }
    expect(focusedLabel(pills), labels.first);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Down goes to the button below, Up comes back', (tester) async {
    await pumpPage(tester);
    final pills = pillsOf(tester);
    pills.first.focusNode.requestFocus();
    await tester.pump();
    final firstTop = tester.getTopLeft(find.byWidget(pills.first)).dy.round();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final below = pills
        .firstWhere((p) => p.focusNode == FocusManager.instance.primaryFocus);
    expect(tester.getTopLeft(find.byWidget(below)).dy.round(),
        greaterThan(firstTop));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focusedLabel(pills), pills.first.label);
    await tester.pump(const Duration(seconds: 2));
  });
}
