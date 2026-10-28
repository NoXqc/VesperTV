import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'programme_reminders_test.dart' show programmeChannel;

class _Playback extends PlaybackService {
  _Playback(super.storage, super.playlistManager);
  final opened = <Channel>[];
  @override
  Future<void> play(Channel channel) async {
    opened.add(channel);
    currentChannel = channel;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PlaylistManager playlists;
  late _Playback playback;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    playlists = PlaylistManager(storage, CatalogDatabase());
    playback = _Playback(storage, playlists);
    playback.currentChannel = programmeChannel;
  });
  tearDown(() => {playback.dispose(), playlists.dispose()});
  test(
      'same-channel handoff stops its provider then reopens through normal recording routing',
      () async {
    await playback.handOverScheduledRecording(programmeChannel, () async {
      expect(playback.currentChannel, isNull);
    }, canResume: () => true);
    expect(playback.opened, [programmeChannel]);
  });
  test('user stop during recorder startup wins over delayed resume', () async {
    final entered = Completer<void>(), ready = Completer<void>();
    final switching =
        playback.handOverScheduledRecording(programmeChannel, () async {
      entered.complete();
      await ready.future;
    }, canResume: () => true);
    await entered.future;
    await playback.stop();
    ready.complete();
    await switching;
    expect(playback.opened, isEmpty);
  });
  test(
      'background or viewer change prevents resume; unrelated channels remain untouched',
      () async {
    await playback.handOverScheduledRecording(programmeChannel, () async {},
        canResume: () => false);
    expect(playback.opened, isEmpty);
    playback.currentChannel = programmeChannel.copyWith(id: 'p::other');
    var waited = false;
    await playback.handOverScheduledRecording(programmeChannel, () async {
      waited = true;
    }, canResume: () => true);
    expect(waited, isFalse);
    expect(playback.currentChannel?.id, 'p::other');
  });
}
