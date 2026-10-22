import 'dart:convert';
import '../models/channel.dart';
import '../models/sports.dart';
import '../utils/channel_name_matching.dart';
import 'multiview_sports.dart';
import 'storage_service.dart';

/// References only: never copies stream URLs or changes groups/favourites.
class SportsChannelList {
  SportsChannelList(
      {required this.id,
      required this.name,
      Iterable<String> channels = const []})
      : channels = channels.toList();
  final String id;
  String name;
  final List<String> channels;
  Map<String, List<String>> filters = {};
  final Set<String> excluded = {};
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'channels': channels,
        'filters': filters,
        'excluded': excluded.toList()
      };
}

class SportsChannelLists {
  SportsChannelLists(this.storage) {
    try {
      final data = jsonDecode(storage.getSportsChannelLists() ?? '{}') as Map;
      for (final row in data['lists'] as List? ?? []) {
        final list = SportsChannelList(
            id: row['id'] as String,
            name: row['name'] as String,
            channels: (row['channels'] as List).cast<String>());
        list.filters = _filters(row['filters']);
        list.excluded.addAll((row['excluded'] as List? ?? []).cast<String>());
        lists.add(list);
      }
      for (final entry in (data['tags'] as Map? ?? {}).entries) {
        tags[entry.key as String] = _filters(entry.value);
      }
      for (final entry in (data['sources'] as Map? ?? {}).entries) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        if ((value['until'] as num? ?? double.infinity) >
            DateTime.now().millisecondsSinceEpoch) {
          sources[entry.key as String] = value;
        }
      }
    } catch (_) {
      lists.clear();
    }
  }
  final StorageService storage;
  final List<SportsChannelList> lists = [];
  final Map<String, Map<String, List<String>>> tags = {};
  final Map<String, Map<String, dynamic>> sources = {};
  static Map<String, List<String>> _filters(dynamic raw) => raw is Map
      ? {
          for (final e in raw.entries)
            e.key as String: (e.value as List).cast<String>(),
        }
      : {};
  Future<void> save() => storage.setSportsChannelLists(jsonEncode({
        'version': 1,
        'lists': lists.map((e) => e.toJson()).toList(),
        'tags': tags,
        'sources': sources,
      }));
  SportsChannelList create(String name, Iterable<String> ids) {
    final list = SportsChannelList(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        channels: ids.toSet());
    lists.add(list);
    return list;
  }

  Future<void> setSources(String scope, Iterable<String> ids,
      {bool event = false}) async {
    sources[scope] = {
      'ids': ids.toSet().toList(),
      if (event)
        'until':
            DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch
    };
    await save();
  }

  Set<String> sourcesFor(SportsGame game, String eventKey) => {
        for (final key in [
          'event:$eventKey',
          'team:${game.league.id}:${game.home.id}',
          'team:${game.league.id}:${game.away.id}',
          'league:${game.league.id}'
        ])
          ...(sources[key]?['ids'] as List? ?? []).cast<String>(),
      };
}

class SportsChannelLibrary {
  SportsChannelLibrary(Iterable<Channel> visible, {this.store})
      : channels = {
          for (final c in visible)
            if (Channel.isLiveId(c.rawId)) c.id: c,
        }.values.toList();
  final List<Channel> channels;
  final SportsChannelLists? store;
  static final _baseTags = Expando<Map<String, List<String>>>();
  Map<String, List<String>> tagsFor(Channel c) => {
        ...(_baseTags[c] ??= _infer(c)),
        ...?store?.tags[c.id],
      };
  Map<String, List<String>> _infer(Channel c) {
    final name = c.name.toUpperCase();
    final text = '$name ${c.group.toUpperCase()}';
    final country = RegExp(
            r'^\s*(US|USA|CA|CAFR|UK|GB|GR|FR|IT|ES|DE|BR|PT|AU|NZ|IE|RO|RS|HR|BG)\s*[:|\-]')
        .firstMatch(name)
        ?.group(1);
    final network = RegExp(
            r'\b(ESPN\+|ESPN PLUS|ESPN\d*|TSN\s*\d*|RDS\s*\d*|SPORTSNET|NBA TV|NFL NETWORK|NHL NETWORK|MLB NETWORK|BEIN SPORTS|EUROSPORT|DAZN)(?!\w)')
        .firstMatch(name)
        ?.group(1);
    final sports = <String>[];
    for (final e in {
      'hockey': r'\b(HOCKEY|NHL|AHL)\b',
      'basketball': r'\b(BASKETBALL|NBA|WNBA)\b',
      'football': r'\b(NFL|CFL|AMERICAN FOOTBALL)\b',
      'soccer': r'\b(SOCCER|FUTBOL|UEFA|PREMIER LEAGUE)\b',
      'baseball': r'\b(BASEBALL|MLB)\b',
      'tennis': r'\b(TENNIS|ATP|WTA)\b',
      'golf': r'\b(GOLF|PGA)\b',
      'racing': r'\b(FORMULA|NASCAR|RACING)\b'
    }.entries) {
      if (RegExp(e.value).hasMatch(text)) sports.add(e.key);
    }
    return {
      'Playlist': [c.playlistId],
      'Group': ['${c.playlistId}::${c.group}'],
      'Country': [
        country == 'USA'
            ? 'US'
            : country == 'CAFR'
                ? 'CA'
                : country == 'GB'
                    ? 'UK'
                    : country ?? 'Unknown'
      ],
      'Network': [network ?? 'Unknown'],
      'Sport': sports.isEmpty ? ['Unknown'] : sports,
      'League': [
        for (final token in (RegExp(
                r'\b(NFL|NBA|WNBA|NHL|MLB|MLS|CFL|AHL|ECHL|ATP|WTA|PGA|F1)\b')
            .allMatches(text)))
          for (final l in [...kSportsLeagues, ...kSportsLeagueBank])
            if (l.shortName.toUpperCase() == token.group(1)) l.id
      ],
    };
  }

  bool accepts(Channel c, Map<String, List<String>> filters) {
    final tags = tagsFor(c);
    return filters.entries.every((e) =>
        e.key == 'All' ||
        (e.key == 'Query'
            ? e.value.any((v) => v
                .toLowerCase()
                .split(RegExp(r'\s+'))
                .every(c.name.toLowerCase().contains))
            : e.value.isEmpty ||
                e.value.any((v) => (tags[e.key]?.isNotEmpty ?? false)
                    ? tags[e.key]!.contains(v)
                    : v == 'Unknown')));
  }

  static String category(Channel c) {
    final text = c.name.toUpperCase();
    if (RegExp(r'\b(NBA TV|NFL NETWORK|NHL NETWORK|MLB NETWORK|CFL)\b')
        .hasMatch(text)) {
      return 'League networks';
    }
    if (RegExp(
            r'\b(REGIONAL|BALLY|FAN(DUEL)? SPORTS|MONUMENTAL|NBC SPORTS|SPORTSNET (EAST|WEST|ONTARIO|PACIFIC))\b')
        .hasMatch(text)) {
      return 'Regional channels';
    }
    return MultiviewSports.isSports(c) ? 'Sports networks' : '';
  }

  List<Channel> search({String query = '', String? group, Set<String>? ids}) {
    final words =
        query.toLowerCase().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return channels
        .where((c) =>
            (group == null || '${c.playlistId}::${c.group}' == group) &&
            (ids == null || ids.contains(c.id)) &&
            words.every(c.name.toLowerCase().contains))
        .toList();
  }

  List<Channel> members(SportsChannelList list) {
    final byId = {for (final c in channels) c.id: c};
    final ids = {
      ...list.channels,
      if (list.filters.isNotEmpty)
        ...channels.where((c) => accepts(c, list.filters)).map((c) => c.id)
    }..removeAll(list.excluded);
    return [
      for (final id in ids)
        if (byId[id] case final c?) c
    ];
  }

  List<Channel> versions(Channel channel) {
    final key = channelCopyKey(channel.name);
    return key.isEmpty
        ? [channel]
        : channels.where((c) => channelCopyKey(c.name) == key).toList();
  }
}
