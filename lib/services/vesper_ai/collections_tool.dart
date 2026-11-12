part of 'vesper_tools.dart';

// `collections`: the Media Hub's collections for an AI (owner, 2026-11-11,
// a user's idea: add / remove catalogs in our collections from the
// connector). Rows of tiles imported from a Nuvio collections file
// (Settings > Media Hub sources > Collections); each tile opens a page of
// catalogs from the viewer's own add-ons (AIOMetadata). The AI arranges
// them; it can't make new catalogs: those are set up on the add-on's own
// page (AIOMetadata's Catalogs), then Refresh Media Hub lists them here.

/// A catalog's key for the AI: `type:id` ("movie:tmdb.top").
String _catalogKey(ArchiveCatalog c) => '${c.wire}:${c.id}';

/// The collection named [name] (its name, emoji or not, or its id).
HubCollection _collectionNamed(List<HubCollection> list, String name) {
  if (name.isEmpty) {
    throw VesperToolError('Which collection? Give collection (list shows '
        'them).');
  }
  final want = TitleSearch.fold(name);
  for (final c in list) {
    if (c.id == name ||
        TitleSearch.fold(c.label) == want ||
        TitleSearch.fold(c.title) == want) {
      return c;
    }
  }
  throw VesperToolError('No collection "$name" (list shows them).');
}

/// The tile named [tile] in [collection] (or in any collection when
/// [collection] is empty: it must be the only tile of that name).
(HubCollection, HubFolder) _tileNamed(
    List<HubCollection> list, String collection, String tile) {
  if (tile.isEmpty) throw VesperToolError('Which tile? Give tile.');
  final want = TitleSearch.fold(tile);
  final where =
      collection.isEmpty ? list : [_collectionNamed(list, collection)];
  final found = [
    for (final c in where)
      for (final f in c.folders)
        if (f.id == tile || TitleSearch.fold(f.title) == want) (c, f),
  ];
  if (found.isEmpty) {
    throw VesperToolError('No tile "$tile"${collection.isEmpty ? '' : ' in '
        '$collection'} (list shows them).');
  }
  if (found.length > 1) {
    throw VesperToolError('"$tile" is in ${found.length} collections: give '
        'collection too.');
  }
  return found.single;
}

final _collectionsTool = VesperTool(
  name: 'collections',
  description:
      'Media Hub collections: rows of tiles on the Media Hub tab (Streaming: '
      'Netflix, Disney+…), each tile opening a page of catalogs from the '
      'viewer\'s add-ons (imported from a Nuvio collections file). list: the '
      'collections and their tiles (with collection: each tile\'s catalogs). '
      'catalogs: the add-on catalogs a tile can use (query filters by name); '
      'pass their key back. turn_on / turn_off: a collection. home: show '
      '(on true) or take a collection off Home. move: a collection to top, '
      'bottom, up / down or a position. remove: a collection. add_catalogs / '
      'remove_catalogs: catalogs (keys) on a tile. create_tile: a new tile '
      'with catalogs (the collection is made if new). rename_tile, '
      'remove_tile. hide_rows: on true = catalogs inside collections leave '
      'the Media Hub rows. Only catalogs the add-ons already have can be '
      'used: new ones are made on the add-on\'s own page (AIOMetadata), then '
      'Refresh Media Hub.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': [
          'list',
          'catalogs',
          'turn_on',
          'turn_off',
          'home',
          'move',
          'remove',
          'add_catalogs',
          'remove_catalogs',
          'create_tile',
          'rename_tile',
          'remove_tile',
          'hide_rows',
        ],
      },
      'collection': {
        'type': 'string',
        'description': 'The collection\'s name ("Streaming").',
      },
      'tile': {
        'type': 'string',
        'description': 'The tile\'s name ("Netflix"); for create_tile and '
            'rename_tile the new tile\'s name is name.',
      },
      'name': {
        'type': 'string',
        'description': 'create_tile: the new tile\'s name. rename_tile: the '
            'new name.',
      },
      'catalogs': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Catalog keys from the catalogs action '
            '("movie:tmdb.top").',
      },
      'query': {
        'type': 'string',
        'description': 'catalogs: words of the catalog\'s name.',
      },
      'on': {
        'type': 'boolean',
        'description': 'home and hide_rows: true or false.',
      },
      'to': {
        'type': 'string',
        'description': 'move: top, bottom, up, down or a position (1 = '
            'first).',
      },
      'steps': {
        'type': 'integer',
        'description': 'move up / down: how many places (default 1).',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    final hub = box.archive ??
        (throw VesperToolError('The Media Hub is not available here.'));
    final action = _str(args, 'action');
    final list = hub.collections;
    final installed = hub.collectionCatalogs();

    Map<String, Object?> describeTile(HubFolder f, {bool catalogs = false}) {
      final found = hub.folderPageCatalogs(f);
      return {
        'tile': f.title,
        'catalogs_found': found.length,
        if (found.isEmpty) 'note': 'none of its catalogs is in the add-ons',
        if (catalogs)
          'catalogs': [
            for (final (s, c) in found)
              {
                'key': _catalogKey(c),
                'name': c.name,
                'add_on': s.name,
              }
          ],
      };
    }

    switch (action) {
      case 'list':
        final only = _str(args, 'collection');
        final shown = only.isEmpty ? list : [_collectionNamed(list, only)];
        return {
          'collections': [
            for (final c in shown)
              {
                'collection': c.label,
                'on': c.enabled,
                'on_home': c.onHome,
                'tiles': [
                  for (final f in c.folders)
                    only.isEmpty
                        ? '${f.title}${hub.folderCatalogs(f).isEmpty ? ' (no '
                            'catalogs found)' : ''}'
                        : describeTile(f, catalogs: true),
                ],
              }
          ],
          'catalogs_inside_leave_rows': hub.collectionsHideRows,
          if (list.isEmpty)
            'note': 'No collections yet: the viewer imports a Nuvio '
                'collections file in Settings > Media Hub sources > '
                'Collections.',
        };
      case 'catalogs':
        final query = TitleSearch.fold(_str(args, 'query'));
        final matches = [
          for (final (s, c) in installed)
            if (query.isEmpty ||
                TitleSearch.fold('${c.name} ${c.id}').contains(query))
              {
                'key': _catalogKey(c),
                'name': c.name,
                'type': c.wire,
                'add_on': s.name,
              },
        ];
        return {
          'catalogs': matches.take(150).toList(),
          if (matches.length > 150) 'more': matches.length - 150,
          if (installed.isEmpty)
            'note': 'No add-on catalogs: add the add-on (AIOMetadata) in '
                'Media Hub sources first.',
        };
    }

    if (box.restrictedViewer) {
      throw VesperToolError('This profile cannot change collections.');
    }

    /// The installed catalogs behind [keys] ("movie:tmdb.top" or an id).
    List<(ArchiveSource, ArchiveCatalog)> catalogsOf(Object? keys) {
      if (keys is! List || keys.isEmpty) {
        throw VesperToolError('Give catalogs: keys from the catalogs action.');
      }
      final out = <(ArchiveSource, ArchiveCatalog)>[];
      final unknown = <String>[];
      for (final k in keys) {
        final key = '$k'.trim();
        final hits = [
          for (final sc in installed)
            if (_catalogKey(sc.$2) == key || sc.$2.id == key) sc
        ];
        if (hits.isEmpty) unknown.add(key);
        for (final h in hits) {
          if (!out.any((o) => _catalogKey(o.$2) == _catalogKey(h.$2))) {
            out.add(h);
          }
        }
      }
      if (unknown.isNotEmpty) {
        throw VesperToolError('Not in the add-ons: ${unknown.join(', ')} '
            '(the catalogs action lists what is).');
      }
      return out;
    }

    HubCollectionSource sourceOf((ArchiveSource, ArchiveCatalog) sc) =>
        HubCollectionSource(
            addonId: sc.$1.addonId ?? '',
            catalogId: sc.$2.id,
            type: sc.$2.wire,
            genre: sc.$2.extra['genre']);

    Future<void> replace(HubCollection c) =>
        hub.saveCollections([for (final x in list) x.id == c.id ? c : x]);

    Future<void> replaceTile(HubCollection c, HubFolder f) =>
        replace(c.copyWith(folders: [
          for (final x in c.folders) x.id == f.id ? f : x,
        ]));

    switch (action) {
      case 'turn_on' || 'turn_off':
        final c = _collectionNamed(list, _str(args, 'collection'));
        await hub.setCollectionEnabled(c.id, action == 'turn_on');
        return {'collection': c.label, 'on': action == 'turn_on'};
      case 'home':
        final c = _collectionNamed(list, _str(args, 'collection'));
        final on = args['on'] != false;
        await hub.setCollectionOnHome(c.id, on);
        return {
          'collection': c.label,
          'on_home': on,
          if (on && !c.enabled)
            'note': 'It is off: turn_on to see it (on Home too).',
        };
      case 'hide_rows':
        final on = args['on'] != false;
        await hub.setCollectionsHideRows(on);
        return {'catalogs_inside_leave_rows': on};
      case 'move':
        final c = _collectionNamed(list, _str(args, 'collection'));
        final to = _str(args, 'to');
        if (to.isEmpty) throw VesperToolError('Give to.');
        final from = list.indexWhere((x) => x.id == c.id);
        final steps = _int(args, 'steps', 1, min: 1, max: 1000);
        final index = _moveTarget(to, from, list.length, steps);
        await hub.moveCollection(c.id, index - from);
        return {
          'collection': c.label,
          'position': index + 1,
          'of': list.length,
        };
      case 'remove':
        final c = _collectionNamed(list, _str(args, 'collection'));
        await _confirmRemote(
            box,
            caller,
            'An AI app wants to remove the collection {name}.',
            {'name': c.label});
        await hub.removeCollection(c.id);
        return {'removed': c.label};
      case 'add_catalogs':
        final (c, f) =
            _tileNamed(list, _str(args, 'collection'), _str(args, 'tile'));
        final adding = catalogsOf(args['catalogs']);
        final have = {for (final s in f.sources) '${s.type}:${s.catalogId}'};
        final fresh = [
          for (final sc in adding)
            if (!have.contains(_catalogKey(sc.$2))) sourceOf(sc)
        ];
        await replaceTile(c, f.copyWith(sources: [...f.sources, ...fresh]));
        return {
          'tile': f.title,
          'added': [for (final s in fresh) '${s.type}:${s.catalogId}'],
          if (fresh.length < adding.length)
            'already_there': adding.length - fresh.length,
        };
      case 'remove_catalogs':
        final (c, f) =
            _tileNamed(list, _str(args, 'collection'), _str(args, 'tile'));
        final keys = args['catalogs'];
        if (keys is! List || keys.isEmpty) {
          throw VesperToolError('Give catalogs: keys (list with collection '
              'shows a tile\'s).');
        }
        final drop = {for (final k in keys) '$k'.trim()};
        final kept = [
          for (final s in f.sources)
            if (!drop.contains('${s.type}:${s.catalogId}') &&
                !drop.contains(s.catalogId))
              s
        ];
        if (kept.length == f.sources.length) {
          throw VesperToolError('None of these catalogs is on ${f.title}.');
        }
        if (kept.isEmpty) {
          throw VesperToolError('That would leave ${f.title} empty: '
              'remove_tile removes the tile.');
        }
        await replaceTile(c, f.copyWith(sources: kept));
        return {
          'tile': f.title,
          'removed': f.sources.length - kept.length,
          'left': kept.length,
        };
      case 'create_tile':
        final name = _str(args, 'name').isNotEmpty
            ? _str(args, 'name')
            : _str(args, 'tile');
        if (name.isEmpty) throw VesperToolError('Give the tile a name.');
        final collection = _str(args, 'collection');
        if (collection.isEmpty) {
          throw VesperToolError('In which collection? Give collection (a new '
              'name makes one).');
        }
        final sources = [
          for (final sc in catalogsOf(args['catalogs'])) sourceOf(sc)
        ];
        final tile = HubFolder(
          id: 'vesper.${DateTime.now().millisecondsSinceEpoch}',
          title: name,
          sources: sources,
        );
        final want = TitleSearch.fold(collection);
        final existing = list
            .where((c) =>
                TitleSearch.fold(c.label) == want ||
                TitleSearch.fold(c.title) == want)
            .firstOrNull;
        if (existing == null) {
          await hub.saveCollections([
            ...list,
            HubCollection(
                id: 'vesper.${DateTime.now().millisecondsSinceEpoch}',
                title: collection,
                folders: [tile]),
          ]);
          return {'collection': collection, 'created': true, 'tile': name};
        }
        await replace(existing.copyWith(folders: [...existing.folders, tile]));
        return {'collection': existing.label, 'tile': name};
      case 'rename_tile':
        final (c, f) =
            _tileNamed(list, _str(args, 'collection'), _str(args, 'tile'));
        final name = _str(args, 'name');
        if (name.isEmpty) throw VesperToolError('Give the new name.');
        await replaceTile(c, f.copyWith(title: name));
        return {'tile': name, 'was': f.title};
      case 'remove_tile':
        final (c, f) =
            _tileNamed(list, _str(args, 'collection'), _str(args, 'tile'));
        await _confirmRemote(box, caller,
            'An AI app wants to remove the tile {name}.', {'name': f.title});
        final left = [
          for (final x in c.folders)
            if (x.id != f.id) x
        ];
        if (left.isEmpty) {
          await hub.removeCollection(c.id);
          return {'removed': f.title, 'collection_removed': c.label};
        }
        await replace(c.copyWith(folders: left));
        return {'removed': f.title, 'collection': c.label};
    }
    throw VesperToolError('Unknown collections action $action.');
  },
);
