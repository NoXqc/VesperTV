import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/viewer_profile.dart';
import '../utils/constants.dart';
import '../services/app_exit.dart';
import '../services/home_wallpaper.dart';
import '../services/storage_service.dart';
import '../services/viewer_profile_service.dart';
import '../widgets/profile_card.dart';
import '../widgets/settings_scaffold.dart';

/// A launch-only gate. The application routes and automatic playback are not
/// created until [onSelected], after switchTo has applied the selected viewer.
class StartupProfileScreen extends StatefulWidget {
  const StartupProfileScreen(
      {super.key, required this.onSelected, this.wallpapers});
  final VoidCallback onSelected;

  /// Tests point this at a temporary folder; [HomeWallpaper.instance].
  final HomeWallpaper? wallpapers;

  @override
  State<StartupProfileScreen> createState() => _StartupProfileScreenState();
}

class _StartupProfileScreenState extends State<StartupProfileScreen> {
  final _nodes = <String, FocusNode>{};
  bool _busy = false;
  String? _selected;
  String? _error;
  bool _initialFocus = false;
  int _columns = 1;

  /// Home wallpapers of the viewers who turned on "Also behind Who is
  /// watching?" (Settings > General > Home wallpaper); the highlighted
  /// card's shows behind the panel.
  final _wallpapers = <String, Uint8List>{};

  /// The same wallpapers small and blurred once: the panel's frosted glass.
  /// A live BackdropFilter (sigma 20) redid the blur over most of the screen
  /// on every frame of a step's card and wallpaper fades: slow on the
  /// Homatics (owner, +772).
  final _glass = <String, ui.Image>{};

  /// The highlighted card. A step repaints the wallpaper and glass, it
  /// doesn't rebuild the page.
  late final ValueNotifier<String?> _focused =
      ValueNotifier(context.read<ViewerProfileService>().active.id);

  @override
  void initState() {
    super.initState();
    _loadWallpapers();
  }

  Future<void> _loadWallpapers() async {
    final storage = context.read<StorageService>();
    final ids = [
      for (final p in context.read<ViewerProfileService>().profiles)
        if (storage.getWallpaperOnProfiles(viewerId: p.id)) p.id,
    ];
    for (final id in ids) {
      final bytes =
          await (widget.wallpapers ?? HomeWallpaper.instance).load(id);
      if (bytes == null || !mounted) continue;
      setState(() => _wallpapers[id] = bytes);
      try {
        final glass = await SettingsBackdrop.blurred(bytes, sigma: 3.3);
        if (!mounted) {
          glass.dispose();
          return;
        }
        setState(() => _glass[id] = glass);
      } catch (e) {
        debugPrint('StartupProfile: wallpaper glass failed: $e');
      }
    }
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _focused.dispose();
    for (final image in _glass.values) {
      image.dispose();
    }
    super.dispose();
  }

  void _reveal(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.hasFocus && node.context != null) {
        Scrollable.ensureVisible(node.context!, duration: Duration.zero);
      }
    });
  }

  void _move(List<ViewerProfile> profiles, int dx, int dy) {
    if (_busy) return;
    final index = profiles.indexWhere((p) => _nodes[p.id]?.hasFocus ?? false);
    if (index < 0) return;
    if (dx < 0 && index % _columns == 0) return;
    if (dx > 0 && index % _columns == _columns - 1) return;
    final next = dy == 0
        ? index + dx
        : dy > 0 && index + _columns >= profiles.length
            ? (index ~/ _columns + 1) * _columns < profiles.length
                ? profiles.length - 1
                : index
            : index + dy * _columns;
    if (next >= 0 && next < profiles.length) {
      _nodes[profiles[next].id]!.requestFocus();
    }
  }

  Future<void> _select(ViewerProfile profile) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    try {
      final switched = await context
          .read<ViewerProfileService>()
          .switchTo(context, profile.id);
      if (!mounted) return;
      if (!switched) {
        setState(() => _busy = false);
        _nodes[profile.id]?.requestFocus();
        return;
      }
      setState(() => _selected = profile.id);
      if (!reduceMotion) {
        await Future<void>.delayed(const Duration(milliseconds: 420));
      }
      if (mounted) widget.onSelected();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _selected = null;
        _error = tr('Could not switch profile. Please try again.');
      });
      _nodes[profile.id]?.requestFocus();
    }
  }

  /// Back here (at launch, or after Back from the app's root returned to
  /// this screen) leaves the app like the TV home's ([AppExit.back]: warm
  /// on Android, asks first on a computer, Stay focused).
  bool _exitPromptOpen = false;

  Future<void> _confirmExit() async {
    if (_busy || _exitPromptOpen) return;
    _exitPromptOpen = true;
    try {
      await AppExit.back(() async {
        final exit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title:
                Text(tr('Exit {appName}?', {'appName': AppConstants.appName})),
            content: Text(tr('Are you sure you want to exit {appName}?',
                {'appName': AppConstants.appName})),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(tr('Exit')),
              ),
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(tr('Stay')),
              ),
            ],
          ),
        );
        return exit == true && mounted;
      });
    } finally {
      _exitPromptOpen = false;
    }
  }

  Widget _profileGrid(
      List<ViewerProfile> profiles, double width, Duration motion) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _move(profiles, -1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _move(profiles, 1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(profiles, 0, -1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _move(profiles, 0, 1),
      },
      child: IgnorePointer(
        ignoring: _busy,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 24,
            children: [
              for (final profile in profiles)
                SizedBox(
                  width: width,
                  child: AnimatedOpacity(
                    opacity:
                        _selected != null && _selected != profile.id ? .12 : 1,
                    duration: motion,
                    child: AnimatedScale(
                      scale: _selected == profile.id ? 1.06 : 1,
                      duration: motion,
                      curve: Curves.easeOutCubic,
                      child: Center(
                        child: ProfileCard(
                          key: ValueKey('startup-profile-${profile.id}'),
                          profile: profile,
                          label: profile.displayName,
                          focusNode: _nodes[profile.id]!,
                          active: _selected == profile.id,
                          onFocused: () {
                            _reveal(_nodes[profile.id]!);
                            _focused.value = profile.id;
                          },
                          onTap: () => _select(profile),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewers = context.watch<ViewerProfileService>();
    final profiles = viewers.profiles;
    for (final profile in profiles) {
      _nodes.putIfAbsent(profile.id, () => FocusNode());
    }
    if (!_initialFocus) {
      _initialFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nodes[viewers.active.id]?.requestFocus();
      });
    }
    final accent = Theme.of(context).colorScheme.primary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = Duration(milliseconds: reduceMotion ? 0 : 260);
    final selected = profiles.where((p) => p.id == _selected).firstOrNull;
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final fade = Duration(milliseconds: reduceMotion ? 0 : 450);
    final glows = _glows(accent);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The highlighted viewer's wallpaper, dimmed so the panel
                  // reads; crossfades as the highlight moves.
                  ValueListenableBuilder<String?>(
                    valueListenable: _focused,
                    builder: (context, focused, _) {
                      final id = _selected ?? focused;
                      final wallpaper = _wallpapers[id];
                      return AnimatedSwitcher(
                        duration: fade,
                        child: wallpaper == null
                            ? const SizedBox.expand(
                                key: ValueKey('no-wallpaper'))
                            : Stack(
                                key: ValueKey('wallpaper-$id'),
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(wallpaper,
                                      fit: BoxFit.cover,
                                      cacheWidth: math
                                          .min(
                                              1920,
                                              size.width *
                                                  MediaQuery.devicePixelRatioOf(
                                                      context))
                                          .round(),
                                      gaplessPlayback: true,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink()),
                                  const ColoredBox(color: _dim),
                                ],
                              ),
                      );
                    },
                  ),
                  for (final glow in glows)
                    DecoratedBox(decoration: BoxDecoration(gradient: glow)),
                ],
              ),
            ),
            SafeArea(
              child: LayoutBuilder(builder: (context, bounds) {
                final padding = bounds.maxWidth < 600 || bounds.maxHeight < 500
                    ? 16.0
                    : 40.0;
                final panelWidth =
                    math.min(900.0, bounds.maxWidth - padding * 2);
                final inside =
                    panelWidth < 500 || bounds.maxHeight < 500 ? 20.0 : 36.0;
                final gridWidth = panelWidth - inside * 2;
                _columns = ((gridWidth + 20) / 148).floor().clamp(1, 5);
                final tileWidth = (gridWidth - (_columns - 1) * 20) / _columns;
                return Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: reduceMotion ? 0 : 360),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                          offset: Offset(0, 18 * (1 - value)), child: child),
                    ),
                    child: Container(
                      width: panelWidth,
                      constraints: BoxConstraints(
                          maxHeight:
                              math.max(0, bounds.maxHeight - padding * 2)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black54,
                              blurRadius: 48,
                              offset: Offset(0, 18)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: ValueListenableBuilder<String?>(
                                  valueListenable: _focused,
                                  builder: (context, focused, _) {
                                    final id = _selected ?? focused;
                                    final glass = _glass[id];
                                    return AnimatedSwitcher(
                                      duration: fade,
                                      child: glass == null
                                          ? const SizedBox.expand(
                                              key: ValueKey('no-glass'))
                                          : CustomPaint(
                                              key: ValueKey('glass-$id'),
                                              painter: _PanelGlass(
                                                  glass,
                                                  Offset(safe.left, safe.top) &
                                                      bounds.biggest,
                                                  size,
                                                  glows),
                                              child: const SizedBox.expand(),
                                            ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            RepaintBoundary(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white24),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0x493C4657),
                                      Color(0xB318202E)
                                    ],
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.all(inside),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          color: accent, size: 28),
                                      const SizedBox(height: 14),
                                      Text(tr('Who is watching?'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      Text(
                                          selected == null
                                              ? tr(
                                                  'Choose your profile to get started.')
                                              : tr('Welcome, {name}', {
                                                  'name': selected.displayName
                                                }),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                      const SizedBox(height: 28),
                                      _profileGrid(profiles, tileWidth, motion),
                                      if (_error != null) ...[
                                        const SizedBox(height: 16),
                                        Text(_error!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  static const _dim = Color(0x73000000);

  /// The two soft lights over the wallpaper (the panel's glass repeats them).
  static List<RadialGradient> _glows(Color accent) => [
        RadialGradient(
          center: const Alignment(-.7, -.8),
          radius: 1.5,
          colors: [accent.withValues(alpha: .24), Colors.transparent],
        ),
        const RadialGradient(
          center: Alignment(.9, .9),
          radius: 1.1,
          colors: [Color(0x503B5F99), Colors.transparent],
        ),
      ];
}

/// The panel's frosted glass without a live blur: the blurred wallpaper and
/// the page's lights, drawn where they are on the screen behind the panel.
class _PanelGlass extends CustomPainter {
  _PanelGlass(this.image, this.area, this.screen, this.glows);
  final ui.Image image;

  /// The SafeArea the panel is centred in, in screen coordinates.
  final Rect area;
  final Size screen;
  final List<RadialGradient> glows;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = area.topLeft +
        Offset((area.width - size.width) / 2, (area.height - size.height) / 2);
    final page = (-origin) & screen;
    final panel = Offset.zero & size;
    canvas.save();
    canvas.clipRect(panel);
    paintImage(
        canvas: canvas,
        rect: page,
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium);
    canvas.drawRect(panel, Paint()..color = _StartupProfileScreenState._dim);
    for (final glow in glows) {
      canvas.drawRect(panel, Paint()..shader = glow.createShader(page));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanelGlass old) =>
      old.image != image ||
      old.area != area ||
      old.screen != screen ||
      old.glows.first.colors.first != glows.first.colors.first;
}
