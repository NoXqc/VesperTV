import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/series_details.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/screens/series_detail_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';

import 'wide_guide_back_test.dart' show GuidePlaylist;

void main() {
  for (final size in [const Size(1920, 1080), const Size(400, 850)]) {
    testWidgets('future episode has a tag in series cards at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
              'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
              (_) async => const StandardMessageCodec().encodeMessage([null]));
      SharedPreferences.setMockInitialValues({});
      await L10n.apply('en');
      final storage = StorageService();
      await storage.init();
      final prefs = AppPreferences(storage);
      await prefs.init();
      final playlist = GuidePlaylist(storage);
      final playback = PlaybackService(storage, playlist);
      final episodes = [
        for (var n = 1; n <= 3; n++)
          Channel(
              id: 'xt_ep_$n',
              rawId: 'xt_ep_$n',
              playlistId: 'p',
              name: 'Episode $n',
              group: 'Show',
              url: 'https://example.com/episode/$n')
      ];
      final details = SeriesDetails(episodes: {
        episodes[0].id: const EpisodeDetails(
            season: 1, episodeNumber: 1, airDate: '2099-12-31'),
        episodes[1].id: const EpisodeDetails(
            season: 1, episodeNumber: 2, airDate: '2000-01-01'),
        episodes[2].id: const EpisodeDetails(season: 1, episodeNumber: 3),
      });
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: storage),
            ChangeNotifierProvider.value(value: prefs),
            ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
            ChangeNotifierProvider.value(value: playback),
          ],
          child: MaterialApp(
              home: SeriesDetailScreen(
            series: XtreamSeries(
                seriesId: 1, playlistId: 'p', name: 'Show', categoryId: '1'),
            showFavorite: false,
            loadEpisodes: () async =>
                (episodes: {1: episodes}, plot: null, details: details),
          ))));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      playback.dispose();
      playlist.dispose();
      prefs.dispose();
      await tester.pump();
    });
  }
}
