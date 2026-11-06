import '../l10n/l10n.dart';
import '../models/playlist_profile.dart';
import 'epg_channel_info.dart';

List<String> editorGuideUrls(PlaylistProfile profile) => {
      if (profile.epgUrl?.isNotEmpty ?? false) profile.epgUrl!,
      ...profile.extraEpgUrls,
    }.toList();

List<Map<String, String>> editorGuideSources(PlaylistProfile profile) {
  final urls = editorGuideUrls(profile);
  return [
    for (var i = 0; i < urls.length; i++)
      {
        'id': '$i',
        'name': urls[i] == profile.epgUrl
            ? tr('Main guide')
            : tr('Extra guide {number}',
                {'number': '${profile.extraEpgUrls.indexOf(urls[i]) + 1}'}),
      }
  ];
}

List<Map<String, String>> editorGuideSearch(PlaylistProfile profile,
    Iterable<EpgChannelInfo> Function(String) lookup, String query,
    {String? source}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (words.isEmpty) return [];
  final urls = editorGuideUrls(profile);
  final labels = editorGuideSources(profile);
  final results = <Map<String, String>>[];
  for (var i = 0; i < urls.length; i++) {
    if (source?.isNotEmpty == true && source != '$i') continue;
    for (final entry in lookup(urls[i])) {
      final hay = '${entry.name} ${entry.id}'.toLowerCase();
      if (!words.every(hay.contains)) continue;
      final logo = epgLogoUrl(entry.logoUrl);
      results.add({
        'id': entry.id,
        'n': entry.name,
        'source': '$i',
        'sourceName': labels[i]['name']!,
        if (logo != null) 'l': logo
      });
      if (results.length == 40) return results;
    }
  }
  return results;
}

Map<String, String> editorEpgTexts() => {
      for (final key in [
        'Use EPG logo',
        'Use provider logo',
        'All guide sources',
        'No EPG logo',
        'Logo selected. Save changes to apply it.',
        'Provider logo selected. Save changes to apply it.',
        'The viewer changed. Reopen the playlist editor.',
        'Logo URLs must be HTTP(S) links of at most 1000 characters.',
        'Guide sources',
        'Guide and logo',
        'Update EPG Now',
        "Using the channel's default guide match.",
        'The TV is loading the guide. Search again when it finishes.',
        'No matching guide channels. Try fewer words or Update EPG Now.',
      ])
        key: tr(key)
    };
