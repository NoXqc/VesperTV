import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_preferences.dart';
import '../services/storage_service.dart';

/// Places Home above the TV root before the Navigator's first frame.
/// Back still returns to the normal tabs/groups/guide screen.
class StartupHomeRoutes {
  bool _generated = false;
  bool homeHandled = false;
  Timer? _guardTimer;

  List<Route<dynamic>> generate({
    required AppPreferences preferences,
    required StorageService storage,
    required WidgetBuilder rootBuilder,
    required WidgetBuilder homeBuilder,
  }) {
    final openHome = !_generated &&
        preferences.effectiveStartSection == 'home' &&
        !storage.getStartSectionPending();
    _generated = true;
    if (openHome) {
      homeHandled = true;
      // Same crash guard as TvHomeScreen's other startup destinations.
      unawaited(storage.setStartSectionPending(true));
      _guardTimer = Timer(const Duration(seconds: 15),
          () => unawaited(storage.setStartSectionPending(false)));
    }
    return [
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'), builder: rootBuilder),
      if (openHome)
        MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/startup-home'),
            builder: homeBuilder),
    ];
  }

  void dispose() => _guardTimer?.cancel();
}
