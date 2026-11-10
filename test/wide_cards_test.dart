import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/wide_art_queue.dart';
import 'package:nox_iptv/widgets/poster_card.dart';

void main() {
  group('WideArtQueue', () {
    test('runs two at a time, newest first, and never re-asks a miss',
        () async {
      final queue = WideArtQueue.instance;
      final gates = <String, Completer<String?>>{};
      final started = <String>[];
      Future<String?> Function() loader(String id) => () {
            started.add(id);
            return (gates[id] = Completer<String?>()).future;
          };
      final a = queue.request('qa', loader('qa'))!;
      final b = queue.request('qb', loader('qb'))!;
      final c = queue.request('qc', loader('qc'))!;
      final d = queue.request('qd', loader('qd'))!;
      await Future<void>.delayed(Duration.zero);
      expect(started, ['qa', 'qb']);
      gates['qa']!.complete('http://x/a.jpg');
      await a;
      await Future<void>.delayed(Duration.zero);
      // The latest card on screen goes next.
      expect(started, ['qa', 'qb', 'qd']);
      gates['qb']!.complete(null);
      expect(await b, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(started.last, 'qc');
      gates['qc']!.complete('http://x/c.jpg');
      gates['qd']!.complete('http://x/d.jpg');
      expect(await c, 'http://x/c.jpg');
      expect(await d, 'http://x/d.jpg');
      // qb had no backdrop: asked once per session only.
      expect(queue.request('qb', loader('qb')), isNull);
    });

    test('a card leaving before its turn cancels it', () async {
      final queue = WideArtQueue.instance;
      final hold = [Completer<String?>(), Completer<String?>()];
      var n = 0;
      queue.request('ca', () => hold[n++].future);
      queue.request('cb', () => hold[n++].future);
      var ran = false;
      final waiting = queue.request('cc', () async {
        ran = true;
        return 'http://x/c.jpg';
      })!;
      queue.cancel('cc');
      expect(await waiting, isNull);
      hold[0].complete(null);
      hold[1].complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(ran, isFalse);
    });
  });

  group('PosterCard wide style', () {
    Widget card({String? backdrop, required Future<String?> Function() load,
            String key = 'k1'}) =>
        MaterialApp(
          home: Scaffold(
            body: PosterCard(
              title: 'Dune',
              imageUrl: null,
              onTap: () {},
              onFocusGained: () {},
              cardWidth: PosterCard.posterHeight * 16 / 9,
              wideStyle: true,
              backdropUrl: backdrop,
              artKey: key,
              loadBackdrop: load,
            ),
          ),
        );

    testWidgets('asks for a backdrop after the dwell, not before',
        (tester) async {
      var asked = 0;
      await tester.pumpWidget(card(
          key: 'w1',
          load: () async {
            asked++;
            return null;
          }));
      await tester.pump(const Duration(milliseconds: 200));
      expect(asked, 0);
      await tester.pump(WideArtQueue.dwell);
      expect(asked, 1);
    });

    testWidgets('a card that has its backdrop never asks', (tester) async {
      var asked = 0;
      await tester.pumpWidget(card(
          key: 'w2',
          backdrop: 'http://x/b.jpg',
          load: () async {
            asked++;
            return null;
          }));
      await tester.pump(WideArtQueue.dwell * 2);
      expect(asked, 0);
    });

    testWidgets('scrolled away before the dwell: no request', (tester) async {
      var asked = 0;
      await tester.pumpWidget(card(
          key: 'w3',
          load: () async {
            asked++;
            return null;
          }));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(WideArtQueue.dwell * 2);
      expect(asked, 0);
    });
  });
}
