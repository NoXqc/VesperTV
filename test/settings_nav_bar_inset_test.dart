import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/settings_scaffold.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';

/// Android 15 draws apps behind the navigation bar: a Settings list with
/// its own padding must still scroll its last row above the bar (user
/// photo, Settings > Playback > Resume reminder under Back/Home).
void main() {
  testWidgets('the last Settings row scrolls clear of the navigation bar',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 2.25;
    // 3-button navigation bar, 48 dp.
    tester.view.padding = const FakeViewPadding(top: 90, bottom: 108);
    tester.view.viewPadding = const FakeViewPadding(top: 90, bottom: 108);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: SettingsScaffold(
        title: 'Playback',
        body: ListView(
          padding: const EdgeInsets.only(top: 8),
          children: [
            for (var i = 0; i < 14; i++)
              TvMenuTile(
                  icon: Icons.tune,
                  title: i == 13 ? 'Resume reminder' : 'Row $i',
                  subtitle: 'Subtitle',
                  onTap: () {}),
          ],
        ),
      ),
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final bar = 108 / tester.view.devicePixelRatio;
    final last = tester.getRect(find.text('Resume reminder'));
    expect(last.bottom, lessThanOrEqualTo(screen.height - bar));
  });
}
