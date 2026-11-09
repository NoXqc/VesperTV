import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/settings_scaffold.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';

Widget _page() => MaterialApp(
      theme: ThemeData.dark(),
      home: SettingsScaffold(
        title: 'Settings',
        body: ListView(children: [
          TvMenuTile(
              icon: Icons.tune,
              title: 'Audio',
              subtitle: 'Audio languages, subtitles and surround sound',
              onTap: () {}),
          SwitchListTile(
              value: true, title: const Text('A switch'), onChanged: (_) {}),
        ]),
      ),
    );

void main() {
  testWidgets('a computer (and a TV box) gets compact Settings rows',
      (tester) async {
    await tester.pumpWidget(_page());
    final phone = tester.getSize(find.byType(TvMenuTile)).height;
    expect(find.byType(CompactMenus), findsNothing);

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_page());
    expect(find.byType(CompactMenus), findsOneWidget);
    final compact = tester.getSize(find.byType(TvMenuTile)).height;
    expect(compact, lessThan(phone));
    expect(tester.getSize(find.byType(CircleAvatar)).height, 30);
    debugDefaultTargetPlatformOverride = null;
  });
}
