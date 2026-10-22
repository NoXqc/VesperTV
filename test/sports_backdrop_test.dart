import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/widgets/sports_widgets.dart';

/// Sports banners (user request): the picked league's / team's logo behind
/// the page, or the sport's icon when there is no logo.
void main() {
  test('each sport gets its own icon', () {
    IconData icon(String id) => SportsBackdrop.sportIcon(sportsLeagueById(id));
    expect(icon('nhl'), Icons.sports_hockey);
    expect(icon('nba'), Icons.sports_basketball);
    expect(icon('nfl'), Icons.sports_football);
    expect(icon('mlb'), Icons.sports_baseball);
    expect(icon('racing.f1'), Icons.sports_motorsports);
    expect(SportsBackdrop.sportIcon(null), Icons.sports);
  });

  testWidgets('nothing for "All"; the sport icon without a logo',
      (tester) async {
    Widget host(Widget child) =>
        MaterialApp(home: SizedBox(width: 800, height: 450, child: child));

    await tester.pumpWidget(host(const SportsBackdrop()));
    expect(find.byType(Icon), findsNothing);

    await tester
        .pumpWidget(host(SportsBackdrop(league: sportsLeagueById('nhl'))));
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.sports_hockey);
  });
}
