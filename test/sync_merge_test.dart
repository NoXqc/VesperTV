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
}
