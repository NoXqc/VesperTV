import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/m3u_group.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/recording_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/tuliprox.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Apple TV (and any device that neither records nor downloads): "Record on
/// the server" was offered but the Recordings page, with its "On the
/// Tuliprox server" list, was hidden. The tabs column now shows Recordings
/// once a playlist's Tuliprox says its DVR is on for this account, and the
/// page lists only the server's part. The suite runs with downloads off
/// (test/flutter_test_config.dart), i.e. as such a device.
const _base = 'https://tv.example.com/admin';

Channel _ch(String id, String url, {String playlist = 'p1'}) => Channel(
    id: '$playlist::$id',
    rawId: id,
    playlistId: playlist,
    name: 'Channel $id',
    group: 'News',
    url: url);

class _Live extends PlaylistManager {
  _Live(StorageService storage) : super(storage, CatalogDatabase());

  final list = [
    for (var i = 1; i <= 3; i++)
      _ch('$i', 'https://plain.example.com/$i.ts', playlist: 'p')
  ];

  @override
  List<Channel> get channels => list;

  @override
  List<M3uGroup> get tvGroups =>
      [M3uGroup(title: 'News', playlistId: 'p', channels: list)];

  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [
        for (final c in list)
          if (groupTitle == null || c.group == groupTitle) c
      ];
}

class _NoGuide extends EpgService {
  _NoGuide(super.storage);

  @override
  List<EpgProgram> getPrograms(String channelId) => [];
}

void main() {
  test('this suite runs as a device without recording or downloads', () {
    expect(RecordingService.supported, isFalse);
    expect(RecordingService.serverRecordingsOnly, isTrue);
  });

  group('Tuliprox.serverDvr', () {
    late Map<String, Object?> caps;
    late List<String> calls;

    setUp(() {
      calls = [];
      caps = {
        'recording': 'private',
        'recording_enabled': true,
        'effective_permissions': ['recording.read', 'recording.create'],
      };
      Tuliprox.instance.serverDvr.value = false;
      Tuliprox.instance.api = TuliproxApi(client: MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.url.path == '/admin/auth/token') {
          return http.Response(jsonEncode({'token': 'player-jwt'}), 200);
        }
        if (req.url.path == '/admin/api/v1/me/capabilities') {
          return http.Response(jsonEncode(caps), 200);
        }
        return http.Response('nope', 404);
      }));
      Tuliprox.instance.login.value = TuliproxLogin(
          base: _base,
          username: 'admin',
          token: 'admin-jwt',
          issuedAt: DateTime.now());
    });

    tearDown(() async {
      await Tuliprox.instance.save(null);
      Tuliprox.instance.serverDvr.value = false;
    });

    test('one channel per playlist, Tuliprox ones only', () {
      final tpx = _ch('949', 'https://tv.example.com/live/u/p/949.ts');
      final list = Tuliprox.instance.onePerPlaylist([
        tpx,
        _ch('950', 'https://tv.example.com/live/u/p/950.ts'),
        _ch('1', 'https://plain.example.com/1.ts', playlist: 'other'),
        _ch('2', 'https://tv.example.com/live/u/p/2.ts', playlist: 'other'),
      ]);
      // "other"'s first channel isn't on the Tuliprox: that playlist is
      // not one (its first channel decides, like the Recordings page).
      expect(list, [tpx]);
    });

    test('on once a server says its DVR lists recordings', () async {
      expect(Tuliprox.instance.serverDvr.value, isFalse);
      await Tuliprox.instance
          .dvrFor(_ch('949', 'https://tv.example.com/live/u/p/949.ts'));
      expect(Tuliprox.instance.serverDvr.value, isTrue);
    });

    test('off while the DVR is switched off on the server', () async {
      caps['recording_enabled'] = false;
      await Tuliprox.instance
          .dvrFor(_ch('949', 'https://tv.example.com/live/u/p/949.ts'));
      expect(Tuliprox.instance.serverDvr.value, isFalse);
    });

    test('asked once a run, before anything played', () async {
      final channels = [_ch('949', 'https://tv.example.com/live/u/p/949.ts')];
      await Tuliprox.instance.checkServerDvrOnce(channels);
      expect(Tuliprox.instance.serverDvr.value, isTrue);
      expect(calls, contains('GET /admin/api/v1/me/capabilities'));
      calls.clear();
      await Tuliprox.instance.checkServerDvrOnce(channels);
      expect(calls, isEmpty);
    });
  });

  group('the TV home', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
              'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
              (_) async => const StandardMessageCodec().encodeMessage([null]));
      Tuliprox.instance.serverDvr.value = false;
    });
    tearDown(() => Tuliprox.instance.serverDvr.value = false);

    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(
          {AppConstants.keyShowClock: false});
      final storage = StorageService();
      await storage.init();
      final prefs = AppPreferences(storage);
      await prefs.init();
      prefs.isTelevision = true;
      prefs.guideViewMode = 'live';
      final playlist = _Live(storage);
      final playback = PlaybackService(storage, playlist);
      final epg = _NoGuide(storage);
      final viewers = ViewerProfileService(storage, playlist, playback);
      await tester.pumpWidget(MultiProvider(providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
        ChangeNotifierProvider.value(value: playback),
        ChangeNotifierProvider<EpgService>.value(value: epg),
        ChangeNotifierProvider.value(value: viewers),
      ], child: const MaterialApp(home: TvHomeScreen())));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 16));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        playback.dispose();
        viewers.dispose();
        playlist.dispose();
        prefs.dispose();
        epg.dispose();
        await tester.pump();
      });
    }

    final row = find.byIcon(Icons.fiber_smart_record_outlined);

    testWidgets(
        'Recordings shows once a server DVR is on and opens the server part',
        (tester) async {
      await pumpHome(tester);
      expect(row, findsNothing);

      Tuliprox.instance.serverDvr.value = true;
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Recordings'), findsWidgets);
      // No Tuliprox playlist here: the server-only words, not the Android
      // ones about games and downloads.
      expect(
          find.text(
              'Nothing on the Tuliprox server yet. Hold OK on a live channel and pick Record on the server.'),
          findsOneWidget);
      expect(find.textContaining('Downloads:'), findsNothing);
      expect(find.text('Downloads'), findsNothing);
    });
  });
}
