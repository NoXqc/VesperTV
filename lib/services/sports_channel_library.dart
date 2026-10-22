import 'dart:convert';
import '../models/channel.dart';
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
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'channels': channels};
}

class SportsChannelLists {
  SportsChannelLists(this.storage) {
    try {
      final data = jsonDecode(storage.getSportsChannelLists() ?? '{}') as Map;
      for (final row in data['lists'] as List? ?? []) {
        lists.add(SportsChannelList(
            id: row['id'] as String,
            name: row['name'] as String,
            channels: (row['channels'] as List).cast<String>()));
      }
    } catch (_) {
      lists.clear();
    }
  }
  final StorageService storage;
  final List<SportsChannelList> lists = [];
  Future<void> save() => storage.setSportsChannelLists(jsonEncode({
        'version': 1,
        'lists': lists.map((e) => e.toJson()).toList(),
      }));
  SportsChannelList create(String name, Iterable<String> ids) {
    final list = SportsChannelList(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        channels: ids.toSet());
    lists.add(list);
    return list;
  }
}

class SportsChannelLibrary {
  SportsChannelLibrary(Iterable<Channel> visible)
      : channels = {
          for (final c in visible)
            if (Channel.isLiveId(c.rawId)) c.id: c,
        }.values.toList();
  final List<Channel> channels;
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
    return [
      for (final id in list.channels)
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
