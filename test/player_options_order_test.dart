import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/player_options_order.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The TV player's options row in the viewer's own order: hold OK on a tile,
/// Left / Right move it, OK or Back is done (Reddit + owner, 2026-11-21).
void main() {
  group('arrange / merge', () {
    String id(String s) => s;

    test('saved order first; new ids stay after their default neighbour', () {
      expect(
          PlayerOptionsOrder.arrange(
              ['a', 'b', 'new', 'c'], id, ['c', 'a', 'b']),
          ['c', 'a', 'b', 'new']);
      expect(PlayerOptionsOrder.arrange(['a', 'b', 'c'], id, const []),
          ['a', 'b', 'c']);
    });

    test('a tile not on screen keeps its place in the saved order', () {
      // "start_over" only shows on catch-up channels.
      expect(
          PlayerOptionsOrder.merge(
              ['reload', 'recall'], ['recall', 'start_over', 'reload']),
          ['reload', 'recall', 'start_over']);
    });
  });

  group('move mode', () {
    late StorageService storage;
    late Map<String, int> pressed;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      pressed = {};
      PlayerOptionsOrder.endMove();
    });

    Widget tile(String id) => InkWell(
          onTap: () => pressed[id] = (pressed[id] ?? 0) + 1,
          child: SizedBox(width: 60, height: 40, child: Text(id)),
        );

    Future<void> pump(WidgetTester tester) =>
        tester.pumpWidget(Provider<StorageService>.value(
            value: storage,
            child: MaterialApp(
                home: Scaffold(
                    body: Center(
                        child: ReorderableOptionTiles(tiles: [
              for (final id in ['A', 'B', 'C']) (id, tile(id)),
            ]))))));

    Future<void> focus(WidgetTester tester, String id) async {
      Focus.of(tester.element(find.text(id))).requestFocus();
      await tester.pump();
    }

    Future<void> hold(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();
    }

    double x(WidgetTester tester, String id) =>
        tester.getTopLeft(find.text(id)).dx;

    testWidgets('a short OK still presses the tile', (tester) async {
      await pump(tester);
      await focus(tester, 'A');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(pressed['A'], 1);
      expect(PlayerOptionsOrder.isMoving, isFalse);
    });

    testWidgets('hold OK, Right moves the tile and saves; OK ends',
        (tester) async {
      await pump(tester);
      await focus(tester, 'A');
      await hold(tester);
      expect(PlayerOptionsOrder.moving.value, 'A');
      expect(pressed['A'], isNull, reason: 'a hold never presses the tile');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(x(tester, 'A'), greaterThan(x(tester, 'B')));
      expect(storage.getPlayerOptionsOrder(), ['B', 'A', 'C']);
      expect(Focus.of(tester.element(find.text('A'))).hasPrimaryFocus, isTrue,
          reason: 'the moved tile keeps the focus');

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(PlayerOptionsOrder.isMoving, isFalse);
      expect(pressed['A'], isNull, reason: 'OK ends the move only');

      // The saved order comes back next time.
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(x(tester, 'A'), greaterThan(x(tester, 'B')));
    });

    testWidgets('Back ends the move', (tester) async {
      await pump(tester);
      await focus(tester, 'B');
      await hold(tester);
      expect(PlayerOptionsOrder.moving.value, 'B');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(PlayerOptionsOrder.isMoving, isFalse);
    });
  });
}
