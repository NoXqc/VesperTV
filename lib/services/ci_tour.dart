import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/playlist_profile.dart';
import 'storage_service.dart';
import 'vesper_ai/vesper_ai.dart';

/// Apple TV UI tour, for the tvOS workflow only (built with
/// `--dart-define=VESPER_CI_TOUR=true`; [enabled] is a constant, so the
/// app itself never contains it). There is no Apple TV to test on: the
/// tour walks the real app on the simulator and logs `VesperTour: shot
/// <name>` at each stop, and `tools/tvos/sim_tour.sh` takes a screenshot
/// for each (owner, 2026-11-19: "We could skip and check the UI").
///
/// Sections open through Vesper's own `open` command (the same openers as
/// the remote); inside a screen the tour presses the remote's keys the way
/// the Siri Remote reaches Flutter (arrows, Enter = click, Menu = Back).
class CiTour {
  CiTour._();

  static const enabled = bool.fromEnvironment('VESPER_CI_TOUR');

  /// A public free-to-air list (iptv-org), so the screens have channels
  /// and logos. Only on an empty install; updated without asking.
  static Future<void> seed(StorageService storage) async {
    if (!enabled || storage.getPlaylists().isNotEmpty) return;
    await storage.setPlaylists([
      PlaylistProfile(
        id: 'ci-tour',
        name: 'iptv-org UK',
        mode: 'm3u',
        m3uUrl: 'https://iptv-org.github.io/iptv/countries/uk.m3u',
        sortOrder: 0,
        autoSync: true,
        createdAt: DateTime.now(),
      ),
    ]);
    _log('seeded the iptv-org UK playlist');
  }

  static Future<void> run() async {
    if (!enabled) return;
    _log('waiting for the app');
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (!await _open('tv')) {
      if (DateTime.now().isAfter(deadline)) {
        await _shot('never-ready');
        _log('done (the app never came up)');
        return;
      }
      await _wait(2);
    }
    await _wait(5);
    await _shot('tv');

    await _open('group', query: 'News');
    await _wait(4);
    await _shot('news-group');
    await _key('down');
    await _key('down');
    await _wait(1);
    await _shot('news-down');
    await _key('enter');
    await _wait(10);
    await _shot('preview');
    await _key('enter');
    await _wait(8);
    await _shot('full-screen');
    // The bar opens on Play / Pause; Left twice = Multiview (Stop between).
    await _key('enter');
    await _wait(2);
    await _shot('full-screen-bar');
    await _key('left');
    await _key('left');
    await _wait(1);
    await _shot('bar-multiview-button');
    // Multiview with this channel on screen 1, then screen 2's picker (a
    // fresh install has the 2-screen layout: screen 2 is under screen 1).
    await _key('enter');
    await _wait(8);
    await _shot('multiview');
    await _key('down');
    await _key('enter');
    await _wait(2);
    await _shot('multiview-picker');
    await _back();
    await _wait(1);
    // Leaving Multiview plays screen 1's channel in full screen again.
    await _back();
    await _wait(6);
    await _shot('back-from-multiview');
    await _back();
    await _wait(3);
    await _shot('back-to-guide');
    await _key('left');
    await _wait(2);
    await _shot('groups');

    await _open('movies');
    await _wait(4);
    await _shot('movies');

    await _open('sports');
    await _wait(12);
    await _shot('sports');
    await _key('down');
    await _wait(2);
    await _shot('sports-down');
    await _back();
    await _wait(3);

    await _open('settings');
    await _wait(4);
    await _shot('settings');
    await _key('down');
    await _key('enter');
    await _wait(3);
    await _shot('settings-page');
    await _key('enter');
    await _wait(2);
    await _shot('settings-choice');
    await _back();
    await _back();
    await _back();
    await _wait(3);

    await _open('search', query: 'news');
    await _wait(6);
    await _shot('search');
    await _back();
    await _wait(2);
    await _shot('end');
    _log('done');
  }

  static Future<bool> _open(String section, {String? query}) async {
    final box = VesperAi.instance.toolbox;
    if (box == null) return false;
    final r = await box.call('open', {
      'section': section,
      if (query != null) 'query': query,
    });
    _log('open $section${query == null ? '' : ' "$query"'}: $r');
    return r['error'] == null;
  }

  static Future<void> _shot(String name) async {
    _log('shot $name');
    // sim_tour.sh takes the screenshot when it reads that line.
    await _wait(2);
  }

  /// HID usages the Apple TV keyboard path sends (iOS raw key messages).
  static const _keys = {
    'up': 0x52,
    'down': 0x51,
    'left': 0x50,
    'right': 0x4f,
    'enter': 0x28,
  };

  static Future<void> _key(String name) async {
    for (final type in const ['keydown', 'keyup']) {
      final data = SystemChannels.keyEvent.codec.encodeMessage({
        'type': type,
        'keymap': 'ios',
        'keyCode': _keys[name],
        'characters': '',
        'charactersIgnoringModifiers': '',
        'modifiers': 0,
      });
      final handled = Completer<void>();
      ui.channelBuffers.push(SystemChannels.keyEvent.name, data, (_) {
        if (!handled.isCompleted) handled.complete();
      });
      await handled.future
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await WidgetsBinding.instance.endOfFrame;
    final focus = FocusManager.instance.primaryFocus;
    _log('key $name -> ${focus?.debugLabel ?? focus?.context?.widget}');
  }

  /// The Siri Remote's Menu: the engine's popRoute.
  static Future<void> _back() async {
    final data =
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
    final done = Completer<void>();
    ui.channelBuffers.push(SystemChannels.navigation.name, data, (_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    _log('back');
  }

  static Future<void> _wait(int seconds) =>
      Future<void>.delayed(Duration(seconds: seconds));

  static void _log(String message) => debugPrint('VesperTour: $message');
}
