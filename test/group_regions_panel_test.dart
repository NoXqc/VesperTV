import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/m3u_group.dart';
import 'package:nox_iptv/screens/settings/group_regions_panel.dart';

/// Group Management > Countries: one row per country, switching all its
/// groups; the rows follow the groups' state while the panel is open.
class _Groups extends ChangeNotifier {
  final titles = [
    'US: News',
    'US| Sports',
    'AM | US - Kids',
    'AM | CA - Sports',
    'CA: News',
    'Sports',
  ];
  final hidden = <String>{'CA: News'};
  final calls = <(List<String>, bool)>[];

  List<M3uGroup> groups() => [
        for (final t in titles)
          M3uGroup(
              title: t,
              playlistId: 'p',
              channels: const [],
              isHidden: hidden.contains(t)),
      ];

  Future<void> setHidden(List<String> titles, bool hide) async {
    calls.add((titles, hide));
    hide ? hidden.addAll(titles) : hidden.removeAll(titles);
    notifyListeners();
  }
}

void main() {
  late _Groups model;

  Future<void> open(WidgetTester tester) async {
    model = _Groups();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showGroupRegions(context,
              listenable: model,
              groups: model.groups,
              setHidden: model.setHidden),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Icon stateOf(WidgetTester tester, String key) => tester.widget<Icon>(find
      .descendant(
          of: find.byKey(ValueKey('region:$key')), matching: find.byType(Icon))
      .last);

  testWidgets('lists each country once with its spellings', (tester) async {
    await open(tester);
    expect(find.text('US'), findsOneWidget);
    expect(find.text('CA'), findsOneWidget);
    expect(find.text('Groups without a country'), findsOneWidget);
    expect(find.textContaining('3 groups · US: · US| · AM | US -'),
        findsOneWidget);
    expect(find.textContaining('1 of 2 shown'), findsOneWidget,
        reason: 'CA: News is hidden');
    expect(stateOf(tester, 'US').icon, Icons.check_circle);
    expect(stateOf(tester, 'CA').icon, Icons.remove_circle_outline);
  });

  testWidgets('a tap hides a fully shown country, shows a partial one',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('US'));
    await tester.pumpAndSettle();
    expect(model.calls.last.$1, ['US: News', 'US| Sports', 'AM | US - Kids']);
    expect(model.calls.last.$2, isTrue);
    expect(stateOf(tester, 'US').icon, Icons.circle_outlined);
    await tester.tap(find.text('CA'));
    await tester.pumpAndSettle();
    expect(model.calls.last.$1, ['AM | CA - Sports', 'CA: News']);
    expect(model.calls.last.$2, isFalse);
    expect(stateOf(tester, 'CA').icon, Icons.check_circle);
    expect(model.hidden, {'US: News', 'US| Sports', 'AM | US - Kids'});
  });

  testWidgets('the remote starts on the first country and OK switches it',
      (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.calls.single.$2, isTrue);
    expect(model.calls.single.$1, hasLength(3));
  });
}
