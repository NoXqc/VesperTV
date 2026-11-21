import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/sync_merge.dart';

Map<String, Object?> s(String v) => {'t': 's', 'v': v};
Map<String, Object?> i(int v) => {'t': 'i', 'v': v};
Map<String, Object?> l(List<String> v) => {'t': 'l', 'v': v};
Map<String, Object?> ids(List<Map<String, Object?>> v) =>
    {'t': 's', 'v': jsonEncode(v)};

List<Object?> idsOf(Object? tagged) => [
      for (final e in jsonDecode((tagged as Map)['v'] as String) as List)
        (e as Map)['id']
    ];

void main() {
  test('only one side changed: its value wins, removals included', () {
    final base = SyncSnapshot({'a': i(1), 'b': i(1), 'c': i(1)}, const {});
    final remote =
        SyncSnapshot({'a': i(2), 'b': i(1), 'c': i(1)}, const {'a': 50});
    final local = {'a': i(1), 'b': i(3)}; // b edited, c removed here
    final merged = mergeSync(
        base: base,
        local: local,
        remote: remote,
        pending: const {'b': 60, 'c': 60});
    expect(merged.values, {'a': i(2), 'b': i(3)});
    expect(merged.stamps['b'], 60);
  });

  test('both changed a value: the newer stamp wins', () {
    final base = SyncSnapshot({'pos': i(10)}, const {});
    final remote = SyncSnapshot({'pos': i(20)}, const {'pos': 100});
    expect(
        mergeSync(
            base: base,
            local: {'pos': i(30)},
            remote: remote,
            pending: const {'pos': 200}).values['pos'],
        i(30));
    expect(
        mergeSync(
            base: base,
            local: {'pos': i(30)},
            remote: remote,
            pending: const {'pos': 50}).values['pos'],
        i(20));
  });

  test('favourites changed on both devices merge as sets', () {
    final base = SyncSnapshot({
      'fav': l(['a', 'b'])
    }, const {});
    // Other device added c and removed a; this one added d and removed b.
    final remote = SyncSnapshot({
      'fav': l(['b', 'c'])
    }, const {
      'fav': 10
    });
    final merged = mergeSync(
        base: base,
        local: {
          'fav': l(['a', 'd'])
        },
        remote: remote,
        pending: const {'fav': 20});
    expect(merged.values['fav'], l(['c', 'd']));
  });

  test('playlists merge per id; an entry edited here and removed there stays',
      () {
    final p1 = {'id': 'p1', 'name': 'One'};
    final p2 = {'id': 'p2', 'name': 'Two'};
    final p3 = {'id': 'p3', 'name': 'Three'};
    final base = SyncSnapshot({
      'lists': ids([p1, p2])
    }, const {});
    final remote = SyncSnapshot({
      'lists': ids([p1]) // p2 removed on the other device
    }, const {
      'lists': 10
    });
    final merged = mergeSync(
        base: base,
        local: {
          'lists': ids([
            p1,
            {'id': 'p2', 'name': 'Two renamed'},
            p3
          ])
        },
        remote: remote,
        pending: const {'lists': 20});
    expect(idsOf(merged.values['lists']), ['p1', 'p2', 'p3']);
  });

  test('a joining device merges lists in but takes the sync\'s settings', () {
    final remote = SyncSnapshot({
      'fav': l(['a']),
      'theme': s('gold'),
      'lists': ids([
        {'id': 'p1'}
      ]),
    }, const {});
    final merged = mergeSync(
        base: null,
        local: {
          'fav': l(['b']),
          'theme': s('red'),
          'lists': ids([
            {'id': 'p9'}
          ]),
          'only_here': i(7),
        },
        remote: remote,
        pending: const {'theme': 99, 'fav': 99, 'lists': 99, 'only_here': 99});
    expect(merged.values['fav'], l(['a', 'b']));
    expect(merged.values['theme'], s('gold'));
    expect(idsOf(merged.values['lists']), ['p1', 'p9']);
    expect(merged.values['only_here'], i(7));
  });

  test('histories merge newest first: both devices\' new titles lead', () {
    Map<String, Object?> e(String id) => {'id': id, 'name': id};
    final base = SyncSnapshot({
      'h': ids([e('a'), e('b')])
    }, const {});
    // The other device watched y (earlier); this one watched x (later).
    final remote = SyncSnapshot({
      'h': ids([e('y'), e('a'), e('b')])
    }, const {
      'h': 100
    });
    final merged = mergeSync(
        base: base,
        local: {
          'h': ids([e('x'), e('a'), e('b')])
        },
        remote: remote,
        pending: const {'h': 200},
        newestFirst: (k) => k == 'h');
    expect(idsOf(merged.values['h']), ['x', 'y', 'a', 'b']);
  });

  test('Media Hub history entries (no id) merge by source + title', () {
    String entry(String src, String id) =>
        '{"src":"$src","meta":{"id":"$id","name":"$id"}}';
    final base = SyncSnapshot({'arc': s('[${entry('s1', 'tt1')}]')}, const {});
    final remote = SyncSnapshot(
        {'arc': s('[${entry('s1', 'tt2')},${entry('s1', 'tt1')}]')},
        const {'arc': 100});
    final merged = mergeSync(
        base: base,
        local: {'arc': s('[${entry('s2', 'tt9')},${entry('s1', 'tt1')}]')},
        remote: remote,
        pending: const {'arc': 200},
        newestFirst: (k) => k == 'arc');
    final list =
        jsonDecode((merged.values['arc'] as Map)['v'] as String) as List;
    expect([for (final x in list) (x as Map)['meta']['id']],
        ['tt9', 'tt2', 'tt1']);
  });

  test('local changes keep their first stamp until synced', () {
    final base = SyncSnapshot({'a': i(1), 'b': i(1)}, const {});
    var pending = stampLocalChanges(base, {'a': i(2), 'b': i(1)}, {}, 100);
    expect(pending, {'a': 100});
    pending = stampLocalChanges(base, {'a': i(3), 'b': i(2)}, pending, 200);
    expect(pending, {'a': 100, 'b': 200});
    // Changed back: nothing to sync.
    pending = stampLocalChanges(base, {'a': i(1), 'b': i(2)}, pending, 300);
    expect(pending, {'b': 200});
  });

  test('Send log: profile keys stay readable, favourites per playlist', () {
    expect(syncKeyLabel('nox_favorites'), 'nox_favorites');
    final label = syncKeyLabel('nox_favorites__vp_1792590634437724');
    expect(label, 'nox_favorites(profile ..7724)');
    // The log's redaction hides any word of 32+ characters.
    expect(RegExp(r'\b[A-Za-z0-9_\-]{32,}\b').hasMatch(label), isFalse);
    expect(syncListChange(l(['1::a', '1::b', '2::c']), l(['1::a', '3::d'])),
        '3 -> 2 (+1 -2) 1:2->1 2:1->0 3:0->1');
    expect(syncListChange(l(['1::a']), null), '1 -> 0 (+0 -1) 1:1->0');
  });

  group('rebaseHeldEdit on a JSON object (own groups, editor edits)', () {
    Map<String, Object?> obj(Map<String, Object?> v) => s(jsonEncode(v));
    Object? rebased(Object? held, Object? local, Object? merged) =>
        jsonDecode((rebaseHeldEdit(held, local, merged) as Map)['v'] as String);

    test('a new field here goes on top; the others\' fields stay', () {
      final out = rebased(
          null,
          obj({
            'groups': ['Kids'],
            'moves': {'x': 'Kids'}
          }),
          obj({
            'groups': ['Sports'],
            'moves': {'a': 'Sports'},
            'order': {
              'Sports': ['a']
            }
          }));
      expect(out, {
        'groups': ['Sports', 'Kids'],
        'moves': {'a': 'Sports', 'x': 'Kids'},
        'order': {
          'Sports': ['a']
        },
      });
    });

    test('only what the edit removed goes', () {
      final held = obj({
        'groups': ['A', 'B'],
        'moves': {'a': 'A', 'b': 'B'},
        'copies': {
          'c': ['A']
        }
      });
      final local = obj({
        'groups': ['A'],
        'moves': {'a': 'A'},
      }); // B deleted, last copy removed (UserGroups drops the map)
      final merged = obj({
        'groups': ['A', 'B', 'C'],
        'moves': {'a': 'A', 'b': 'B', 'c3': 'C'},
        'copies': {
          'c': ['A'],
          'd': ['C']
        }
      });
      expect(rebased(held, local, merged), {
        'groups': ['A', 'C'],
        'moves': {'a': 'A', 'c3': 'C'},
        'copies': {
          'd': ['C']
        },
      });
    });

    test('a reorder here keeps its order and the others\' additions', () {
      final out = rebased(
          obj({
            'groups': ['A', 'B', 'C']
          }),
          obj({
            'groups': ['C', 'A', 'B']
          }),
          obj({
            'groups': ['A', 'B', 'C', 'D']
          }));
      expect(out, {
        'groups': ['C', 'A', 'B', 'D']
      });
    });

    test('a plain value is still the edit', () {
      expect(rebaseHeldEdit(s('gold'), s('red'), s('blue')), s('red'));
      expect(rebaseHeldEdit(obj({'a': 1}), null, obj({'a': 1, 'b': 2})), null);
    });
  });
}
