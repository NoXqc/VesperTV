import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/tracker_api.dart';
import 'package:nox_iptv/services/tracker_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'mixed season marks/unmarks every selected episode and leaves others alone',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setResumeFraction('s1e1', 50);
    await storage.setLastPosition('s2e1', 450);
    for (final id in ['s1e1', 's1e2']) {
      await TrackerSync.setLocalWatched(storage, id,
          watched: true, durationSeconds: id == 's1e1' ? 60 : 0);
      expect(storage.isFullyWatched(id), isTrue);
      expect(storage.isResumeFraction(id), isFalse);
    }
    expect(storage.getLastPosition('s1e1'), 60000);
    expect(storage.getLastPosition('s1e2'), 1);
    for (final id in ['s1e1', 's1e2']) {
      await TrackerSync.setLocalWatched(storage, id, watched: false);
      expect(storage.getLastPosition(id), 0);
    }
    expect(storage.getLastPosition('s2e1'), 450);
  });
  for (final kind in TrackerKind.values) {
    test('${kind.name} sends one season batch for mark and unmark', () async {
      final requests = <http.Request>[];
      final api = TrackerApi(client: MockClient((r) async {
        requests.add(r);
        return http.Response('{}', 200);
      }));
      final login = TrackerLogin(kind: kind, accessToken: 'fake');
      for (final watched in [true, false]) {
        await api.setSeasonWatched(
            login, const TrackedItem.movie('tt123', tmdb: '42'), 2, [3, 4, 4],
            watched: watched);
        final body = jsonDecode(requests.last.body);
        expect(body['shows'][0]['seasons'], [
          {
            'number': 2,
            'episodes': [
              {'number': 3},
              {'number': 4}
            ]
          }
        ]);
        expect(requests.last.url.path.endsWith('/remove'), !watched);
      }
      expect(requests, hasLength(2));
    });
  }
}
