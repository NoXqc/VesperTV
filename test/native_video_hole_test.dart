import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/native_video_hole.dart';

void main() {
  late List<MethodCall> calls;
  late GlobalKey<NavigatorState> navigator;
  var nextPlayer = 1;
  late int player;
  setUp(() {
    calls = [];
    player = nextPlayer++;
    navigator = GlobalKey<NavigatorState>();
    NativeVideoSurface.active = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('vespertv/native_surface'), (call) async {
      calls.add(call);
      return <String, Object?>{};
    });
  });
  tearDown(() {
    NativeVideoSurface.active = false;
  });

  Widget hole(int id) => Center(
      child: SizedBox(
          width: 240, height: 135, child: NativeVideoHole(playerId: id)));
  Future<void> mount(WidgetTester tester, {Widget? home}) async {
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator, home: home ?? Scaffold(body: hole(player))));
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
      'player switch keeps output in place until replacement is laid out',
      (tester) async {
    final shown = ValueNotifier<int?>(player);
    addTearDown(shown.dispose);
    await mount(tester,
        home: Scaffold(
            body: ValueListenableBuilder<int?>(
                valueListenable: shown,
                builder: (_, id, __) =>
                    id == null ? const SizedBox() : hole(id))));
    final release = NativeVideoSurface.retainForPlayerSwitch();
    addTearDown(release);
    shown.value = null;
    await tester.pump();
    expect(calls.where((c) => c.method == 'hide'), isEmpty);
    shown.value = nextPlayer++;
    await tester.pump();
    release();
    await tester.pump();
    expect(calls.where((c) => c.method == 'hide'), isEmpty);
    expect(calls.where((c) => c.method == 'attach'), hasLength(2));
    await finish(tester);
    expect(calls.last.method, 'hide');
  });

  testWidgets('cancelled and overlapping switch holds release safely',
      (tester) async {
    await mount(tester);
    final first = NativeVideoSurface.retainForPlayerSwitch();
    final second = NativeVideoSurface.retainForPlayerSwitch();
    addTearDown(first);
    addTearDown(second);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    first();
    first();
    await tester.pump();
    expect(calls.where((c) => c.method == 'hide'), isEmpty);
    second();
    await tester.pump();
    expect(calls.last.method, 'hide');
  });

  testWidgets('Settings coverage and pop keep native surface in place',
      (tester) async {
    await mount(tester);
    final before = calls.lastWhere((c) => c.method == 'setRect').arguments;
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Settings'))));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'hide'), isEmpty);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls.where((c) => c.method == 'hide'), isEmpty);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'attach'), hasLength(1));
    expect(calls.lastWhere((c) => c.method == 'setRect').arguments, before);
    await finish(tester);
    expect(calls.last.method, 'hide');
  });

  testWidgets('translucent covering route does not hide the preview',
      (tester) async {
    await mount(tester);
    navigator.currentState!.push(PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            const Center(child: Text('Floating window'))));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'hide'), isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'hide'), isEmpty);
    await finish(tester);
  });

  testWidgets('explicit hidden TickerMode still hides and restores video',
      (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await mount(tester,
        home: Scaffold(
            body: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (_, on, __) =>
                    TickerMode(enabled: on, child: hole(player)))));
    visible.value = false;
    await tester.pump();
    expect(calls.where((c) => c.method == 'hide'), hasLength(1));
    visible.value = true;
    await tester.pump();
    expect(calls.last.method, 'setRect');
    await finish(tester);
  });

  testWidgets('fullscreen hole wins and returning reattaches the preview',
      (tester) async {
    await mount(tester);
    final fullscreen = nextPlayer++;
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: hole(fullscreen))));
    await tester.pumpAndSettle();
    expect(
        (calls.lastWhere((c) => c.method == 'attach').arguments
            as Map)['playerId'],
        fullscreen);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(
        (calls.lastWhere((c) => c.method == 'attach').arguments
            as Map)['playerId'],
        player);
    expect(calls.where((c) => c.method == 'hide'), isEmpty);
    await finish(tester);
  });

  testWidgets(
      'browse tab removes picture and returns without reattaching player',
      (tester) async {
    final browsing = ValueNotifier(false);
    addTearDown(browsing.dispose);
    await mount(tester,
        home: Scaffold(
            body: ValueListenableBuilder<bool>(
                valueListenable: browsing,
                builder: (_, browse, __) =>
                    browse ? const Text('Movies / TV Shows') : hole(player))));
    final before = calls.lastWhere((c) => c.method == 'setRect').arguments;
    browsing.value = true;
    await tester.pump();
    expect(calls.last.method, 'hide');
    browsing.value = false;
    await tester.pump();
    expect(calls.last.method, 'setRect');
    expect(calls.last.arguments, before);
    expect(calls.where((c) => c.method == 'attach'), hasLength(1));
    await finish(tester);
  });
}
