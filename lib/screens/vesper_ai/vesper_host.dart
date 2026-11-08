import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/channel.dart';
import '../../models/viewer_profile.dart';
import '../../models/xtream_series.dart';
import '../../services/app_preferences.dart';
import '../../services/desktop_mini_player.dart';
import '../../services/guide_key.dart';
import '../../services/parental_pin.dart';
import '../../services/playback_service.dart';
import '../../services/vesper_ai/vesper_ai.dart';
import '../../services/vesper_ai/vesper_tools.dart';
import '../../services/viewer_profile_service.dart';
import '../../widgets/pin_pad.dart';
import '../../widgets/tv_dialog_option.dart';
import '../archive_screen.dart';
import '../desktop_player_screen.dart';
import '../home_screen.dart';
import '../player_screen.dart';
import '../search_screen.dart';
import '../series_detail_screen.dart';
import '../settings/settings_menu_screen.dart';
import '../sports_screen.dart';
import '../../utils/desktop_platform.dart';

/// [VesperHost] on the app's navigator: plays like picking a channel in the
/// guide (full screen, both players), opens sections through the TV home's
/// own openers ([GuideKey.openSection]), asks on the TV for AI-app actions.
class AppVesperHost implements VesperHost {
  AppVesperHost(
      {required this.navigatorKey,
      required this.playback,
      required this.prefs});

  final GlobalKey<NavigatorState> navigatorKey;
  final PlaybackService playback;
  final AppPreferences prefs;

  NavigatorState get _nav {
    final nav = navigatorKey.currentState;
    if (nav == null) throw VesperToolError('The app is still starting.');
    return nav;
  }

  @override
  Future<void> playChannel(Channel channel) async {
    final nav = _nav;
    // Over whatever is open (the panel included), like a fresh pick.
    nav.popUntil((r) => r.isFirst);
    if (isDesktop) {
      DesktopMiniPlayer.instance.clear();
      unawaited(nav.push(MaterialPageRoute(
          builder: (_) => DesktopPlayerScreen(channel: channel))));
      return;
    }
    // Awaited before the push, as Search does (PlayerScreen's own play is
    // then a no-op on the same channel).
    await playback.play(channel);
    unawaited(nav
        .push(PlayerPageRoute(builder: (_) => PlayerScreen(channel: channel))));
  }

  @override
  Future<void> openSeries(XtreamSeries series) async {
    final nav = _nav;
    nav.popUntil((r) => r.isFirst);
    unawaited(nav.push(
        MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series))));
  }

  @override
  Future<bool> openSection(String section, {String? query}) async {
    final nav = _nav;
    final handled = GuideKey.openSection(nav, section, query: query);
    if (handled != null) return handled;
    // No TV home open (Sports Mode): open the page itself.
    Widget? page = switch (section) {
      'home' => const HomeScreen(),
      'hub' when !prefs.hideArchive => ArchiveScreen(initialQuery: query),
      'sports' when !prefs.hideSportsTrak => const SportsScreen(),
      'search' => SearchScreen(initialScope: 'TV', initialQuery: query),
      'settings' => const SettingsMenuScreen(),
      _ => null,
    };
    if (page == null) return false;
    nav.popUntil((r) => r.isFirst);
    unawaited(nav.push(MaterialPageRoute(builder: (_) => page)));
    return true;
  }

  @override
  Future<bool> confirm(String question, Map<String, Object?> args) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final answer = showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(text: tr(question, args)),
    );
    // No answer within a minute = no (nobody is in front of the TV).
    return await answer.timeout(const Duration(minutes: 1), onTimeout: () {
          final nav = navigatorKey.currentState;
          if (nav != null && nav.canPop()) nav.pop(false);
          return false;
        }) ??
        false;
  }

  @override
  void showMessage(String text) =>
      VesperAi.instance.showBubble(text, from: tr('AI app'));
}

/// [VesperProfileControl] on the app's own profile service and PIN pad.
class AppVesperProfiles implements VesperProfileControl {
  AppVesperProfiles(
      {required this.navigatorKey, required this.viewers, required this.pin});

  final GlobalKey<NavigatorState> navigatorKey;
  final ViewerProfileService viewers;
  final ParentalPin pin;

  /// Nobody at the TV for 2 minutes = cancelled.
  static const _padTimeout = Duration(minutes: 2);

  BuildContext get _context =>
      navigatorKey.currentContext ??
      (throw VesperToolError('The app is still starting.'));

  @override
  List<ViewerProfile> get profiles => viewers.profiles;
  @override
  ViewerProfile get active => viewers.active;
  @override
  bool get pinSet => pin.isSet;

  @override
  Future<bool> askPin() => promptForPin(_context, timeout: _padTimeout);
  @override
  Future<bool> newPin() => setupPinFlow(_context, timeout: _padTimeout);

  @override
  Future<bool> switchTo(String id, {bool unlocked = false}) {
    // Over whatever is open (the Vesper panel included), like the
    // profile cards: the home screen is rebuilt for the new viewer.
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    return viewers.switchTo(_context, id, unlocked: unlocked);
  }

  @override
  Future<ViewerProfile> create(String name,
          {required bool kid, required int colour}) =>
      viewers.createProfile(name: name, colorIndex: colour, isRestricted: kid);
  @override
  Future<void> rename(String id, String name) =>
      viewers.renameProfile(id, name);
  @override
  Future<bool> delete(String id) => viewers.deleteProfile(id);
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
      ),
      title: Row(children: [
        Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        const Text('Vesper AI'),
      ]),
      content: Text(text),
      actions: [
        TvDialogOption(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Cancel')),
        ),
        TvDialogOption(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr('OK')),
        ),
      ],
    );
  }
}
