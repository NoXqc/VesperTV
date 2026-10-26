import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/audio_track_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/subtitle_tracks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

Channel episode(String id,
        {String source = 'source', String title = 'Carrie'}) =>
    Channel(
        id: 'archive::arc_ep_${source}_$id',
        rawId: 'arc_ep_${source}_$id',
        playlistId: 'archive',
        name: id,
        group: title,
        url: 'https://example.com/video');
const english = VideoAudioTrack(
    id: 'new-2', label: 'English 5.1', language: 'eng', isSelected: false);
const french = VideoAudioTrack(
    id: 'new-1', label: 'French', language: 'fra', isSelected: true);

class _Controller extends VideoPlayerHdrController {
  _Controller() : super.networkUrl(Uri.parse('https://example.com/video'));
  String? picked;
  @override
  int get textureId => 52;
  @override
  Future<List<VideoAudioTrack>> getAudioTracks() async => [french, english];
  @override
  Future<void> selectAudioTrack(String id) async {
    picked = id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  test('manual audio overrides preference and survives new episode/track IDs',
      () async {
    await storage.setPreferredAudioLanguage('fr');
    await AudioTrackPreferences.remember(storage, episode('tt:1:1'), english);
    final controller = _Controller();
    await AudioTrackPreferences.apply(storage, episode('tt:1:2'), controller,
        isCurrent: () => true);
    expect(controller.picked, english.id);
    expect(AudioTrackPreferences.choice(storage, episode('tt:1:2'))!['lang'],
        'eng');
    expect(
        AudioTrackPreferences.choice(
            storage, episode('tt:1:1', source: 'different'))!['lang'],
        'fr');
    await controller.dispose();
  });

  test('ISO aliases, regions and unknown audio do not pick the wrong language',
      () {
    expect(sameTrackLanguage('en-US', 'eng'), true);
    expect(sameTrackLanguage('fra', 'fr-CA'), true);
    expect(sameTrackLanguage('und', 'und'), false);
    expect(AudioTrackPreferences.match([french, english], {'lang': 'en'}),
        english);
    expect(
        AudioTrackPreferences.match([french, english], {'lang': 'ja'}), null);
    expect(
        AudioTrackPreferences.match([french, english], {'lang': null}), null);
  });

  test(
      'audio/subtitle preferences and manual series choices are profile isolated',
      () async {
    await storage.setPreferredAudioLanguage('en');
    await storage.setPreferredSubtitleLanguage('fr');
    await AudioTrackPreferences.remember(storage, episode('tt:1:1'), french);
    await SubtitleTracks.rememberForSeries(storage, episode('tt:1:1'),
        kind: 'embedded', lang: 'en', label: 'Full');
    await storage.setActiveViewerId('second');
    expect(storage.getPreferredAudioLanguage(), '');
    expect(storage.getPreferredSubtitleLanguage(), 'off');
    expect(AudioTrackPreferences.choice(storage, episode('tt:1:1')), null);
    expect(SubtitleTracks.seriesChoiceFor(storage, episode('tt:1:1'))!['kind'],
        'off');
    await storage.setActiveViewerId('main');
    expect(storage.getPreferredAudioLanguage(), 'en');
    expect(SubtitleTracks.seriesChoiceFor(storage, episode('tt:1:2'))!['lang'],
        'en');
  });

  test('Media Hub Off survives resume and wins over preferred subtitles',
      () async {
    await storage.setPreferredSubtitleLanguage('en');
    await SubtitleTracks.rememberForSeries(storage, episode('tt:1:1'));
    expect(SubtitleTracks.seriesChoiceFor(storage, episode('tt:1:2'))!['kind'],
        'off');
    final calls = <MethodCall>[];
    const bridge = MethodChannel('vespertv/subtitles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      return null;
    });
    final controller = _Controller();
    await SubtitleTracks.applyForSeries(storage, episode('tt:1:1'), controller);
    expect(calls.single.arguments['group'], -1);
    expect(calls.single.arguments['playerId'], 52);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null);
    await controller.dispose();
  });

  test(
      'embedded subtitle selection restores language/label/forced across alias changes',
      () async {
    await SubtitleTracks.rememberForSeries(storage, episode('tt:1:1'),
        kind: 'embedded', lang: 'en', label: 'Full');
    Map? selected;
    const bridge = MethodChannel('vespertv/subtitles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
      if (call.method == 'getTextTracks') {
        return [
          {
            'group': 1,
            'track': 0,
            'language': 'eng',
            'label': 'Forced',
            'forced': true
          },
          {'group': 2, 'track': 0, 'language': 'eng', 'label': 'Full'},
        ];
      }
      selected = call.arguments as Map;
      return null;
    });
    final controller = _Controller();
    await SubtitleTracks.applyForSeries(storage, episode('tt:1:2'), controller);
    expect(selected!['group'], 2);
    selected = null;
    await SubtitleTracks.applyForSeries(storage, episode('tt:1:2'), controller,
        isCurrent: () => false);
    expect(selected, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null);
    await controller.dispose();
  });

  test('movies remember independently; live streams are excluded', () async {
    Channel movie(String id) => Channel(
        id: id,
        rawId: 'arc_vod_$id',
        playlistId: 'archive',
        name: id,
        group: 'Movies',
        url: 'https://example.com/video');
    await SubtitleTracks.rememberForSeries(storage, movie('one'),
        kind: 'embedded', lang: 'fr');
    expect(
        SubtitleTracks.seriesChoiceFor(storage, movie('one'))!['lang'], 'fr');
    expect(
        SubtitleTracks.seriesChoiceFor(storage, movie('two'))!['kind'], 'off');
    final live = Channel(
        id: 'live',
        rawId: 'xt_live_123',
        playlistId: 'p',
        name: 'Live',
        group: 'TV',
        url: 'https://example.com/live');
    expect(SubtitleTracks.seriesKeyOf(live), null);
    final controller = _Controller();
    await storage.setPreferredAudioLanguage('en');
    await AudioTrackPreferences.apply(storage, movie('one'), controller,
        isCurrent: () => false);
    expect(controller.picked, null);
    await controller.dispose();
  });
}
