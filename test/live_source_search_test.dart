import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/live_source_drawer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Channel _c(String playlist, int i, String name) => Channel(
    id: '$playlist::$i',
    rawId: '$i',
    playlistId: playlist,
    name: name,
    group: 'Group $playlist',
    url: 'https://$playlist/$i');

final _pool = [
  for (var i = 0; i < 400; i++) _c('p', i, 'Channel $i'),
  _c('q', 1, 'CA: TSN 1 HD'),
  _c('q', 2, 'TSN1 FHD'),
  _c('q', 3, 'CA: TSN 1 4K'), // already a source: skipped
];

/// Player > Sources > Add another source (owner, 2026-11-16: Sports Trak's
/// picker felt slow, and keys pressed while it opened changed the channel).
void main() {
  late AppPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
  });

  Future<List<Channel?>> open(WidgetTester tester,
      {String suggest = ''}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final result = <Channel?>[];
    await tester.pumpWidget(ChangeNotifierProvider<AppPreferences>.value(
      value: prefs,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(await showLiveSourceSearch(
                context,
                title: 'Another source for CA: TSN 1 4K',
                channels: _pool,
                describe: (c) => c.group,
                suggest: suggest,
                skipUrls: {'https://q/3'})),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('starts on the suggestions; OK adds the focused one',
      (tester) async {
    final result = await open(tester, suggest: 'TSN');
    expect(find.text('CA: TSN 1 HD'), findsOneWidget);
    expect(find.text('TSN1 FHD'), findsOneWidget);
    expect(find.text('CA: TSN 1 4K'), findsNothing);
    expect(find.text('Channel 1'), findsNothing);
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'live-source-results');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result.single?.name, 'TSN1 FHD');
  });

  testWidgets('typing searches every channel, 150 rows at most; Back closes',
      (tester) async {
    final result = await open(tester);
    expect(find.text('Type a channel name.'), findsOneWidget);
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'live-source-search');
    await tester.sendKeyEvent(LogicalKeyboardKey.select); // opens typing
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'channel');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Showing the first 150. Type more to narrow it down.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'channel 39');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Showing the first'), findsNothing);
    expect(find.text('Channel 39'), findsOneWidget);
    // The keyboard's Search key goes to the list, Up back, Down again,
    // Back closes.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'live-source-results');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'live-source-search');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(result, [null]);
    expect(find.byKey(const ValueKey('live-source-search')), findsNothing);
  });
}
