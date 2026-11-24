import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_preferences.dart';
import '../utils/tv_theme.dart';
import '../widgets/mode_button.dart';
import '../l10n/l10n.dart';

/// What the new viewer picked on [WelcomeAddPlaylistScreen].
enum WelcomeChoice {
  skip,
  addPlaylist,

  /// Sync, a transfer or a backup ([FromAnotherDeviceScreen]).
  fromAnotherDevice,
}

/// Shown once, from main.dart's bootstrap gate, the very first time the app
/// launches with zero playlists configured — a brand-new install has no
/// other hint that content lives behind Settings > Playlist Manager rather
/// than just showing up. Modeled directly on [CatalogSyncPromptScreen]: same
/// "runs before the real MaterialApp/theme tree exists, so it carries its
/// own" situation, same reason it reads [AppPreferences.palette] itself
/// instead of inheriting a theme.
class WelcomeAddPlaylistScreen extends StatelessWidget {
  const WelcomeAddPlaylistScreen({super.key, required this.onRespond});

  /// [WelcomeChoice.addPlaylist] opens [AddPlaylistScreen] right after
  /// bootstrap finishes, [WelcomeChoice.fromAnotherDevice] opens
  /// [FromAnotherDeviceScreen], [WelcomeChoice.skip] lands on the normal
  /// (empty) main app — see main.dart's `_welcomeChoice` for why this can't
  /// just push the screen directly from here (no Navigator exists yet at
  /// this point).
  final void Function(WelcomeChoice choice) onRespond;

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<AppPreferences>().palette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: buildPaletteColorScheme(palette, Brightness.dark),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          // Scrolls and stacks the buttons: with a phone's largest font and
          // display size the text pushed the buttons off the screen
          // (vision-impaired user, 2026-11-02).
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 640 ||
                  MediaQuery.textScalerOf(context).scale(16) > 20;
              final skip = ModeButton(
                label: tr('Skip for now'),
                selected: false,
                onTap: () => onRespond(WelcomeChoice.skip),
              );
              final add = ModeButton(
                label: tr('Add Playlist'),
                selected: false,
                onTap: () => onRespond(WelcomeChoice.addPlaylist),
              );
              // Sync, a transfer or a backup from a device that already has
              // VesperTV (BallerMC, Discord, 2026-11-22: a new Apple TV
              // install offered only Skip / Add Playlist).
              final other = ModeButton(
                label: tr('From another device'),
                selected: false,
                onTap: () => onRespond(WelcomeChoice.fromAnotherDevice),
              );
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(stacked ? 20 : 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/icon/icon_flat.png',
                              width: 96,
                              height: 96,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            tr('Hey beautiful Human,'),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              tr('Welcome to VesperTV'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(
                              tr('Add your first playlist?'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr('Add a playlist to kick things off, or skip for now if you just want to browse and discover the app without content.'),
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('Already use VesperTV on another device? Bring your playlists, favourites and settings here.'),
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          // ModeButton over plain Outlined/FilledButton for
                          // the same reason as CatalogSyncPromptScreen — a
                          // solid fill *only* on real D-pad focus, not
                          // permanently on one button.
                          if (stacked)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                add,
                                const SizedBox(height: 12),
                                other,
                                const SizedBox(height: 12),
                                skip,
                              ],
                            )
                          else
                            // Same height for all three when one label
                            // wraps (a longer translation).
                            SizedBox(
                              width: 560,
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: skip),
                                    const SizedBox(width: 16),
                                    Expanded(child: other),
                                    const SizedBox(width: 16),
                                    Expanded(child: add),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
