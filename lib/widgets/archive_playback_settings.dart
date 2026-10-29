import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../services/archive_playback_preferences.dart';
import '../services/archive_service.dart';
import '../services/storage_service.dart';

Future<void> showArchivePlaybackSettings(BuildContext context) async {
  final storage = context.read<StorageService>();
  final generation = storage.viewerGeneration;
  final prefs = ArchivePlaybackPreferences.read(storage);
  var auto = prefs.autoPlay, hdr = prefs.avoidHdr;
  var lang = prefs.language, source = prefs.sourceKey;
  var height = prefs.maxHeight;
  final sources = context
      .read<ArchiveService>()
      .enabledSources
      .where((source) => !source.listOnly && source.tracker == null)
      .toList();
  if (!sources.any((s) => s.key == source)) source = '';
  final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
                title: Text(tr('Media Hub playback')),
                content: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      SwitchListTile(
                          autofocus: true,
                          title: Text(tr('Auto-play preferred stream')),
                          value: auto,
                          onChanged: (v) => update(() => auto = v)),
                      DropdownButtonFormField<String>(
                          initialValue: source,
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText: tr('Preferred source')),
                          items: [
                            DropdownMenuItem(
                                value: '', child: Text(tr('Any source'))),
                            for (final s in sources)
                              DropdownMenuItem(
                                  value: s.key,
                                  child: Text(s.name,
                                      overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: (v) => update(() => source = v ?? '')),
                      DropdownButtonFormField<String>(
                          initialValue: lang,
                          decoration: InputDecoration(
                              labelText: tr('Preferred audio language')),
                          items: [
                            for (final e in const {
                              '': 'Any language',
                              'en': 'English',
                              'fr': 'French',
                              'es': 'Spanish',
                              'de': 'German',
                              'it': 'Italian',
                              'pt': 'Portuguese'
                            }.entries)
                              DropdownMenuItem(
                                  value: e.key, child: Text(tr(e.value)))
                          ],
                          onChanged: (v) => update(() => lang = v ?? '')),
                      DropdownButtonFormField<int>(
                          initialValue: height,
                          decoration:
                              InputDecoration(labelText: tr('Maximum quality')),
                          items: [
                            for (final e in const {
                              0: 'Any quality',
                              720: '720p',
                              1080: '1080p',
                              2160: '4K'
                            }.entries)
                              DropdownMenuItem(
                                  value: e.key, child: Text(tr(e.value)))
                          ],
                          onChanged: (v) => update(() => height = v ?? 0)),
                      SwitchListTile(
                          title: Text(tr('Prefer SDR')),
                          value: hdr,
                          onChanged: (v) => update(() => hdr = v)),
                      Text(
                          tr('If no stream matches, choose one manually. Format and language information comes from your sources.'),
                          style: Theme.of(ctx).textTheme.bodySmall),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(tr('Cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(tr('Save')))
                ],
              )));
  if (saved == true && storage.viewerGeneration == generation) {
    await ArchivePlaybackPreferences(
            autoPlay: auto,
            language: lang,
            maxHeight: height,
            sourceKey: source,
            avoidHdr: hdr)
        .save(storage);
  }
}
