import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:nox_iptv/widgets/data_pool_card.dart';

class FileController extends VideoPlayerHdrController {
  FileController(String file)
      : super.networkUrl(Uri.parse('https://example.com/$file')) {
    value = const VideoPlayerHdrValue(
        duration: Duration(hours: 2),
        isInitialized: true,
        size: Size(1920, 1080));
  }
  @override
  int get textureId => 55;
  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
  @override
  Future<bool> isHdrSupported() async => false;
}

void main() {
  for (final file in ['movie.mp4', 'episode.mkv', 'm3u-movie.ts']) {
    testWidgets('Data pool shows the total playing file size for $file',
        (tester) async {
      final controller = FileController(file);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('vespertv/stats'),
          (_) async => {'fileSizeBytes': 12300000000, 'bytes': 100000});
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: DataPoolCard(controller: controller, showFileSize: true))));
      await tester.pumpAndSettle();
      expect(find.text('File size'), findsOneWidget);
      expect(find.text('12.3 GB'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await controller.dispose();
      messenger.setMockMethodCallHandler(
          const MethodChannel('vespertv/stats'), null);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets(
      'unknown size is unavailable, never downloaded byte count; metadata fallback works',
      (tester) async {
    final controller = FileController('movie.mkv');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('vespertv/stats'),
        (_) async => {'bytes': 9990000000});
    Future<void> pump({int? size, bool show = true}) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: DataPoolCard(
                  controller: controller,
                  showFileSize: show,
                  fileSizeBytes: size))));
      await tester.pumpAndSettle();
    }

    await pump();
    expect(find.text('File size unavailable'), findsOneWidget);
    expect(find.text('10.0 GB'), findsNothing);
    await pump(size: 47000000000);
    expect(find.text('47.0 GB'), findsOneWidget);
    await pump(size: 47000000000, show: false);
    expect(find.text('File size'), findsNothing);
    expect(find.text('47.0 GB'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    messenger.setMockMethodCallHandler(
        const MethodChannel('vespertv/stats'), null);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('changing the controller clears the previous title size',
      (tester) async {
    final first = FileController('first.mkv');
    final second = FileController('second.mkv');
    Map<Object?, Object?> stats = {'fileSizeBytes': 70000000000};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('vespertv/stats'), (_) async => stats);
    Future<void> pump(FileController controller) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: DataPoolCard(controller: controller, showFileSize: true))));
      await tester.pumpAndSettle();
    }

    await pump(first);
    expect(find.text('70.0 GB'), findsOneWidget);
    stats = {};
    await pump(second);
    expect(find.text('70.0 GB'), findsNothing);
    expect(find.text('File size unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await first.dispose();
    await second.dispose();
    messenger.setMockMethodCallHandler(
        const MethodChannel('vespertv/stats'), null);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
