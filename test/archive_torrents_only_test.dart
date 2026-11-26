import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_stream_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/archive_stream_picker.dart';

/// Reddit (LOG-MGPDXB): a Torrentio without a debrid service answered 76
/// torrent links and nothing else, and the picker only said "No streams" /
/// "No playable stream for this title." It now says why.
const _torrentio = ArchiveSource(
    manifestUrl: 'https://torrentio.example/manifest.json', name: 'Torrentio');
const _comet = ArchiveSource(
    manifestUrl: 'https://comet.example/manifest.json', name: 'Comet');

const _message =
    "Only torrent links were found, and VesperTV can't play torrents. Turn on "
    "a debrid service (Real-Debrid, TorBox…) in the add-on's settings so it "
    'sends direct links.';

Future<void> _pick(WidgetTester tester, ArchiveStreamSession session) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final hub = ArchiveService(storage);
  addTearDown(hub.dispose);
  await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: hub)
      ],
      child: MaterialApp(
          home: Scaffold(
              body: ArchiveStreamPicker(
                  options: session.options, session: session)))));
  await tester.pumpAndSettle();
}

void main() {
  test('the add-on reply counts the torrent links it left out', () async {
    final api = ArchiveApiService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'streams': [
                {'name': 'Torrentio 4k', 'infoHash': 'aa' * 20, 'fileIdx': 0},
                {'name': 'Torrentio 1080p', 'infoHash': 'bb' * 20},
                {'name': 'Direct', 'url': 'https://media.example/a.mkv'},
                {'name': 'Elsewhere', 'externalUrl': 'https://example.com'},
              ]
            }),
            200)));
    int? skipped;
    final streams = await api.fetchStreams(
        'https://torrentio.example', ArchiveType.movie, 'tt24818230',
        skippedTorrents: (n) => skipped = n);
    expect(streams.map((s) => s.url), ['https://media.example/a.mkv']);
    expect(skipped, 2);
  });

  test('a source with torrents only is marked; a retry clears it', () {
    final session = ArchiveStreamSession(isCurrent: () => true);
    session.addSource(_torrentio.key, _torrentio.name);
    session.addSource(_comet.key, _comet.name);
    session.finish(_torrentio.key, const [], skippedTorrents: 76);
    expect(session.onlyTorrentsFound, isFalse, reason: 'Comet still loading');
    session.finish(_comet.key, const [], failed: true);
    expect(session.torrentsOnly, {_torrentio.key});
    expect(session.onlyTorrentsFound, isTrue);
    session.startRetry(_torrentio.key);
    expect(session.torrentsOnly, isEmpty);
    session.finish(_torrentio.key, const []);
    expect(session.onlyTorrentsFound, isFalse);
    session.dispose();
  });

  testWidgets('the picker says Torrents only and explains debrid',
      (tester) async {
    final session = ArchiveStreamSession(isCurrent: () => true);
    session.addSource(_torrentio.key, _torrentio.name);
    session.addSource(_comet.key, _comet.name);
    session.finish(_torrentio.key, const [], skippedTorrents: 76);
    session.finish(_comet.key, const []);
    await _pick(tester, session);
    expect(find.text('Torrentio · Torrents only'), findsOneWidget);
    expect(find.text('Comet · No streams'), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    expect(find.text('No playable stream for this title.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('a source with nothing at all keeps the usual words',
      (tester) async {
    final session = ArchiveStreamSession(isCurrent: () => true);
    session.addSource(_comet.key, _comet.name);
    session.finish(_comet.key, const []);
    await _pick(tester, session);
    expect(find.text('Comet · No streams'), findsOneWidget);
    expect(find.text('No playable stream for this title.'), findsOneWidget);
    expect(find.text(_message), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
