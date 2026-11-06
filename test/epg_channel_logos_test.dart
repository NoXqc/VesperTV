import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/epg_channel_info.dart';
import 'package:nox_iptv/services/epg_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playlist_editor_epg.dart';
import 'package:nox_iptv/services/playlist_edits.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Chunks extends http.BaseClient {
  Chunks(this.xml, this.status);
  final String xml;
  final int status;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(xml);
    return http.StreamedResponse(
        Stream.fromIterable([
          for (var i = 0; i < bytes.length; i += 7)
            bytes.sublist(i, i + 7 > bytes.length ? bytes.length : i + 7)
        ]),
        status);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late StorageService storage;
  late EpgService epg;
  final profile = PlaylistProfile(
      id: 'p',
      name: 'Test',
      mode: 'm3u',
      m3uUrl: 'https://playlist.example/list',
      epgUrl: 'https://main.example/epg.xml',
      extraEpgUrls: ['https://custom.example/guide.xml'],
      sortOrder: 0,
      createdAt: DateTime(2026));
  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await EpgDatabase.createSchema(db);
    epg = EpgService(storage, database: EpgDatabase(database: db));
  });
  tearDown(() async {
    epg.dispose();
    await db.close();
    L10n.code = 'en';
  });
  Future<void> feed(String xml, {String? url, int status = 200}) =>
      http.runWithClient(
          () => epg
              .refresh(url ?? profile.epgUrl!, knownChannelIds: {'unrelated'}),
          () => Chunks(xml, status));

  test(
      'stream parser keeps channel icons only, including unfiltered candidates',
      () async {
    await feed(
        '<tv><channel id="Sky.UK"><display-name>Sky &amp; Sport</display-name>'
        '<icon src="javascript:bad"/><icon src="/logos/sky.png?a=1&amp;b=2"/>'
        '<icon src="https://other.example/second.png"/></channel>'
        '<channel id="NoLogo"><display-name>No logo</display-name></channel>'
        '<programme channel="sky.uk" start="20260101000000 +0000" stop="20260101010000 +0000">'
        '<title>Show</title><icon src="https://bad.example/programme.png"/>'
        '<rating><icon src="https://bad.example/rating.png"/></rating></programme></tv>');
    final entries = epg.channelsFromSource(profile.epgUrl!);
    expect(entries, hasLength(2));
    expect(entries.first.id, 'sky.uk');
    expect(entries.first.name, 'Sky & Sport');
    expect(entries.first.logoUrl, 'https://main.example/logos/sky.png?a=1&b=2');
    expect(entries.last.logoUrl, isNull);
    expect(epg.channelCatalog['sky.uk'], 'Sky & Sport');
  });

  test(
      'duplicate IDs remain source-specific; search restricts playlist and source',
      () async {
    await feed(
        '<tv><channel id="same"><display-name>Sky</display-name><icon src="/provider.png"/></channel></tv>');
    await feed(
        '<tv><channel id="same"><display-name>Sky custom</display-name><icon src="/custom.png"/></channel></tv>',
        url: profile.extraEpgUrls.single);
    await feed(
        '<tv><channel id="same"><display-name>Sky unrelated</display-name><icon src="/unrelated.png"/></channel></tv>',
        url: 'https://unrelated.example/epg');
    final all = editorGuideSearch(profile, epg.channelsFromSource, 'sky');
    expect(all, hasLength(2));
    expect(all.map((x) => x['source']), ['0', '1']);
    final custom =
        editorGuideSearch(profile, epg.channelsFromSource, 'sky', source: '1')
            .single;
    expect(custom['l'], 'https://custom.example/custom.png');
    expect(custom['id'], 'same');
    expect(custom['sourceName'], 'Extra guide 1');
    expect(
        editorGuideSearch(profile, epg.channelsFromSource, 'sky', source: '99'),
        isEmpty);
    expect(editorGuideSources(profile).toString(), isNot(contains('https://')));
  });

  test('failed parse retains source branding; successful refresh replaces it',
      () async {
    const first =
        '<tv><channel id="sky"><display-name>Sky</display-name><icon src="/old.png"/></channel></tv>';
    await feed(first);
    await feed('down', status: 500);
    expect(epg.channelsFromSource(profile.epgUrl!).single.logoUrl,
        endsWith('/old.png'));
    await feed(
        '<tv><channel id="new"><display-name>New</display-name></channel></tv>');
    expect(epg.channelsFromSource(profile.epgUrl!).single.id, 'new');
    expect(epg.channelsFromSource(profile.epgUrl!).single.logoUrl, isNull);
    await epg.clearAll();
    expect(epg.channelsFromSource(profile.epgUrl!), isEmpty);
  });

  test('removed configured feeds disappear from the source directory',
      () async {
    await feed(
        '<tv><channel id="sky"><display-name>Sky</display-name><icon src="/logo.png"/></channel></tv>',
        url: profile.extraEpgUrls.single);
    epg.startAutoRefresh(
        1000, () => [(url: profile.epgUrl!, knownChannelIds: <String>{})]);
    await http.runWithClient(
        () => epg.refreshAll(), () => Chunks('<tv></tv>', 200));
    expect(epg.channelsFromSource(profile.extraEpgUrls.single), isEmpty);
  });

  test(
      'unsafe, blank, overlong and credential URLs are rejected without truncation',
      () {
    for (final value in [
      '',
      'javascript:alert(1)',
      'data:image/png;base64,a',
      'file:///tmp/logo',
      'ftp://x/a.png',
      'https://u:p@example.com/a',
      'https://example.com/a b.png',
      "https://example.com/${'x' * 1000}"
    ]) {
      expect(epgLogoUrl(value), isNull,
          reason: value.substring(0, value.length > 80 ? 80 : value.length));
    }
    expect(
        epgLogoUrl('../logo.png',
            sourceUrl: 'https://example.com/dir/guide.xml'),
        'https://example.com/logo.png');
    expect(
        epgLogoUrl('//cdn.example/a.png',
            sourceUrl: 'https://example.com/guide'),
        'https://cdn.example/a.png');
  });

  test(
      'selected URL survives backup/transfer and viewer-scoped edits; reset keeps name and EPG',
      () async {
    final channel = Channel(
        id: 'p::a',
        rawId: 'a',
        playlistId: 'p',
        name: 'Provider',
        group: 'g',
        url: 'https://stream.example/a',
        logoUrl: 'https://logo.example/provider.png',
        epgIdOverride: 'matched');
    final edits = PlaylistEdits(
        names: {'a': 'Renamed'},
        logos: {'a': 'https://logo.example/custom.png'});
    await storage.setPlaylistEditsJson('p', edits.encode());
    final backup = storage.exportForBackup();
    final transfer = storage.exportForTransfer();
    await storage.importForBackup(backup);
    expect(storage.getPlaylistEditsJson('p'), edits.encode());
    await storage.importForTransfer(transfer);
    expect(storage.getPlaylistEditsJson('p'), edits.encode());
    expect(storage.getPlaylistEditsJson('another-playlist'), isNull);
    await storage.setActiveViewerId('other');
    expect(storage.getPlaylistEditsJson('p'), isNull);
    await storage.setActiveViewerId('main');
    final restored = PlaylistEdits.decode(storage.getPlaylistEditsJson('p'));
    restored.apply([channel]);
    expect(channel.logoUrl, 'https://logo.example/custom.png');
    restored.logos.remove('a');
    restored.apply([channel]);
    expect(channel.logoUrl, 'https://logo.example/provider.png');
    expect(channel.name, 'Renamed');
    expect(channel.epgId, 'matched');
    final newChannel = Channel.fromJson(channel.toJson());
    edits.apply([newChannel]);
    expect(newChannel.logoUrl, 'https://logo.example/custom.png');
  });

  test(
      'new editor labels and guide source names are localized in all languages',
      () async {
    for (final code in ['fr', 'es', 'it', 'el', 'de']) {
      await L10n.apply(code);
      for (final entry in editorEpgTexts().entries) {
        expect(entry.value, isNot(entry.key));
      }
      expect(editorGuideSources(profile).first['name'], isNot('Main guide'));
      expect(editorGuideSources(profile).last['name'],
          isNot(contains('{number}')));
    }
  });
}
