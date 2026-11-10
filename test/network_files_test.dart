import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/network_files.dart';
import 'package:nox_iptv/services/recording_service.dart';

const _base = 'smb://10.0.0.81/Media/VesperTV';

NetworkFile _file(String name,
        {Map<String, dynamic>? details, int size = 4459821164, int at = 0}) =>
    NetworkFile.fromJson({
      'path': '$_base/$name',
      'name': name,
      'size': size,
      'modified': at,
      if (details != null) 'details': jsonEncode(details),
    })!;

void main() {
  group('NetworkFile', () {
    test('reads the details the saving device wrote', () {
      final f = _file('2026-11-10_72_HOURS_dlho0llvpcll_0.mkv', details: {
        'v': 1,
        'kind': 'download',
        'title': '72 Hours',
        'poster': 'https://img/72.jpg',
        'durationSec': 5400,
      });
      expect(f.title, '72 Hours');
      expect(f.group, '');
      expect(f.poster, 'https://img/72.jpg');
      expect(f.durationSec, 5400);
      expect(f.extension, 'mkv');
      expect(f.savedByVesper, isTrue);
      expect(f.ready, isTrue);
    });

    test('an episode keeps its show', () {
      final f = _file('2026-11-10_Severance_S1_E2_dlabc_1.mkv',
          details: {'title': 'S1 E2 · Half Loop', 'group': 'Severance'});
      expect(f.group, 'Severance');
      expect(f.toChannel().name, 'Severance · S1 E2 · Half Loop');
    });

    test('a VesperTV file without details is still being written', () {
      final f = _file('2026-11-10_72_HOURS_dlho0llvpcll_0.mkv');
      expect(f.savedByVesper, isTrue);
      expect(f.ready, isFalse);
      expect(f.title, '72 HOURS');
      // A recording's name: date, title, the base-36 id.
      expect(
          _file('2026-11-09_Canadiens_vs_Bruins_m8x2k3abcd.ts').ready, isFalse);
    });

    test('a file put there by hand is ready, named from its file name', () {
      final f = _file('The.Batman.2022.2160p.mkv');
      expect(f.savedByVesper, isFalse);
      expect(f.ready, isTrue);
      expect(f.title, 'The Batman 2022 2160p');
      expect(NetworkFile.titleFromName('Home_Video.mp4'), 'Home Video');
    });

    test('bad details are ignored, not fatal', () {
      final f = NetworkFile.fromJson({
        'path': '$_base/x.mkv',
        'name': 'x.mkv',
        'details': '{not json',
      })!;
      expect(f.details, isNull);
      expect(NetworkFile.fromJson({'name': 'x.mkv'}), isNull);
    });

    test('plays as a recording channel with a stable id', () {
      final a = _file('Movie.mkv').toChannel();
      final b = _file('Movie.mkv').toChannel();
      expect(Channel.isRecordingId(a.rawId), isTrue);
      expect(a.id, b.id);
      expect(a.url, '$_base/Movie.mkv');
      expect(_file('Other.mkv').toChannel().id, isNot(a.id));
      expect(NetworkFile.stableHash('abc'), NetworkFile.stableHash('abc'));
    });
  });

  test('details file sits in .vespertv beside the video', () {
    expect(networkDetailsPath('$_base/Movie.mkv'),
        '$_base/.vespertv/Movie.mkv.json');
    expect(networkDetailsPath('$_base/Shows/Ep 1.mkv'),
        '$_base/Shows/.vespertv/Ep 1.mkv.json');
  });

  test('offers ready files that are not this device\'s own or copied', () {
    final mine =
        _file('2026-11-10_Mine_dlaaa_0.mkv', details: {'title': 'Mine'}, at: 3);
    final copied = _file('Copied.mkv', at: 2);
    final writing = _file('2026-11-10_Half_dlbbb_0.mkv', at: 4);
    final older = _file('Older.mkv', at: 1);
    final newer = _file('Newer.mkv', at: 5);
    final shown = networkFilesToShow(
      [mine, copied, writing, older, newer],
      ownPaths: {mine.path},
      copiedFrom: {copied.path},
    );
    expect(shown.map((f) => f.name), ['Newer.mkv', 'Older.mkv']);
  });

  test('a network entry\'s details name the title, show and poster', () {
    final d = RecordingService.detailsOf(RecordingEntry(
      id: 'dl1',
      title: 'S1 E2',
      league: 'Severance',
      gameKey: '',
      leagueId: '',
      gameStart: DateTime(2026, 11, 10),
      startAt: DateTime(2026, 11, 10),
      endAt: DateTime(2026, 11, 24),
      channelId: 'x',
      channelName: '',
      playlistId: '',
      url: 'https://x/1.mkv',
      path: '$_base/2026-11-10_Severance_S1_E2_dl1_0.mkv',
      kind: 'download',
      poster: 'https://img/sev.jpg',
      durationSec: 3000,
    ));
    expect(d['kind'], 'download');
    expect(d['title'], 'S1 E2');
    expect(d['group'], 'Severance');
    expect(d['poster'], 'https://img/sev.jpg');
    expect(d['durationSec'], 3000);
    // What the other device reads back.
    final f = _file('2026-11-10_Severance_S1_E2_dl1_0.mkv', details: d);
    expect(f.title, 'S1 E2');
    expect(f.group, 'Severance');
    expect(f.ready, isTrue);
  });

  test('a copy keeps the file\'s extension', () {
    const item = DownloadItem(
        sourceId: 'net:x',
        title: 'T',
        url: '$_base/My Movie.avi',
        fileExtension: 'avi');
    expect(item.extension, 'avi');
  });

  test('entries remember their details were saved', () {
    final e = RecordingEntry.fromJson({
      'id': 'a',
      'path': '$_base/a.mkv',
      'kind': 'download',
      'detailsSaved': true,
    });
    expect(e.detailsSaved, isTrue);
    expect(e.toJson()['detailsSaved'], isTrue);
    expect(
        RecordingEntry.fromJson({'id': 'b'})
            .toJson()
            .containsKey('detailsSaved'),
        isFalse);
  });
}
