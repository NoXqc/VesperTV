import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/media_file_info.dart';
import 'package:nox_iptv/widgets/media_file_info_overlay.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/youtube_embed.dart';
import 'package:nox_iptv/screens/youtube_player_screen.dart';

void main() {
  const id = 'AbCdEfGhI12';
  test('official embed uses an app origin and only validated video identities',
      () {
    final doc = YouTubeEmbedDocument(id);
    expect(YouTubeEmbedDocument.url.origin, 'https://vespertv.app');
    expect(doc.html, contains('strict-origin-when-cross-origin'));
    expect(doc.html, contains('https://www.youtube.com/iframe_api'));
    expect(doc.html, contains("origin:'https://vespertv.app'"));
    expect(doc.html, contains('player.seekTo'));
    expect(doc.html, isNot(contains('googlevideo')));
    expect(() => YouTubeEmbedDocument("</script>"), throwsArgumentError);
    expect(() => YouTubeEmbedDocument.command('arbitrary JS'),
        throwsArgumentError);
  });

  test('YouTube and direct stream parsing remain distinct and safe', () {
    expect(ArchiveStream.fromJson({'ytId': id})!.ytId, id);
    expect(
        ArchiveStream.fromJson({'url': 'https://www.youtube.com/watch?v=$id'})!
            .ytId,
        id);
    expect(
        ArchiveStream.fromJson({
          'url': 'https://r.example.googlevideo.com/videoplayback?token=test'
        })!
            .ytId,
        isNull);
    expect(ArchiveStream.fromJson({'ytId': 'bad'}), isNull);
    expect(ArchiveStream.fromJson({'infoHash': 'not-a-player'}), isNull);
    expect(
        ArchiveStream.fromJson({'externalUrl': 'https://example.com'}), isNull);
    expect(ArchiveStream.fromJson({'url': 'javascript:bad'}), isNull);
    expect(const ArchiveStream(ytId: 'bad').playbackUri, isNull);
  });

  test('trailer channel is VOD and copies retain transient playback', () {
    final c = Channel.trailer(
        title: 'Trailer', url: 'https://example.com/trailer.mp4');
    expect(Channel.isLiveId(c.rawId), isFalse);
    expect(c.transientPlayback, isTrue);
    expect(
        c.copyWith(url: 'https://example.com/redirect.mp4').transientPlayback,
        isTrue);
    expect(c.toJson().containsKey('transientPlayback'), isFalse);
  });

  testWidgets(
      'remote OK toggles, arrows seek, and Back closes without movie playback',
      (tester) async {
    final scripts = <String>[];
    late void Function(Object?) event;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => YouTubePlayerScreen(
                          videoId: id,
                          title: 'User trailer',
                          mediaFileInfo: const MediaFileInfo(
                              source: 'TB+', sizeBytes: 3200000000),
                          television: true,
                          viewBuilder: (document, controller, onEvent) {
                            controller((script) async {
                              scripts.add(script);
                            });
                            event = onEvent;
                            return const SizedBox.expand();
                          },
                        ))),
                child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pump();
    event({'type': 'ready'});
    await tester.pumpAndSettle();
    for (final key in [
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(find.text('Source: TB+'), findsOneWidget);
    expect(find.text('File size: 3.2 GB'), findsOneWidget);
    expect(
        tester
            .widget<AnimatedOpacity>(find.descendant(
                of: find.byType(MediaFileInfoOverlay),
                matching: find.byType(AnimatedOpacity)))
            .opacity,
        1);
    expect(scripts, [
      'window.vesperToggle();',
      'window.vesperSeek(-10);',
      'window.vesperSeek(10);'
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(YouTubePlayerScreen), findsNothing);
    expect(scripts, contains('window.vesperPause();'));
  });

  for (final code in [101, 150, 153]) {
    testWidgets('embed error $code uses only the documented external fallback',
        (tester) async {
      final opened = <Uri>[];
      late void Function(Object?) event;
      await tester.pumpWidget(MaterialApp(
          home: YouTubePlayerScreen(
        videoId: id,
        title: 'Trailer',
        television: false,
        viewBuilder: (document, controller, onEvent) {
          controller((_) async {});
          event = onEvent;
          return const SizedBox.expand();
        },
        openExternal: (uri) async {
          opened.add(uri);
          return true;
        },
      )));
      event({'type': 'error', 'code': code});
      await tester.pumpAndSettle();
      expect(opened.length, code == 153 ? 0 : 1);
      if (opened.isNotEmpty) expect(opened.single.queryParameters['v'], id);
      expect(find.text('Open in YouTube'), findsOneWidget);
      event({'type': 'error', 'code': code});
      await tester.pumpAndSettle();
      expect(opened.length, code == 153 ? 0 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('phone layout fits and timeout leaves a usable fallback',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: YouTubePlayerScreen(
      videoId: id,
      title: 'Trailer',
      television: false,
      viewBuilder: (document, controller, onEvent) {
        controller((_) async {});
        return const SizedBox.expand();
      },
      openExternal: (_) async => false,
    )));
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.text('Open in YouTube'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
