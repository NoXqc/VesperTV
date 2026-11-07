import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/playlist_edits.dart';
import 'package:nox_iptv/services/playlist_edits_diff.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';

Channel ch(String raw, String name) => Channel(
    id: 'p1::$raw',
    rawId: raw,
    playlistId: 'p1',
    name: name,
    group: 'SPORTS',
    url: 'http://x/$raw.ts');

PlaylistEdits copy(PlaylistEdits e) => PlaylistEdits.fromJson(e.toJson());

void main() {
  group('undo (EditsDiff)', () {
    test('takes back exactly what one change did', () {
      final before = PlaylistEdits(
        hidden: {'a'},
        names: {'x': 'Old'},
        rules: [EditRule(type: 'hide', find: 'XXX')],
      );
      final after = copy(before)
        ..hidden.addAll({'b', 'c'})
        ..names['x'] = 'New'
        ..names['y'] = 'Added'
        ..rules.add(EditRule(type: 'replace', find: 'CA: '))
        ..fallbacks['b'] = ['p2::z']
        ..hideLowerCopies = true;
      final diff = EditsDiff.between(before, after);
      expect(diff.isEmpty, isFalse);
      final (undone, kept) = diff.revert(after);
      expect(kept, 0);
      expect(undone.toJson(), before.toJson());
    });

    test('leaves alone what was changed again since', () {
      final before = PlaylistEdits();
      final after = copy(before)
        ..names['x'] = 'AI name'
        ..hidden.add('h')
        ..rules.add(EditRule(type: 'replace', find: 'CA: '));
      final diff = EditsDiff.between(before, after);
      // The viewer then renamed x again by hand and added a rule.
      final later = copy(after)
        ..names['x'] = 'Viewer name'
        ..rules.add(EditRule(type: 'hide', find: 'Adult'));
      final (undone, kept) = diff.revert(later);
      expect(kept, 1);
      expect(undone.names['x'], 'Viewer name');
      expect(undone.hidden, isEmpty);
      expect([for (final r in undone.rules) r.find], ['Adult']);
    });

    test('a rule removed by the change comes back', () {
      final before =
          PlaylistEdits(rules: [EditRule(type: 'hide', find: 'Adult')]);
      final after = copy(before)..rules.clear();
      final (undone, _) = EditsDiff.between(before, after).revert(after);
      expect([for (final r in undone.rules) r.find], ['Adult']);
    });

    test('stream test results are not part of a change', () {
      final before = PlaylistEdits();
      final after = copy(before);
      after.probes['a'] = PlaylistEdits.fromJson({
        'probes': {
          'a': {'ok': false, 'at': 1}
        }
      }).probes['a']!;
      expect(EditsDiff.between(before, after).isEmpty, isTrue);
    });

    test('the log survives a restart and finds changes by id', () {
      final log = AiEditLog();
      final d = EditsDiff.between(
          PlaylistEdits(), PlaylistEdits(hidden: {'a'}, names: {'b': 'B'}));
      final c1 = log.add('hide a', {'p1': d});
      final c2 = log.add('rename b', {'p1': d});
      final back = AiEditLog.decode(log.encode());
      expect(back.find(null)!.id, c2.id);
      expect(back.find(c1.id)!.summary, 'hide a');
      final (undone, _) = back.find(c1.id)!.diffs['p1']!.revert(PlaylistEdits(
            hidden: {'a'},
            names: {'b': 'B'},
          ));
      expect(undone.isEmpty, isTrue);
      expect(back.add('next', {}).id, isNot(anyOf(c1.id, c2.id)));
    });

    test('the log keeps the latest changes only', () {
      final log = AiEditLog();
      for (var i = 0; i < AiEditLog.max + 5; i++) {
        log.add('change $i', {});
      }
      expect(log.changes.length, AiEditLog.max);
      expect(log.changes.last.summary, 'change ${AiEditLog.max + 4}');
    });

    test('a broken saved log reads as empty', () {
      expect(AiEditLog.decode('{nope').changes, isEmpty);
      expect(AiEditLog.decode('{"c":[{"id":1}]}').changes, isEmpty);
    });
  });

  group('help manual', () {
    final tool = vesperTools.firstWhere((t) => t.name == 'playlist_editor');
    final manual = vesperHelpTopics['playlist_editor']!;

    test('names every action the tool offers', () {
      final actions =
          ((tool.schema['properties'] as Map)['action'] as Map)['enum'] as List;
      for (final a in actions) {
        expect(manual, contains('- $a'), reason: a as String);
      }
    });

    test('the help tool lists every topic', () {
      final help = vesperTools.firstWhere((t) => t.name == 'vesper_help');
      final topics =
          ((help.schema['properties'] as Map)['topic'] as Map)['enum'];
      expect(topics, vesperHelpTopics.keys.toList());
    });

    test('the CA affix example strips affixes and nothing else', () {
      const pattern = r'^\s*CA\s*[:|\-]+\s*|\s*[\[(]\s*CA\s*[\])]|\s+CA\s*$';
      expect(manual, contains(pattern));
      final e = PlaylistEdits(rules: [
        EditRule(type: 'replace', find: pattern, regex: true),
      ]);
      final cases = {
        'CA: TSN 1': 'TSN 1',
        'CA | Sportsnet One': 'Sportsnet One',
        'ca- RDS': 'RDS',
        'TSN 2 (CA)': 'TSN 2',
        'TSN 3 [CA]': 'TSN 3',
        'CTV CA': 'CTV',
        'CANAL+ SPORT': 'CANAL+ SPORT',
        'CARTOON NETWORK': 'CARTOON NETWORK',
        'TSN CANADA': 'TSN CANADA',
        'AFRICA 24': 'AFRICA 24',
      };
      final channels = [
        for (final (i, name) in cases.keys.indexed) ch('$i', name)
      ];
      e.apply(channels);
      for (final c in channels) {
        expect(c.name, cases[c.sourceName], reason: c.sourceName);
      }
    });
  });
}
