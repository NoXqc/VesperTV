import 'dart:typed_data';
import 'dart:ui' as ui;

import '../utils/refined_finish.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'glass_menu.dart';
import 'tv_app_bar_button.dart';
import 'tv_menu_tile.dart';
import '../l10n/l10n.dart';
import '../services/app_preferences.dart';
import '../services/device_memory_service.dart';
import '../services/home_wallpaper.dart';
import '../utils/desktop_platform.dart';

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
      this.backFocusNode,
      this.actions,
      this.bottom,
      this.panel = true,
      this.wide = false});

  final String title;
  final Widget body;
  final FocusNode? backFocusNode;
  final List<Widget>? actions;

  /// For screens that need a TabBar in the app bar (Group Management) —
  /// kept optional since most Settings screens don't.
  final PreferredSizeWidget? bottom;

  /// TV box / computer: the page floats on a [GlassPanel] over the
  /// wallpaper (owner, 2026-11-10: Settings should look like the app's
  /// glass menus, not full-width boxes). Off for a page that draws its own
  /// panels (the Settings menu).
  final bool panel;

  /// The panel spans the screen: multi-pane tools (Add Playlist, Playlist
  /// Manager, guide matching). Otherwise it is at most [panelWidth] wide
  /// and centred, so a short form doesn't stretch across the TV.
  final bool wide;

  static const panelWidth = 760.0;

  /// Compact rows on this device (a TV box or a computer).
  static bool get compact => DeviceTypeService.television || isDesktopTarget;

  /// Settings' focus look: no gold wash (the "pastel selector", owner
  /// 2026-11-10) — a faint light sheen for stock widgets, the glass outline
  /// for rows ([GlassRowScope]) — and rounded glass text fields, smaller
  /// on a TV box / computer ([compact]) so a short form stays short.
  /// [glassTheme] built once per theme: a new copy per build never
  /// compared equal, and `Theme` then rebuilt every row under it
  /// (CLAUDE.md §10 "Frame cost on weak boxes" (2)).
  static final _glassThemes = Expando<List<ThemeData?>>();

  static ThemeData _glassFor(ThemeData theme, bool compact) {
    final cached = _glassThemes[theme] ??= List<ThemeData?>.filled(2, null);
    return cached[compact ? 1 : 0] ??= glassTheme(theme, compact: compact);
  }

  static ThemeData glassTheme(ThemeData theme, {bool compact = false}) {
    final scheme = theme.colorScheme;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width));
    return theme.copyWith(
      focusColor: Colors.white.withValues(alpha: 0.10),
      hoverColor: Colors.white.withValues(alpha: 0.05),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: border(Colors.white24, 1),
        focusedBorder: border(scheme.primary, 2),
        isDense: compact ? true : null,
        contentPadding: compact
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (SettingsFloating.of(context)) return _buildFloating(context);
    final glass = compact && panel;
    return Theme(
      data: _glassFor(Theme.of(context), compact),
      child: Stack(
        children: [
          const Positioned.fill(
              child: RepaintBoundary(child: SettingsBackdrop())),
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
                          focusNode: backFocusNode,
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
            // TV boxes and computers: compact rows (CompactMenus). Phones
            // keep Material's touch sizes.
            //
            // SafeArea: Android 15 draws apps behind the navigation bar, and a
            // ListView with its own padding doesn't add that space itself, so a
            // page's last row stayed under the Back/Home buttons (user photo,
            // Settings > Playback > Resume reminder, 2026-11-09). No inset on
            // a TV box, so nothing changes there.
            body: SafeArea(
              top: false,
              child: GlassRowScope(
                child: compact
                    ? CompactMenus(
                        child: CompactMenus.listTheme(context,
                            child: glass ? _floating(body) : body))
                    : body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floating(Widget body) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: wide ? double.infinity : panelWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            child: SizedBox(
                width: double.infinity, child: GlassPanel(child: body)),
          ),
        ),
      );

  /// [openSettingsPage] with `floating`: the page is a glass panel over the
  /// one below (dimmed), sized to what it holds — title and Back inside it.
  Widget _buildFloating(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Theme(
      data: _glassFor(Theme.of(context), compact),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: wide ? 900 : floatingWidth,
                maxHeight: size.height * 0.9),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GlassPanel(
                blur: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 12, 2),
                      child: Row(children: [
                        if (canPop)
                          TvAppBarButton.icon(
                            focusNode: backFocusNode,
                            icon: Icons.arrow_back,
                            tooltip: tr('Back'),
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                        ...?actions,
                      ]),
                    ),
                    Flexible(
                      child: GlassRowScope(
                        child: CompactMenus(
                          child: CompactMenus.listTheme(context, child: body),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const floatingWidth = 680.0;
}

/// Marks a Settings page opened by [openSettingsPage] as a floating panel.
class SettingsFloating extends InheritedWidget {
  const SettingsFloating({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsFloating>() != null;

  @override
  bool updateShouldNotify(SettingsFloating oldWidget) => false;
}

/// Opens a Settings page. With [floating] on a TV box or computer it is a
/// glass panel over the screen below instead of a page of its own (owner,
/// 2026-11-10: a short form shouldn't take the whole TV); a phone always
/// gets a normal page. Back, or a click outside, closes it.
Future<T?> openSettingsPage<T>(BuildContext context, WidgetBuilder builder,
    {bool floating = false}) {
  final navigator = Navigator.of(context);
  if (!floating || !SettingsScaffold.compact) {
    return navigator.push<T>(MaterialPageRoute(builder: builder));
  }
  return navigator.push<T>(PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, __, ___) =>
        SettingsFloating(child: Builder(builder: builder)),
    transitionsBuilder: (_, animation, __, child) {
      final curve =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curve), child: child),
      );
    },
  ));
}

/// Behind every Settings page: the viewer's Home wallpaper, blurred and
/// dimmed, so the glass panels have something to show through; without
/// one, a soft glow in the theme colours. The picture is decoded tiny,
/// blurred once and kept for the session, so pages pushed on top don't read
/// the file again. A live full-screen blur (ImageFiltered) was redone by
/// the GPU on every frame: 24-36 ms per frame on the Homatics while
/// scrolling Settings (2026-11-13).
class SettingsBackdrop extends StatefulWidget {
  const SettingsBackdrop({super.key});

  /// The wallpaper 160 px wide, blurred once (sigma 1 there is the old
  /// sigma 6 on the screen-size picture); drawn scaled up, which smooths
  /// it further. Who's watching's panel uses it too ([sigma] 3.3 = its old
  /// live sigma 20 on a 960-wide screen).
  static Future<ui.Image> blurred(Uint8List bytes, {double sigma = 1}) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 160);
    final source = (await codec.getNextFrame()).image;
    codec.dispose();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(
        source,
        Offset.zero,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
              sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp));
    final picture = recorder.endRecording();
    final image = await picture.toImage(source.width, source.height);
    picture.dispose();
    source.dispose();
    return image;
  }

  @override
  State<SettingsBackdrop> createState() => _SettingsBackdropState();
}

class _SettingsBackdropState extends State<SettingsBackdrop> {
  static String? _cachedFor;
  static ui.Image? _cached;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    HomeWallpaper.instance.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    HomeWallpaper.instance.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final viewer = context.read<AppPreferences?>()?.storage.getActiveViewerId();
    if (viewer == null) return;
    final key = '$viewer#${HomeWallpaper.instance.changes.value}';
    if (_cachedFor == key) {
      if (_image != _cached) setState(() => _image = _cached);
      return;
    }
    final bytes = await HomeWallpaper.instance.load(viewer);
    ui.Image? image;
    if (bytes != null) {
      try {
        image = await SettingsBackdrop.blurred(bytes);
      } catch (e) {
        debugPrint('SettingsBackdrop: wallpaper failed: $e');
      }
    }
    _cachedFor = key;
    _cached = image;
    if (mounted && image != _image) setState(() => _image = image);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = _image;
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.9),
            radius: 1.7,
            colors: [
              Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.16), Colors.black),
              Color.alphaBlend(
                  scheme.secondary.withValues(alpha: 0.05), Colors.black),
              Colors.black,
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
      ),
      if (image != null)
        RepaintBoundary(
          child: RawImage(
            image: image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      if (image != null) const ColoredBox(color: Color(0x80000000)),
    ]);
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
