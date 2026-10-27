import '../utils/refined_finish.dart';
import 'package:flutter/material.dart';

import 'tv_app_bar_button.dart';
import '../l10n/l10n.dart';

/// Every Settings-family screen's background used to be whatever flat,
/// near-black surface `ThemeData.scaffoldBackgroundColor` happened to
/// resolve to — reported directly as looking like a plain terminal,
/// nothing like the rest of this app's own "cyberpunk" duo-tone identity
/// (already named on [CyberpunkPalette] itself: `secondary`'s doc comment
/// literally says "gradient partner", a use this was the first screen to
/// actually act on). A reference screenshot of another player's Settings
/// (bright saturated blue gradient, white pill for the focused row, no
/// separate app-bar color break) is the direct inspiration here.
///
/// A `Stack` with the gradient painted behind a fully transparent
/// `Scaffold` — rather than `Scaffold.backgroundColor` alone — so the
/// *app bar* shares the exact same gradient instead of sitting in its own
/// flat-colored strip above it, matching that reference's borderless
/// look. Every Settings screen should use this instead of building its
/// own `Scaffold` directly, the same "fix the look once, centrally"
/// approach `SectionLabel`/`_SelectableRow` already use elsewhere.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold(
      {super.key,
      required this.title,
      required this.body,
      this.actions,
      this.bottom});

  final String title;
  final Widget body;
  final List<Widget>? actions;

  /// For screens that need a TabBar in the app bar (Group Management) —
  /// kept optional since most Settings screens don't.
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _SettingsGradientBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            // Replaces the implicit default back button — reported
            // directly: "the back arrow, edit and delete is barely
            // visible... that's the case for every page." Flutter's own
            // default focus indicator for an AppBar's back button is a
            // faint ripple/overlay, not the solid-fill-on-real-focus this
            // app established everywhere else via ModeButton.
            // TvAppBarButton is that same fix, sized for the app bar.
            leading: Builder(
              builder: (context) => ModalRoute.of(context)?.canPop ?? false
                  ? Center(
                      child: TvAppBarButton.icon(
                        icon: Icons.arrow_back,
                        tooltip: tr('Back'),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            title: Text(title),
            actions: actions,
            bottom: bottom,
          ),
          body: body,
        ),
      ],
    );
  }
}

/// Standalone so [GroupManagementScreen] (which needs its own `PopScope`
/// wrapping the whole `Scaffold`, not just this background) can paint the
/// identical gradient without going through [SettingsScaffold] itself.
class SettingsGradientBackground extends StatelessWidget {
  const SettingsGradientBackground({super.key});

  @override
  Widget build(BuildContext context) => const _SettingsGradientBackground();
}

class _SettingsGradientBackground extends StatelessWidget {
  const _SettingsGradientBackground();

  @override
  Widget build(BuildContext context) {
    // Keep the original black backdrop when off. The opt-in finish adds
    // palette light using opaque stops, keeping the page readable.
    if (!RefinedFinish.of(context)) {
      return const ColoredBox(color: Colors.black);
    }
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.black,
            gradient: RadialGradient(
                center: const Alignment(-0.75, -0.8),
                radius: 1.65,
                colors: [
                  Color.alphaBlend(
                      scheme.primary.withValues(alpha: 0.14), Colors.black),
                  Color.alphaBlend(
                      scheme.secondary.withValues(alpha: 0.035), Colors.black),
                  Colors.black
                ],
                stops: const [
                  0,
                  0.5,
                  1
                ])));
  }
}
