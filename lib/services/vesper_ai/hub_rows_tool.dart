part of 'vesper_tools.dart';

// `hub_rows`: the Media Hub tab's rows for an AI, the same switches as
// Customize Media Hub (owner, 2026-11-11: "I should be able to tell my
// Claude MCP to hide anything I don't want"). Collections (rows of tiles)
// are the collections tool's.

/// The name a row shows (without the genre the tab may add).
String _hubRowName(ArchiveRow row) {
  if (row.customTitle != null) return row.customTitle!;
  if (row.isHistory) return 'Recently watched';
  if (row.isFavorites) return 'Favourites';
  return row.title;
}

/// Movies, shows or both from [args]' `type`.
List<ArchiveType> _hubRowTypes(Map<String, Object?> args) =>
    switch (_str(args, 'type')) {
      'movies' || 'movie' => const [ArchiveType.movie],
      'shows' || 'series' => const [ArchiveType.series],
      _ => ArchiveType.values,
    };

final _hubRowsTool = VesperTool(
  name: 'hub_rows',
  description:
      'The Media Hub tab\'s rows (each add-on catalog, Continue watching, '
      'Recently watched, Favourites), like Customize Media Hub on the TV. '
      'list: the rows of movies and/or shows, with hidden / pinned. hide / '
      'show: rows by name (every row of that name unless source narrows it '
      'to one add-on). pin / unpin: keep rows at the top. move: one row to '
      'top, bottom, up or down. rename: one row (name, empty = its own name '
      'again). Rows of collection tiles are the collections tool\'s.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'hide', 'show', 'pin', 'unpin', 'move', 'rename'],
      },
      'type': {
        'type': 'string',
        'enum': ['movies', 'shows', 'both'],
        'description': 'Which tab side (default both).',
      },
      'rows': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Row names as list shows them.',
      },
      'source': {
        'type': 'string',
        'description': 'Only rows of this add-on (its name, or part of it).',
      },
      'to': {
        'type': 'string',
        'description': 'move: top, bottom, up or down.',
      },
      'name': {
        'type': 'string',
        'description': 'rename: the new name.',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    final hub = box.archive ??
        (throw VesperToolError('The Media Hub is not available here.'));
    final action = _str(args, 'action');
    final types = _hubRowTypes(args);
    List<(ArchiveType, ArchiveRow)> all() => [
          for (final t in types)
            for (final r in hub.rows(t, includeHidden: true))
              if (!r.isSearch) (t, r),
        ];

    if (action == 'list') {
      final rows = all();
      return {
        'rows': [
          for (final (t, r) in rows)
            {
              'row': _hubRowName(r),
              'type': t == ArchiveType.movie ? 'movies' : 'shows',
              if (r.continuations == null && !r.isHistory && !r.isFavorites)
                'source': r.source.name,
              if (hub.rowHidden(r.key)) 'hidden': true,
              if (hub.rowPinned(r.key)) 'pinned': true,
            }
        ],
        if (rows.isEmpty)
          'note': 'No rows loaded yet: open the Media Hub once (or Refresh '
              'it) and ask again.',
      };
    }

    if (box.restrictedViewer) {
      throw VesperToolError('This profile cannot change the Media Hub.');
    }
    final names = args['rows'];
    if (names is! List || names.isEmpty) {
      throw VesperToolError('Give rows: names from the list action.');
    }
    final source = TitleSearch.fold(_str(args, 'source'));
    final rows = all();
    final found = <(ArchiveType, ArchiveRow)>[];
    final missing = <String>[];
    for (final n in names) {
      final want = TitleSearch.fold('$n');
      final hits = [
        for (final hit in rows)
          if (TitleSearch.fold(_hubRowName(hit.$2)) == want &&
              (source.isEmpty ||
                  TitleSearch.fold(hit.$2.source.name).contains(source)))
            hit
      ];
      if (hits.isEmpty) missing.add('$n');
      found.addAll(hits);
    }
    if (found.isEmpty) {
      throw VesperToolError('No row named ${missing.join(', ')} (list shows '
          'them).');
    }
    String label((ArchiveType, ArchiveRow) hit) =>
        '${_hubRowName(hit.$2)} (${hit.$1 == ArchiveType.movie ? 'movies' : 'shows'}'
        '${hit.$2.continuations == null && !hit.$2.isHistory && !hit.$2.isFavorites ? ', ${hit.$2.source.name}' : ''})';

    switch (action) {
      case 'hide' || 'show' || 'pin' || 'unpin':
        final flag = action == 'hide' || action == 'show' ? 'hidden' : 'pinned';
        final on = action == 'hide' || action == 'pin';
        final keys = {for (final hit in found) hit.$2.key};
        for (final k in keys) {
          await hub.setRowFlag(k, flag, on);
        }
        return {
          'done': [for (final hit in found) label(hit)],
          if (missing.isNotEmpty) 'not_found': missing,
        };
      case 'move' || 'rename':
        if (found.length > 1) {
          throw VesperToolError('Several rows match: '
              '${found.map(label).join('; ')}. Give source or type.');
        }
        final (t, row) = found.single;
        if (action == 'rename') {
          await hub.renameRow(row.key, _str(args, 'name'));
          return {'renamed': label(found.single), 'to': _str(args, 'name')};
        }
        final keys = [
          for (final r in hub.rows(t, includeHidden: true))
            if (!r.isSearch && r.continuations == null) r.key
        ];
        final from = keys.indexOf(row.key);
        if (from < 0) {
          throw VesperToolError('${_hubRowName(row)} stays where it is.');
        }
        final steps = switch (_str(args, 'to')) {
          'top' => -from,
          'bottom' => keys.length - 1 - from,
          'up' => -1,
          'down' => 1,
          _ => throw VesperToolError('to: top, bottom, up or down.'),
        };
        // moveRow takes one step at a time (it re-reads the order).
        for (var i = 0; i < steps.abs(); i++) {
          await hub.moveRow(t, row.key, steps.sign);
        }
        return {'moved': label(found.single), 'to': _str(args, 'to')};
    }
    throw VesperToolError('Unknown hub_rows action $action.');
  },
);
