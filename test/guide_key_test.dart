import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/guide_key.dart';

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> implements GuideTarget {
  int opened = 0;

  @override
  ModalRoute<dynamic>? get guideRoute =>
      mounted ? ModalRoute.of(context) : null;

  @override
  void openGuide() => setState(() => opened++);

  @override
  void initState() {
    super.initState();
    GuideKey.register(this);
  }

  @override
  void dispose() {
    GuideKey.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('home $opened');
}

const _guideDown = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.programGuide,
    logicalKey: LogicalKeyboardKey.guide,
    timeStamp: Duration.zero);

void main() {
  final navKey = GlobalKey<NavigatorState>();
  bool handler(KeyEvent e) =>
      GuideKey.handle(e, navigator: navKey.currentState);

  // The key simulator can't synthesize a Guide key on the test host; the
  // app's HardwareKeyboard handler is exactly this call.
  Future<void> pressGuide(WidgetTester tester) async {
    expect(handler(_guideDown), isTrue);
    await tester.pump();
  }

  testWidgets('Guide closes the pages above the TV home and opens its guide',
      (tester) async {
    await tester
        .pumpWidget(MaterialApp(navigatorKey: navKey, home: const _Home()));
    navKey.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Text('settings')));
    await tester.pumpAndSettle();
    navKey.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Text('player')));
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
    await pressGuide(tester);
    await tester.pumpAndSettle();
    expect(find.text('player'), findsNothing);
    expect(find.text('settings'), findsNothing);
    expect(find.text('home 1'), findsOneWidget);
  });

  testWidgets(
      'no TV home (Sports Mode root): the opener opens one on its guide',
      (tester) async {
    final owner = Object();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navKey, home: const Text('sports')));
    GuideKey.registerOpener(owner, () {
      GuideKey.openGuideOnNextHome();
      navKey.currentState!
          .push(MaterialPageRoute<void>(builder: (_) => const _Home()));
    });
    addTearDown(() => GuideKey.unregisterOpener(owner));
    await pressGuide(tester);
    await tester.pumpAndSettle();
    expect(find.text('home 1'), findsOneWidget);
  });

  test('the Formuler EPG key counts as Guide (on-screen probe values)', () {
    const formuler = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey(0x110000016a),
        logicalKey: LogicalKeyboardKey(0x11000000e4),
        timeStamp: Duration.zero);
    expect(GuideKey.isGuide(formuler), isTrue);
    expect(GuideKey.isGuide(_guideDown), isTrue);
    const ok = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.select,
        logicalKey: LogicalKeyboardKey.select,
        timeStamp: Duration.zero);
    expect(GuideKey.isGuide(ok), isFalse);
  });

  testWidgets('ignored while the splash / profile selector shows',
      (tester) async {
    expect(GuideKey.handle(_guideDown, navigator: null), isFalse);
  });
}
