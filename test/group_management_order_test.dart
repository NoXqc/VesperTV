import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/m3u_group.dart';
import 'package:nox_iptv/screens/settings/group_management_screen.dart';
import 'package:nox_iptv/utils/title_search.dart';

/// Group management lists shown groups first and can list only the shown
/// or only the hidden ones (Discord, 2026-11-18).
void main() {
  final groups = [
    for (final (t, h) in [
      ('AR | News', true),
      ('UK | News', false),
      ('AR | Sports', true),
      ('UK | Sports', false),
      ('Kids', false),
    ])
      M3uGroup(title: t, playlistId: 'p', channels: const [], isHidden: h)
  ];

  test('shown groups first, hidden after, each in playlist order', () {
    expect(shownFirst(groups, search: TitleSearch(''), view: GroupView.all), [
      'UK | News',
      'UK | Sports',
      'Kids',
      'AR | News',
      'AR | Sports',
    ]);
  });

  test('Shown / Hidden views and a search', () {
    expect(shownFirst(groups, search: TitleSearch(''), view: GroupView.hidden),
        ['AR | News', 'AR | Sports']);
    expect(shownFirst(groups, search: TitleSearch(''), view: GroupView.shown),
        ['UK | News', 'UK | Sports', 'Kids']);
    expect(shownFirst(groups, search: TitleSearch('news'), view: GroupView.all),
        ['UK | News', 'AR | News']);
  });
}
