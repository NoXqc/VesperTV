import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/title_hold_menu.dart';

void main() {
  /// Opens the menu; the returned future completes when it closes.
  Future<Future<TitleHoldAction?>> open(WidgetTester tester,
      {required bool isFavorite, bool? watched}) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final result = showTitleHoldMenu(ctx,
        title: 'Title', isFavorite: isFavorite, watched: watched);
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('unwatched movie: favourite + mark as watched', (tester) async {
    final result = await open(tester, isFavorite: false, watched: false);
    expect(find.text('Add to Favourites'), findsOneWidget);
    expect(find.text('Mark as watched'), findsOneWidget);
    expect(find.text('Mark as unwatched'), findsNothing);
    await tap(tester, 'Mark as watched');
    expect(await result, TitleHoldAction.watched);
  });

  testWidgets('watched favourite movie: remove + mark as unwatched',
      (tester) async {
    final result = await open(tester, isFavorite: true, watched: true);
    expect(find.text('Remove from Favourites'), findsOneWidget);
    expect(find.text('Mark as unwatched'), findsOneWidget);
    expect(find.text('Mark as watched'), findsNothing);
    await tap(tester, 'Remove from Favourites');
    expect(await result, TitleHoldAction.favorite);
  });

  testWidgets('show: both episode marks, Cancel returns nothing',
      (tester) async {
    final result = await open(tester, isFavorite: false);
    expect(find.text('Mark every episode watched'), findsOneWidget);
    expect(find.text('Mark every episode unwatched'), findsOneWidget);
    await tap(tester, 'Cancel');
    expect(await result, isNull);
  });
}
