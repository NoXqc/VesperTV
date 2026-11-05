import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/refined_finish.dart';
import 'package:nox_iptv/utils/tv_theme.dart';
import 'package:nox_iptv/widgets/glass_menu.dart';
import 'package:nox_iptv/widgets/hold_to_activate.dart';
import 'package:nox_iptv/widgets/roll_down_menu.dart';
import 'package:nox_iptv/widgets/tv_dialog_option.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppPreferences prefs;
  late GlobalKey capture;

  setUpAll(() async {
    for (final entry in {
      'Roboto': Platform.environment['GLASS_MENU_PREVIEW_FONT'],
      'MaterialIcons': Platform.environment['GLASS_MENU_PREVIEW_ICONS'],
    }.entries) {
      if (entry.value == null) continue;
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(
            ByteData.sublistView(await File(entry.value!).readAsBytes())));
      await loader.load();
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    capture = GlobalKey();
  });
  tearDown(() => prefs.dispose());

  Future<BuildContext> scene(WidgetTester tester, Size size,
      {bool light = false,
      bool rtl = false,
      double scale = 1,
      Widget? button}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    prefs.isTelevision = size.width > 600;
    final theme = ThemeData(
        colorScheme: buildPaletteColorScheme(
            prefs.palette, light ? Brightness.light : Brightness.dark),
        useMaterial3: true);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: prefs,
      child: RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) => Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!)),
          home: Scaffold(
            body: Stack(fit: StackFit.expand, children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF184D66),
                      Color(0xFF27213D),
                      Color(0xFF715225)
                    ],
                  ),
                ),
              ),
              const Positioned(
                  left: 20,
                  top: 32,
                  child: Text('VesperTV',
                      style: TextStyle(color: Colors.white54, fontSize: 28))),
              Center(child: button ?? const SizedBox()),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.element(find.byType(Scaffold));
  }

  Future<void> preview(WidgetTester tester, String name) async {
    final dir = Platform.environment['GLASS_MENU_PREVIEW_DIR'];
    if (dir == null) return;
    final boundary =
        capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File('$dir/$name.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final light in [false, true]) {
    testWidgets(
        'glass rows stay readable and retain focus when finish changes; light=$light',
        (tester) async {
      final context = await scene(tester, const Size(960, 640), light: light);
      var refined = true;
      late StateSetter update;
      final base = Theme.of(context);
      final result = showGlassMenu<String>(
          context: context,
          builder: (dialog) => StatefulBuilder(builder: (_, setState) {
                update = setState;
                return Theme(
                    data: RefinedFinish.apply(base, refined),
                    child: GlassMenuDialog(
                      title: const Text('Channel options'),
                      children: [
                        TvMenuTile(
                            key: const ValueKey('first'),
                            autofocus: true,
                            icon: Icons.star_outline,
                            title: 'Add to Favourites',
                            subtitle: 'Keep this channel in your favourites',
                            onTap: () => Navigator.pop(dialog, 'favorite')),
                        TvMenuTile(
                            icon: Icons.visibility_off_outlined,
                            title: 'Hide this channel',
                            onTap: () => Navigator.pop(dialog, 'hide')),
                        TvMenuTile(
                            icon: Icons.swap_vert,
                            title: 'Move Up / Down',
                            onTap: () {}),
                        TvDialogOption(
                            onPressed: () => Navigator.pop(dialog),
                            child: const Text('Cancel')),
                      ],
                    ));
              }));
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('first'));
      final state = tester.state(first);
      final focus = FocusManager.instance.primaryFocus;
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(Theme.of(tester.element(first)).colorScheme.brightness,
          Brightness.dark);
      expect(Theme.of(tester.element(first)).colorScheme.primary, Colors.white,
          reason:
              'Platinum needs a visible selector on the dark glass in either theme');
      expect(Theme.of(tester.element(first)).textTheme.bodyMedium!.color,
          Colors.white);
      update(() => refined = false);
      await tester.pumpAndSettle();
      expect(tester.state(first), same(state));
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(find.byType(BackdropFilter), findsOneWidget);
      if (!light) await preview(tester, 'channel-menu-tv');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(await result, 'favorite');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('selected option and subsequent remote rows scroll into view',
      (tester) async {
    final context = await scene(tester, const Size(360, 640), scale: 1.4);
    final result = showGlassMenu<int>(
        context: context,
        builder: (dialog) => GlassMenuDialog(
              title: const Text(
                  'A long channel name with several words and a programme title'),
              children: [
                for (var i = 0; i < 50; i++)
                  TvDialogOption(
                    autofocus: i == 35,
                    onPressed: () => Navigator.pop(dialog, i),
                    child: Text('Option $i'),
                  )
              ],
            ));
    await tester.pumpAndSettle();
    expect(find.text('Option 35').hitTestable(), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(find.text('Option 38').hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(await result, 38);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hold repeats and release do not activate a new glass menu',
      (tester) async {
    var taps = 0, actions = 0;
    late BuildContext context;
    final button = HoldToActivate(
      onTap: () => taps++,
      onHold: () => showGlassMenu<void>(
          context: context,
          builder: (dialog) => SwallowHeldActivate(
                child:
                    GlassMenuDialog(title: const Text('Hold menu'), children: [
                  TvDialogOption(
                      autofocus: true,
                      onPressed: () {
                        actions++;
                        Navigator.pop(dialog);
                      },
                      child: const Text('Choose')),
                ]),
              )),
      child: TextButton(
          autofocus: true, onPressed: () => taps++, child: const Text('Open')),
    );
    context = await scene(tester, const Size(800, 600), button: button);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Hold menu'), findsOneWidget);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(actions, 0);
    expect(taps, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(actions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final keyboard in [0.0, 180.0]) {
    testWidgets(
        'bottom-anchored menu retains its side action; keyboard=$keyboard',
        (tester) async {
      final context = await scene(tester, const Size(360, 640));
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await tester.pump();
      final result = showRollDownMenu<int>(
        context,
        anchor: const Rect.fromLTWH(270, 580, 50, 30),
        title: 'Multiview options',
        items: [
          for (var i = 0; i < 25; i++)
            RollDownMenuItem(
              value: i,
              icon: Icons.live_tv,
              label: 'Channel $i',
              selected: i == 18,
              action: i == 18
                  ? const RollDownMenuAction(
                      value: 999, icon: Icons.visibility_off, label: 'Hide')
                  : null,
            )
        ],
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(GlassMenuSurface));
      expect(rect.top, greaterThanOrEqualTo(12));
      expect(rect.bottom,
          lessThanOrEqualTo(keyboard == 0 ? 572 : 640 - keyboard - 12));
      expect(rect.right, lessThanOrEqualTo(348));
      expect(find.text('Channel 18').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Hide').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(await result, 999);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('large text, RTL and keyboard insets keep Cancel reachable',
      (tester) async {
    final context =
        await scene(tester, const Size(360, 600), rtl: true, scale: 1.5);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    final result = showGlassMenu<bool>(
        context: context,
        builder: (dialog) => GlassMenuDialog(
              title: const Text(
                  'Remove a source with a very long name from your library?'),
              content: const Text(
                  'Existing source details remain visible while you choose an action.\n\nSaved items are preserved.\n\nMore details follow here.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Remove')),
                TextButton(
                    autofocus: true,
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancel')),
              ],
            ));
    await tester.pumpAndSettle();
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byType(GlassMenuSurface)).bottom,
        lessThanOrEqualTo(420));
    await preview(tester, 'confirmation-phone');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Back dismisses a glass menu with no selected action',
      (tester) async {
    final context = await scene(tester, const Size(800, 600));
    final result = showGlassMenu<int>(
        context: context,
        builder: (_) => const GlassMenuDialog(
              title: Text('Options'),
              children: [Text('Choose an action')],
            ));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await result, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
