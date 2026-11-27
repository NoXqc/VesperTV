import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/screens/settings/trackers_screen.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/tracker_api.dart';
import 'package:nox_iptv/services/tracker_sync.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCache extends ArchiveCache {
  @override
  Future<List<ArchiveMeta>> read(String k, ArchiveCatalog c) async => const [];
  @override
  Future<DateTime?> fetchedAt(String k, ArchiveCatalog c) async => null;
  @override
  Future<void> write(String k, ArchiveCatalog c, List<ArchiveMeta> i) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> deleteSource(String k) async {}
}

ViewerProfile _profile(String id, {bool kids = false}) => ViewerProfile(
    id: id,
    name: id,
    colorIndex: 1,
    isRestricted: kids,
    createdAt: DateTime(2026));

TrackerLogin _trakt(String user, String token) =>
    TrackerLogin(kind: TrackerKind.trakt, accessToken: token, userName: user);

/// Trakt answers each account with its own history: ann watched Heat
/// (TMDB 949), bob watched Dune (TMDB 438631).
final _api = TrackerApi(client: MockClient((req) async {
  final where = '${req.url.host}${req.url.path}';
  final token = req.headers['Authorization'];
  Object? body = switch (where) {
    'api.trakt.tv/sync/watched/movies' => [
        {
          'movie': token == 'Bearer TA'
              ? {
                  'title': 'Heat',
                  'ids': {'imdb': 'tt0113277', 'tmdb': 949}
                }
              : {
                  'title': 'Dune',
                  'ids': {'imdb': 'tt1160419', 'tmdb': 438631}
                }
        }
      ],
    'api.trakt.tv/sync/watched/shows' || 'api.trakt.tv/sync/playback' => [],
    _ => null,
  };
  if (body == null) return http.Response('', 404);
  return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
}));

/// Discord, 2026-11-26: "Can Trakt / Simkl be scoped per profile, or is it
/// just one login for all profiles?" Each profile can now have its own
/// account of each kind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const main = AppConstants.mainViewerId;
  late StorageService storage;
  late ArchiveService archive;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: '[]',
    });
    storage = StorageService();
    await storage.init();
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      _profile('guest'),
      _profile('kid', kids: true),
    ]);
    archive = ArchiveService(storage, cache: _MemoryCache(), trackers: _api);
    addTearDown(archive.dispose);
  });

  Future<String?> traktOf(String viewer) async {
    await storage.setActiveViewerId(viewer);
    return archive.trackerSource(TrackerKind.trakt)?.tracker?.userName;
  }

  List<String> accounts() => [
        for (final s in archive.trackerAccounts(TrackerKind.trakt))
          s.tracker!.userName
      ];

  group('accounts', () {
    test('each profile its own Trakt account', () async {
      await archive
          .addTracker(_trakt('ann', 'TA'), profileIds: {main, 'guest'});
      expect(await traktOf(main), 'ann');
      expect(await traktOf('guest'), 'ann');
      expect(await traktOf('kid'), isNull);

      // The guest connects their own: only theirs changes.
      await storage.setActiveViewerId('guest');
      await archive.addTracker(_trakt('bob', 'TB'));
      expect(await traktOf(main), 'ann');
      expect(await traktOf('guest'), 'bob');
      expect(accounts(), ['ann', 'bob']);
      expect([
        for (final s in archive.trackerAccounts(TrackerKind.trakt))
          s.manifestUrl
      ], [
        'trakt://account',
        'trakt://account/bob'
      ]);

      // Plays are reported to the profile in use's account only.
      await storage.setActiveViewerId('guest');
      expect(
          [for (final l in await archive.trackerLogins()) l.userName], ['bob']);
      await storage.setActiveViewerId(main);
      expect(
          [for (final l in await archive.trackerLogins()) l.userName], ['ann']);
    });

    test('the same user signing in again keeps their account and profiles',
        () async {
      await archive
          .addTracker(_trakt('ann', 'TA'), profileIds: {main, 'guest'});
      await storage.setActiveViewerId('guest');
      await archive.addTracker(_trakt('Ann', 'TA2'));
      expect(accounts(), ['Ann'], reason: 'one account, the new sign-in');
      final ann = archive.trackerAccounts(TrackerKind.trakt).single;
      expect(ann.tracker!.accessToken, 'TA2');
      expect(archive.profilesWith(ann), {main, 'guest'});
    });

    test('an account left on no profile is removed', () async {
      await archive.addTracker(_trakt('ann', 'TA'), profileIds: {main});
      await archive.addTracker(_trakt('bob', 'TB'), profileIds: {'guest'});
      // Media Hub sources > bob > Profiles: every regular profile.
      final bob = archive.trackerAccounts(TrackerKind.trakt).last;
      await archive.setSourceProfiles([bob.manifestUrl], {main, 'guest'});
      expect(accounts(), ['bob']);
      expect(await traktOf(main), 'bob');
    });

    test('one profile: a new account replaces the old one, as before',
        () async {
      await storage.setViewerProfiles([ViewerProfile.main()]);
      await storage.setActiveViewerId(main);
      await archive.addTracker(_trakt('ann', 'TA'));
      await archive.addTracker(_trakt('bob', 'TB'));
      expect(accounts(), ['bob']);
      expect(await traktOf(main), 'bob');
      // Simkl is its own account.
      await archive.addTracker(const TrackerLogin(
          kind: TrackerKind.simkl, accessToken: 'SA', userName: 'Bo'));
      expect(await traktOf(main), 'bob');
      expect(archive.trackerSource(TrackerKind.simkl)!.tracker!.userName, 'Bo');
    });
  });

  test("a profile's watched marks come from its own account", () async {
    await archive.addTracker(_trakt('ann', 'TA'), profileIds: {main});
    await archive.addTracker(_trakt('bob', 'TB'), profileIds: {'guest'});
    TrackerSync.instance.attach(archive, api: _api);
    TrackerSync.instance.invalidate();
    final heat = TrackerHistory.keys(tmdb: '949');
    final dune = TrackerHistory.keys(tmdb: '438631');

    await storage.setActiveViewerId(main);
    var h = (await TrackerSync.instance.history())!;
    expect(h.movieWatched(heat), isTrue);
    expect(h.movieWatched(dune), isFalse);

    // Within the 5-minute cache, but another profile: its own history.
    await storage.setActiveViewerId('guest');
    h = (await TrackerSync.instance.history())!;
    expect(h.movieWatched(heat), isFalse);
    expect(h.movieWatched(dune), isTrue);

    await storage.setActiveViewerId('kid');
    expect(await TrackerSync.instance.history(), isNull);
  });

  group('Connect window', () {
    // Discord (cillfog, 2026-11-26): on a phone the code ran down one letter
    // per line past the window.
    final signIn = TrackerApi(client: MockClient((req) async {
      final where = '${req.url.host}${req.url.path}';
      if (where == 'api.trakt.tv/oauth/device/code') {
        return http.Response(
            jsonEncode({
              'device_code': 'dev123456',
              'user_code': 'MF2TEJT7',
              'verification_url': 'https://auth.trakt.tv/activate',
              'expires_in': 600,
              'interval': 5
            }),
            200);
      }
      return http.Response('', 400); // Not approved yet.
    }));

    Future<void> open(WidgetTester tester, Size logical) async {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = logical * 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    TrackerSignInDialog(kind: TrackerKind.trakt, api: signIn),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }

    testWidgets('a phone: the code on one line inside the window',
        (tester) async {
      await open(tester, const Size(411, 891));
      expect(tester.takeException(), isNull);
      final code = find.text('MF2TEJT7');
      expect(code, findsOneWidget);
      final codeBox = tester.getRect(code);
      expect(codeBox.height, lessThan(60), reason: 'one line');
      final window = tester.getRect(find.byType(AlertDialog));
      expect(window.contains(codeBox.topLeft), isTrue);
      expect(window.contains(codeBox.bottomRight), isTrue);
      // Stacked: the steps above the QR code.
      expect(tester.getRect(find.byType(QrImageView)).top,
          greaterThan(codeBox.bottom));
      expect(find.text('Open in browser'), findsOneWidget);

      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(find.text('Copy code'));
      await tester.pump();
      expect(copied, 'MF2TEJT7');
      expect(find.text('Copied'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a TV: the QR code beside the steps, as before',
        (tester) async {
      await open(tester, const Size(1280, 720));
      expect(tester.takeException(), isNull);
      final code = tester.getRect(find.text('MF2TEJT7'));
      final qr = tester.getRect(find.byType(QrImageView));
      expect(qr.right, lessThan(code.left));
      expect(code.height, lessThan(60));
      await close(tester);
    });
  });
}
