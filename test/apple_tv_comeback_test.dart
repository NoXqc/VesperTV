import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/apple_tv_comeback.dart';

void main() {
  void go(WidgetTester tester, List<AppLifecycleState> states) {
    for (final s in states) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  const toHome = [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  const back = [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];

  testWidgets('the Home screen and back: one call', (tester) async {
    final calls = <Duration>[];
    final listener = AppleTvComeback.listen(calls.add, enabled: true)!;
    addTearDown(listener.dispose);
    go(tester, toHome);
    expect(calls, isEmpty);
    go(tester, back);
    expect(calls, hasLength(1));
    // Each return counts once.
    go(tester, toHome);
    go(tester, back);
    expect(calls, hasLength(2));
  });

  testWidgets('Control Center over the app (inactive only): nothing',
      (tester) async {
    final calls = <Duration>[];
    final listener = AppleTvComeback.listen(calls.add, enabled: true)!;
    addTearDown(listener.dispose);
    go(tester, const [AppLifecycleState.inactive, AppLifecycleState.resumed]);
    expect(calls, isEmpty);
  });

  test('off Apple TV: no listener', () {
    expect(AppleTvComeback.listen((_) {}, enabled: false), isNull);
  });
}
