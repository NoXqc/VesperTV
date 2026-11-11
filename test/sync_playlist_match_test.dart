import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/sync_merge.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> tagged(Object value) => {
      't': value is List
          ? 'l'
          : value is int
              ? 'i'
              : 's',
      'v': value
    };
Map<String, Object?> json(Object value) => tagged(jsonEncode(value));
Map<String, Object?> playlist(String id,
        {String user = 'Viewer',
        String server = 'https://example.invalid',
        String? m3u}) =>
    {
      'id': id,
      'name': 'Home',
      'mode': m3u == null ? 'xtream' : 'm3u',
      'xtreamServer': server,
      'xtreamUsername': user,
      'xtreamPassword': 'fixture-only',
      if (m3u != null) 'm3uUrl': m3u,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final remote = {
    AppConstants.keyPlaylists: json([playlist('remote')])
  };

  test('unique server + exact user adopts remote id, leaves inputs untouched',
      () {
    final local = {
      AppConstants.keyPlaylists: json([
        {
          ...playlist('local', server: 'HTTPS://EXAMPLE.INVALID:443/'),
          'name': 'local::label',
          'xtreamPassword': 'local::password'
        },
        playlist('other', user: 'someone-else'),
      ]),
      'nox_favorites': tagged(['local::live_1', 'other::live_1'])
    };
    final before = jsonEncode(local);
    final result = matchSyncPlaylists(local, remote);
    expect((result['nox_favorites'] as Map)['v'],
        ['remote::live_1', 'other::live_1']);
    final rows =
        jsonDecode((result['nox_playlists'] as Map)['v'] as String) as List;
    expect(rows.map((r) => r['id']), ['remote', 'other']);
    expect(rows.first['name'], 'local::label');
    expect(rows.first['xtreamPassword'], 'local::password');
    expect(jsonEncode(local), before);
  });

  test('M3U full URL matches; account, path, query and mode differences do not',
      () {
    const url = 'https://example.invalid/list.m3u?user=Case&key=fixture';
    final r = {
      'nox_playlists': json([playlist('r', m3u: url)])
    };
    final yes = matchSyncPlaylists({
      'nox_playlists': json([playlist('l', m3u: url)])
    }, r);
    expect(
        jsonDecode((yes['nox_playlists'] as Map)['v'] as String)[0]['id'], 'r');
    for (final entry in [
      playlist('l'),
      playlist('l', m3u: '$url&extra=1'),
      playlist('l', m3u: url.replaceFirst('Case', 'case'))
    ]) {
      final local = {
        'nox_playlists': json([entry])
      };
      expect(identical(matchSyncPlaylists(local, r), local), isTrue);
    }
    for (final entry in [
      playlist('l', user: 'viewer'),
      playlist('l', server: 'http://example.invalid'),
      playlist('l', server: 'https://example.invalid/another'),
      {...playlist('l'), 'xtreamServer': ''},
      {...playlist('l'), 'xtreamUsername': null}
    ]) {
      final local = {
        'nox_playlists': json([entry])
      };
      expect(identical(matchSyncPlaylists(local, remote), local), isTrue);
    }
  });

  test('ambiguous remote accounts and corrupt definitions are left alone', () {
    final local = {
      'nox_playlists': json([playlist('local')])
    };
    final ambiguous = {
      'nox_playlists': json([playlist('a'), playlist('b')])
    };
    expect(identical(matchSyncPlaylists(local, ambiguous), local), isTrue);
    for (final bad in [tagged('{broken'), tagged('[]'), tagged('not json')]) {
      expect(matchSyncPlaylists(local, {'nox_playlists': bad}), local);
    }
  });

  test(
      'actual StorageService keys remap across viewers and per-playlist scopes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setPlaylists([PlaylistProfile.fromJson(playlist('local'))]);
    for (final viewer in ['main', 'kids']) {
      await storage.setActiveViewerId(viewer);
      await storage.setFavorites({'local::live_1', 'archive::arc_movie'});
      await storage.setFavoriteSeries({'local::series_2'});
      await storage.setFavoriteLiveOrder(['local::live_1']);
      await storage.setHiddenGroups('local', {'local::literal group'});
      await storage.setHiddenChannels('local', {'raw1'});
      await storage.setShownGroups('local', {'Kids'});
      await storage.setFavoritedGroups('local', {'Sport'});
      await storage.setGroupOrder('local', 'vod', ['Movies']);
      await storage.setChannelOrder('local', {
        'Sport': ['raw1']
      });
      await storage.setHiddenPlaylistGroups('tv', {'local'});
      await storage.setLastPosition('local::vod_5', 42000);
      await storage.setLastDuration('local::vod_5', 120000);
      await storage.setResumeFraction('local::ep_6', .42);
      await storage.setLastChannelId('local::live_1');
      await storage.setSportsPreferredPlaylist('local');
    }
    final before = storage.exportForSync();
    final result = matchSyncPlaylists(before, remote);
    final merged = mergeSync(
        base: null,
        local: result,
        remote: SyncSnapshot(remote, const {}),
        pending: const {});
    await storage.applySyncChanges(merged.values,
        before.keys.where((k) => !merged.values.containsKey(k)).toSet());
    expect(storage.getPlaylists().map((p) => p.id), ['remote']);
    for (final viewer in ['main', 'kids']) {
      await storage.setActiveViewerId(viewer);
      expect(storage.getFavorites(), {'remote::live_1', 'archive::arc_movie'});
      expect(storage.getFavoriteSeries(), {'remote::series_2'});
      expect(storage.getFavoriteLiveOrder(), ['remote::live_1']);
      expect(storage.getHiddenGroups('remote'), {'local::literal group'});
      expect(storage.getHiddenChannels('remote'), {'raw1'});
      expect(storage.getShownGroups('remote'), {'Kids'});
      expect(storage.getFavoritedGroups('remote'), {'Sport'});
      expect(storage.getGroupOrder('remote', 'vod'), ['Movies']);
      expect(storage.getChannelOrder('remote'), {
        'Sport': ['raw1']
      });
      expect(storage.getHiddenPlaylistGroups('tv'), {'remote'});
      expect(storage.getLastPosition('remote::vod_5'), 42000);
      expect(storage.getLastDuration('remote::vod_5'), 120000);
      expect(storage.isResumeFraction('remote::ep_6'), isTrue);
      expect(storage.getLastChannelId(), 'remote::live_1');
      expect(storage.getSportsPreferredPlaylist(), 'remote');
    }
    expect(result.keys.where((k) => k.contains('_local')), isEmpty);
  });

  test(
      'JSON references remap while labels, raw ids, URLs and secrets stay intact',
      () {
    final local = <String, Object?>{
      'nox_playlists': json([playlist('local')]),
      'nox_my_groups': json({
        'groups': ['local::title'],
        'moves': {'local::live_1': 'local::title'},
        'order': {
          'local::title': ['local::live_1']
        },
        'pmoves': {'local::live_1': 'p:local\u0000local::Sport'},
        'copies': {
          'local::live_2': ['o:local::title', 'p:local\u0000News']
        },
        'porder': {
          'p:local\u0000local::Sport': ['local::live_1', 'other::live_9']
        }
      }),
      'nox_channel_links_local': json({
        'raw1': {'playlistId': 'local', 'rawId': 'local::raw'}
      }),
      'nox_playlist_edits_local': json({
        'names': {'raw1': 'local::name'},
        'fallbacks': {
          'raw1': ['local::live_1']
        },
        'logos': {'raw1': 'https://local.invalid/local::logo'}
      }),
      'vesper_series_subs': json({
        'local::series_2': {'label': 'local::track'}
      }),
      'vesper_audio_choices': json({
        'local::vod_5': {'label': 'local::track'}
      }),
      'vesper_sports_channel_picks': json({
        'teams': {'nhl:1': 'local::live_1'},
        'events': {
          'nhl:game': {'c': 'local::live_2', 't': 100}
        }
      }),
      'vesper_sports_channel_lists': json({
        'lists': [
          {
            'id': 'list',
            'name': 'local::title',
            'channels': ['local::live_1'],
            'excluded': ['local::live_2'],
            'filters': {
              'Playlist': ['local'],
              'Group': ['local::Sport'],
              'Network': ['local::literal']
            }
          }
        ],
        'picks': {'tsn': 'local::live_1'},
        'tags': {
          'local::live_1': {
            'Playlist': ['local']
          }
        },
        'sources': {
          'team:nhl:1': {
            'ids': ['local::live_2'],
            'until': 123
          }
        }
      }),
      'nox_recent_searches': tagged(['local::literal']),
      'vesper_archive_sources': json([
        {'id': 'local::id', 'url': 'https://local.invalid/local::token'}
      ]),
      'unknown_key': tagged('local::literal'),
    };
    final result = matchSyncPlaylists(local, remote);
    dynamic read(String k) => jsonDecode((result[k] as Map)['v'] as String);
    expect(read('nox_my_groups')['moves'], {'remote::live_1': 'local::title'});
    expect(read('nox_my_groups')['order'], {
      'local::title': ['remote::live_1']
    });
    expect(read('nox_my_groups')['pmoves'],
        {'remote::live_1': 'p:remote\u0000local::Sport'});
    expect(read('nox_my_groups')['copies'], {
      'remote::live_2': ['o:local::title', 'p:remote\u0000News']
    });
    expect(read('nox_my_groups')['porder'], {
      'p:remote\u0000local::Sport': ['remote::live_1', 'other::live_9']
    });
    expect(read('nox_channel_links_remote')['raw1'],
        {'playlistId': 'remote', 'rawId': 'local::raw'});
    expect(read('nox_playlist_edits_remote')['fallbacks'], {
      'raw1': ['remote::live_1']
    });
    expect(read('nox_playlist_edits_remote')['names'], {'raw1': 'local::name'});
    expect(read('vesper_series_subs')['remote::series_2'],
        {'label': 'local::track'});
    expect(read('vesper_audio_choices')['remote::vod_5'],
        {'label': 'local::track'});
    expect(read('vesper_sports_channel_picks')['events']['nhl:game']['c'],
        'remote::live_2');
    expect(read('vesper_sports_channel_lists')['lists'][0]['filters'], {
      'Playlist': ['remote'],
      'Group': ['remote::Sport'],
      'Network': ['local::literal']
    });
    expect(read('vesper_sports_channel_lists')['sources']['team:nhl:1']['ids'],
        ['remote::live_2']);
    for (final k in [
      'nox_recent_searches',
      'vesper_archive_sources',
      'unknown_key'
    ]) {
      expect(result[k], local[k]);
    }
  });

  test(
      'duplicate local accounts collapse; canonical values and all favourites survive',
      () {
    final local = {
      'nox_playlists': json([playlist('local'), playlist('remote')]),
      'nox_favorites': tagged(['local::a', 'remote::a']),
      'nox_hidden_groups_local': tagged(['A']),
      'nox_hidden_groups_remote': tagged(['B']),
      'nox_last_position_local::a': tagged(100),
      'nox_last_position_remote::a': tagged(200)
    };
    final r = matchSyncPlaylists(local, remote);
    expect(
        jsonDecode((r['nox_playlists'] as Map)['v'] as String), hasLength(1));
    expect(r['nox_hidden_groups_remote'], tagged(['B', 'A']));
    expect(r['nox_last_position_remote::a'], tagged(200));
    expect(r['nox_favorites'], tagged(['remote::a']));
  });
  test(
      'Continue Watching file references remap across viewers without changing media data',
      () {
    final channel = Channel(
        id: 'local::vod_5',
        rawId: 'vod_5',
        playlistId: 'local',
        name: 'local::title',
        group: 'local::group',
        url: 'https://example.invalid/local::fixture',
        seriesId: 2,
        onDemand: true);
    for (final key in [
      'file:recently_played',
      'file:recently_played_vp_kids'
    ]) {
      final local = {
        'nox_playlists': json([playlist('local')]),
        key: json([channel.toJson()])
      };
      final result = matchSyncPlaylists(local, remote);
      final rows = jsonDecode((result[key] as Map)['v'] as String) as List;
      final restored =
          Channel.fromJson(Map<String, dynamic>.from(rows.single as Map));
      expect(restored.id, 'remote::vod_5');
      expect(restored.playlistId, 'remote');
      expect(restored.seriesId, channel.seriesId);
      expect(restored.rawId, channel.rawId);
      expect(restored.sourceName, channel.sourceName);
      expect(restored.group, channel.group);
      expect(restored.url, channel.url);
      expect(local[key], json([channel.toJson()]));
    }
  });
}
