import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/subtitle_tracks.dart';
import 'package:nox_iptv/widgets/subtitle_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

class CaptionController extends VideoPlayerHdrController {
  CaptionController(this.id)
      : super.networkUrl(Uri.parse('https://example.com/live'));
  final int id;
  @override
  int get textureId => id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CaptionController controller;

  setUp(() {
    SubtitleTracks.externalFor.value = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('vespertv/subtitles/cues'), (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    controller = CaptionController(1);
  });

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(1920, 1080)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    final playlist = PlaylistManager(storage, CatalogDatabase());
    final playback = PlaybackService(storage, playlist);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
        ],
        child: MaterialApp(
            home: Scaffold(body: SubtitleOverlay(controller: controller)))));
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.dispose();
      playback.dispose();
      playlist.dispose();
      SubtitleTracks.externalFor.value = null;
      await tester.pump();
    });
  }

  Future<void> cue(WidgetTester tester, String text,
      {int player = 1,
      bool cc = true,
      bool reset = false,
      bool enabled = true}) async {
    tester.binding.channelBuffers.push(
        'vespertv/subtitles/cues',
        const StandardMethodCodec().encodeSuccessEnvelope({
          'playerId': player,
          'text': text,
          'cc': cc,
          'reset': reset,
          'enabled': enabled,
          'mime': cc ? 'application/cea-608' : 'text/vtt',
        }),
        (_) {});
    await tester.pump();
    // EventChannel delivery schedules a rebuild after the first frame.
    await tester.pump();
  }

  testWidgets('the Subtitle size choice scales the text', (tester) async {
    await pump(tester);
    await cue(tester, 'Sized caption');
    double size() =>
        tester.widget<Text>(find.text('Sized caption')).style!.fontSize!;
    final normal = size();
    final prefs =
        tester.element(find.byType(SubtitleOverlay)).read<AppPreferences>();
    prefs.setSubtitleScale(1.5);
    await tester.pump();
    expect(size(), closeTo(normal * 1.5, 0.01));
    expect(AppPreferences.subtitleSizeName(1.5), 'Extra large');
    expect(AppPreferences.subtitleSizeName(1.0), 'Normal');
    expect(AppPreferences.subtitleSizeName(0.95), 'Normal');
  });

  testWidgets(
      'CC blank grace prevents flashes and repeated blanks do not extend it',
      (tester) async {
    await pump(tester);
    await cue(tester, 'Readable caption');
    await cue(tester, '');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Readable caption'), findsOneWidget);
    await cue(tester, '');
    await tester.pump(const Duration(milliseconds: 401));
    expect(find.text('Readable caption'), findsNothing);
  });

  testWidgets('next snapshot cancels a pending blank and replaces old rows',
      (tester) async {
    await pump(tester);
    await cue(tester, 'First row\nSecond row');
    await cue(tester, '');
    await tester.pump(const Duration(milliseconds: 100));
    await cue(tester, 'Second row\nThird row');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('First row\nSecond row'), findsNothing);
    expect(find.text('Second row\nThird row'), findsOneWidget);
  });

  testWidgets(
      'Off or track change clears immediately and ignores disabled text',
      (tester) async {
    await pump(tester);
    await cue(tester, 'Old text');
    await cue(tester, '');
    await cue(tester, '', reset: true);
    expect(find.text('Old text'), findsNothing);
    await cue(tester, 'Late text', enabled: false);
    expect(find.text('Late text'), findsNothing);
  });

  testWidgets('ordinary embedded subtitles retain exact empty-cue timing',
      (tester) async {
    await pump(tester);
    await cue(tester, 'Movie caption', cc: false);
    expect(find.text('Movie caption'), findsOneWidget);
    await cue(tester, '', cc: false);
    expect(find.text('Movie caption'), findsNothing);
  });

  testWidgets('other players cannot change or clear this player',
      (tester) async {
    await pump(tester);
    await cue(tester, 'My caption');
    await cue(tester, 'Other player', player: 2);
    await cue(tester, '', player: 2, reset: true);
    expect(find.text('My caption'), findsOneWidget);
    expect(find.text('Other player'), findsNothing);
  });

  testWidgets('downloaded captions bypass CC hold and clear at file timing',
      (tester) async {
    await pump(tester);
    await cue(tester, 'Embedded caption');
    await cue(tester, '');
    controller.value = controller.value.copyWith(
        caption: const Caption(
            number: 1,
            start: Duration.zero,
            end: Duration(seconds: 2),
            text: '<i>File caption</i>'));
    SubtitleTracks.externalFor.value = 1;
    await tester.pump();
    expect(find.text('File caption'), findsOneWidget);
    expect(find.text('Embedded caption'), findsNothing);
    await cue(tester, 'Wrong source');
    controller.value = controller.value.copyWith(caption: Caption.none);
    await tester.pump();
    expect(find.text('File caption'), findsNothing);
    expect(find.text('Wrong source'), findsNothing);
    SubtitleTracks.externalFor.value = null;
    await tester.pump();
    expect(find.text('Embedded caption'), findsNothing);
  });

  testWidgets('changing controller drops held captions and pending timers',
      (tester) async {
    await pump(tester);
    await cue(tester, 'Old channel');
    await cue(tester, '');
    final old = controller;
    controller = CaptionController(2);
    // Keep the provider and overlay element; exercise didUpdateWidget.
    final overlay = tester.element(find.byType(SubtitleOverlay));
    final playback = overlay.read<PlaybackService>();
    final prefs = overlay.read<AppPreferences>();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
        ],
        child: MaterialApp(
            home: Scaffold(body: SubtitleOverlay(controller: controller)))));
    expect(find.text('Old channel'), findsNothing);
    await cue(tester, 'New channel', player: 2);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('New channel'), findsOneWidget);
    await old.dispose();
  });

  for (final size in [
    const Size(1920, 1080),
    const Size(800, 400),
    const Size(400, 800)
  ]) {
    testWidgets('CC uses 90% width and keeps rows readable at $size',
        (tester) async {
      await pump(tester, size: size);
      final long = List.filled(12, 'Caption text').join(' ');
      await cue(tester, long);
      final text = find.text(long);
      final box =
          find.ancestor(of: text, matching: find.byType(Container)).first;
      expect(tester.getSize(box).width, closeTo(size.width * 0.9, 0.1));
      expect(
          tester.widget<Text>(text).style!.fontSize, inInclusiveRange(16, 30));
      expect(tester.takeException(), isNull);
    });
  }

  test('CC row metadata orders a complete snapshot top to bottom', () {
    final event = SubtitleCueEvent.fromMap({
      'playerId': 1,
      'text': 'legacy',
      'cc': true,
      'cues': [
        {'text': 'Bottom', 'line': -1.0, 'lineType': 1},
        {'text': 'Top', 'line': -3.0, 'lineType': 1},
        {'text': 'Middle', 'line': -2.0, 'lineType': 1},
      ]
    });
    expect(event.text, 'Top\nMiddle\nBottom');
  });

  test('legacy and ordinary VOD events preserve their original text', () {
    expect(SubtitleCueEvent.fromMap({'playerId': 1, 'text': 'Legacy'}).text,
        'Legacy');
    expect(
        SubtitleCueEvent.fromMap({
          'playerId': 1,
          'text': 'Timed VOD',
          'cc': false,
          'cues': [
            {'text': 'Do not reorder'}
          ]
        }).text,
        'Timed VOD');
  });
}
