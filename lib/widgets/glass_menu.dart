import 'dart:async';
import 'dart:ui' as ui show Image, PictureRecorder;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/refined_finish.dart';
import 'ink_layer.dart';

/// Keeps the backdrop visible while preserving each menu's dismissal policy.
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final frost = GlassFrost.capture(context);
  return frost.during(showDialog<T>(
    context: context,
    builder: (context) => frost.scope(builder(context)),
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black38,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  ));
}

/// The page under a menu, captured small and blurred ONCE when the menu
/// opens: the panel's frosted glass. A live BackdropFilter re-blurred the
/// screen on every frame the menu drew (each D-pad step's focus fade, and
/// every frame anything behind moved: Home's hero, live scores, the mini
/// player), the same cost as the old Settings / Who's watching blurs
/// (CLAUDE.md §10 rule 13; Home's row hold menu, owner photo 2026-11-13).
/// Native video (a SurfaceView behind the Flutter view) isn't in the
/// capture: it shows through the panel's dark fill as before.
class GlassFrost {
  GlassFrost._();

  /// The capture's scale: 1/5 of logical pixels, blurred with sigma 2.4
  /// there = the old live sigma 12, and drawn scaled up (smooths further).
  static const _scale = 0.2;
  static const _sigma = 12 * _scale;

  final ValueNotifier<_Frost?> _frost = ValueNotifier(null);
  bool _closed = false;

  /// Starts the capture now, before the menu's route is pushed (the scene is
  /// read synchronously; only its raster is async), so the menu itself is
  /// never in it. Nothing is captured over moving video ([GlassBlur.live]
  /// false: no blur at all there) or when no page boundary is found; the
  /// panel then keeps its plain look until the capture lands.
  static GlassFrost capture(BuildContext context) {
    final frost = GlassFrost._();
    if (GlassBlur.live) frost._start(context);
    return frost;
  }

  void _start(BuildContext context) {
    try {
      final screen = MediaQuery.maybeSizeOf(context);
      RenderRepaintBoundary? page;
      RenderObject? r = context.findRenderObject();
      // The outermost boundary that covers the screen: the whole page (a
      // card's own boundary is only the card).
      while (r != null) {
        if (r is RenderRepaintBoundary &&
            r.attached &&
            r.hasSize &&
            (screen == null ||
                (r.size.width >= screen.width - 1 &&
                    r.size.height >= screen.height - 1))) {
          page = r;
        }
        r = r.parent;
      }
      if (page == null) return;
      if (kDebugMode && page.debugNeedsPaint) return;
      final origin = page.localToGlobal(Offset.zero);
      final size = page.size;
      unawaited(page.toImage(pixelRatio: _scale).then((raw) async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImage(
            raw,
            Offset.zero,
            Paint()
              ..imageFilter = ImageFilter.blur(
                  sigmaX: _sigma, sigmaY: _sigma, tileMode: TileMode.clamp));
        final picture = recorder.endRecording();
        final image = await picture.toImage(raw.width, raw.height);
        picture.dispose();
        raw.dispose();
        if (_closed) {
          image.dispose();
          return;
        }
        _frost.value = _Frost(image, origin & size);
      }).catchError((Object _) {}));
    } catch (_) {
      // No frost: the panel keeps its plain look.
    }
  }

  /// [child] with this capture available to its [GlassMenuSurface]; the
  /// capture is released when the menu's route is gone (after its closing
  /// fade, which still paints the panel).
  Widget scope(Widget child) => _FrostOwner(
      onDispose: _release,
      child: _GlassFrostScope._(frost: _frost, child: child));

  /// [menu]'s result. A capture still rastering when the menu closes is
  /// dropped when it lands.
  Future<T?> during<T>(Future<T?> menu) =>
      menu.whenComplete(() => _closed = true);

  void _release() {
    _closed = true;
    final image = _frost.value?.image;
    _frost.value = null;
    image?.dispose();
  }
}

/// Calls [onDispose] when the menu's page leaves the tree.
class _FrostOwner extends StatefulWidget {
  const _FrostOwner({required this.onDispose, required this.child});
  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_FrostOwner> createState() => _FrostOwnerState();
}

class _FrostOwnerState extends State<_FrostOwner> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Frost {
  const _Frost(this.image, this.rect);
  final ui.Image image;

  /// Where the captured page sits on screen (logical pixels).
  final Rect rect;
}

/// Hands a menu's [GlassFrost] capture to the [GlassMenuSurface] inside.
class _GlassFrostScope extends InheritedWidget {
  const _GlassFrostScope._({required this.frost, required super.child});
  final ValueListenable<_Frost?> frost;

  @override
  bool updateShouldNotify(_GlassFrostScope oldWidget) =>
      frost != oldWidget.frost;
}

/// Draws the part of the frozen, blurred page that is under this box.
class _FrostPainter extends CustomPainter {
  _FrostPainter(this.frost, this.box, {this.dim}) : super(repaint: frost);
  final ValueListenable<_Frost?> frost;
  final RenderBox? Function() box;

  /// Painted over the capture: the route's barrier, which a live blur
  /// sampled too but the capture (taken before the route) doesn't hold.
  final Color? dim;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frost.value;
    final b = box();
    if (f == null || b == null || !b.attached) return;
    // The panel's rect on screen, through any transform (a roll-down's
    // reveal), in the capture's pixels.
    final global =
        MatrixUtils.transformRect(b.getTransformTo(null), Offset.zero & size);
    final sx = f.image.width / f.rect.width;
    final sy = f.image.height / f.rect.height;
    final src = Rect.fromLTRB(
        (global.left - f.rect.left) * sx,
        (global.top - f.rect.top) * sy,
        (global.right - f.rect.left) * sx,
        (global.bottom - f.rect.top) * sy);
    canvas.drawImageRect(f.image, src, Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low);
    if (dim != null) canvas.drawRect(Offset.zero & size, Paint()..color = dim!);
  }

  @override
  bool shouldRepaint(_FrostPainter old) => old.frost != frost;
}

/// The frost behind [child]: the menu's capture when there is one, else a
/// live BackdropFilter (a GlassMenuSurface not opened through
/// [showGlassMenu] / [GlassFrost], e.g. Sports Trak's panel).
class _FrostedBackdrop extends StatefulWidget {
  const _FrostedBackdrop({required this.child, this.dim});
  final Widget child;
  final Color? dim;

  @override
  State<_FrostedBackdrop> createState() => _FrostedBackdropState();
}

class _FrostedBackdropState extends State<_FrostedBackdrop> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_GlassFrostScope>();
    if (scope == null || !GlassBlur.live) {
      return BackdropFilter(
        enabled: GlassBlur.live,
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: widget.child,
      );
    }
    return CustomPaint(
      key: _key,
      painter: _FrostPainter(scope.frost,
          () => _key.currentContext?.findRenderObject() as RenderBox?,
          dim: widget.dim),
      child: widget.child,
    );
  }
}

/// Shared glass surface for context menus, including anchored roll-down menus.
/// One clipped blur per panel; interactive children retain their focus nodes.
class GlassMenuSurface extends StatelessWidget {
  const GlassMenuSurface({super.key, required this.child, this.radius = 20});

  final Widget child;
  final double radius;

  static ThemeData? _menuThemeFor, _menuTheme;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassMenuScope>() != null;

  /// Rows under a [GlassRowScope] (Settings pages): only the focused one
  /// gets the glass, idle rows stay clear.
  static bool quietRows(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassMenuScope>()?.quiet ??
      false;

  /// [quiet]: an idle row draws nothing (long Settings lists), only the
  /// focused / selected one gets the glass.
  static BoxDecoration rowDecoration(BuildContext context,
      {required bool focused,
      bool selected = false,
      double radius = 10,
      bool quiet = false}) {
    final accent = Theme.of(context).colorScheme.primary;
    final lit = focused || selected;
    if (quiet && !lit) {
      // Same border width as the lit row, so focus never shifts the text.
      return BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.transparent, width: 2));
    }
    return RefinedFinish.decorate(
        context,
        BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: lit ? 0.16 : 0.045),
              accent.withValues(alpha: lit ? 0.16 : 0.018),
              Colors.black.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
              color: focused ? accent : Colors.white.withValues(alpha: 0.08),
              width: 2),
        ),
        focused: focused);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(radius);
    Color readableAccent(Color color) {
      if (theme.brightness != Brightness.light ||
          color.computeLuminance() >= 0.18) {
        return color;
      }
      final hsl = HSLColor.fromColor(color);
      return hsl.withLightness(hsl.saturation < 0.05 ? 1 : 0.72).toColor();
    }

    final accent = readableAccent(theme.colorScheme.primary);
    // Menus retain the chosen accent on both light and dark app themes.
    // Same app theme in = the same menu theme out: its button styles hold
    // closures, so a fresh copy never compares equal and `Theme` rebuilt
    // every row under it on any rebuild (CLAUDE.md §10 rules 2 / 8).
    final menuTheme = identical(theme, _menuThemeFor)
        ? _menuTheme!
        : _menuTheme = theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              brightness: Brightness.dark,
              primary: accent,
              onPrimary: ThemeData.estimateBrightnessForColor(accent) ==
                      Brightness.light
                  ? Colors.black
                  : Colors.white,
              primaryContainer:
                  readableAccent(theme.colorScheme.primaryContainer),
              secondary: readableAccent(theme.colorScheme.secondary),
              tertiary: readableAccent(theme.colorScheme.tertiary),
              surface: const Color(0xFF17191F),
              onSurface: Colors.white,
              onSurfaceVariant: Colors.white70,
            ),
            textTheme: theme.textTheme
                .apply(bodyColor: Colors.white, displayColor: Colors.white),
            iconTheme: theme.iconTheme.copyWith(color: Colors.white70),
            disabledColor: Colors.white38,
            dividerColor: Colors.white12,
          );
    _menuThemeFor = theme;
    return _GlassMenuScope(
      child: Theme(
        data: menuTheme,
        child: RefinedFinishBackdrop(
          translucent: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              // No blurred shadow over moving video (see GlassBlur).
              boxShadow: GlassBlur.live
                  ? const [
                      BoxShadow(
                          color: Colors.black54,
                          blurRadius: 28,
                          offset: Offset(0, 10)),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: _FrostedBackdrop(
                child: Material(
                  type: MaterialType.transparency,
                  child: Ink(
                    decoration: BoxDecoration(
                      // Darker without the blur: the video behind stays
                      // quiet under the text.
                      color: GlassBlur.live
                          ? const Color(0xC20D1016)
                          : const Color(0xEB0D1016),
                      borderRadius: borderRadius,
                      border: Border.all(color: Colors.white24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          accent.withValues(alpha: 0.045),
                          Colors.black.withValues(alpha: 0.10),
                        ],
                        stops: const [0, 0.35, 1],
                      ),
                    ),
                    // Own layer: a row's focus step repaints only the rows,
                    // never the panel's frost, gradient and shadow.
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMenuScope extends InheritedWidget {
  const _GlassMenuScope({required super.child, this.quiet = false});
  final bool quiet;
  @override
  bool updateShouldNotify(_GlassMenuScope oldWidget) =>
      quiet != oldWidget.quiet;
}

/// Rows below take the glass row look ([GlassMenuSurface.of] is true)
/// without a blurred panel of their own: Settings pages, which sit on
/// [GlassPanel]s over an already blurred backdrop.
class GlassRowScope extends StatelessWidget {
  const GlassRowScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _GlassMenuScope(quiet: true, child: child);
}

/// The glass focus outline around any focusable child that has no focus
/// look of its own (a plain `ListTile`, a dropdown): Settings dropped the
/// theme's gold focus wash (owner, 2026-11-10: "the pastel selector").
/// The wrapper itself never takes focus (CLAUDE.md §10).
class GlassFocusFrame extends StatefulWidget {
  const GlassFocusFrame({super.key, required this.child, this.radius = 10});

  final Widget child;
  final double radius;

  @override
  State<GlassFocusFrame> createState() => _GlassFocusFrameState();
}

class _GlassFocusFrameState extends State<GlassFocusFrame> {
  bool _focused = false;
  final _node = FocusNode(canRequestFocus: false, skipTraversal: true);

  @override
  void initState() {
    super.initState();
    // Rebuilt around a child that already has focus (a list row moved to
    // another index keeps its button's node): no focus change comes, so
    // read it once laid out, or the outline stays off until the next key
    // (Customize Media Hub, owner 2026-11-12).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _node.hasFocus != _focused) {
        setState(() => _focused = _node.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _node,
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) {
          if (f != _focused) setState(() => _focused = f);
        },
        child: Container(
          decoration: GlassMenuSurface.rowDecoration(context,
              focused: _focused, radius: widget.radius, quiet: true),
          child: InkLayer(child: widget.child),
        ),
      );
}

/// A Settings pane: dark see-through glass with a light top edge, the same
/// recipe as [GlassMenuSurface] minus the blur (its backdrop is already a
/// blurred wallpaper or a flat glow, so a blur would cost GPU for nothing
/// on a weak box).
class GlassPanel extends StatelessWidget {
  const GlassPanel(
      {super.key,
      required this.child,
      this.radius = 20,
      this.padding,
      this.blur = false,
      this.dim});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  /// Blur what is behind (a panel floating over another page). Off on a
  /// panel over the Settings backdrop, which is already blurred. Opened
  /// through [GlassFrost] (`openSettingsPage`), that is the page captured
  /// and blurred once, not a live BackdropFilter.
  final bool blur;

  /// The barrier color over the page behind: painted over the capture so
  /// the frost is as dark as the live blur was.
  final Color? dim;

  static const _base = Color(0xBF0D1016);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final borderRadius = BorderRadius.circular(radius);
    Widget glass = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white24),
        // A gradient replaces BoxDecoration.color, so the dark base is
        // blended into each stop.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.12), _base),
            Color.alphaBlend(accent.withValues(alpha: 0.04), _base),
            Color.alphaBlend(Colors.black.withValues(alpha: 0.10), _base),
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        // The content on its own layer: a focus step inside doesn't redraw
        // the panel's gradient and shadow (weak boxes, CLAUDE.md §10).
        child: RepaintBoundary(
            child: padding == null
                ? child
                : Padding(padding: padding!, child: child)),
      ),
    );
    if (blur) glass = _FrostedBackdrop(dim: dim, child: glass);
    return RefinedFinishBackdrop(
      translucent: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: ClipRRect(borderRadius: borderRadius, child: glass),
      ),
    );
  }
}

/// A context menu with a fixed title/actions and a bounded, scrollable body.
/// Options are built together so autofocus can reach a selected item offscreen.
class GlassMenuDialog extends StatelessWidget {
  const GlassMenuDialog({
    super.key,
    this.title,
    this.children,
    this.content,
    this.actions,
    this.titlePadding = const EdgeInsets.fromLTRB(20, 18, 20, 12),
    this.contentPadding = const EdgeInsets.fromLTRB(8, 8, 8, 12),
    this.actionsPadding = const EdgeInsets.fromLTRB(12, 0, 12, 12),
    this.insetPadding =
        const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.alignment,
    this.maxWidth = 560,
    this.scrollable = true,
  })  : assert(children == null || content == null),
        child = null;

  /// Existing specialised menus keep their own layout, size and scrolling.
  const GlassMenuDialog.custom({
    super.key,
    required this.child,
    this.insetPadding =
        const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.alignment,
    this.maxWidth = 760,
  })  : title = null,
        children = null,
        content = null,
        actions = null,
        titlePadding = EdgeInsets.zero,
        contentPadding = EdgeInsets.zero,
        actionsPadding = EdgeInsets.zero,
        scrollable = false;

  final Widget? title;
  final List<Widget>? children;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? child;
  final EdgeInsetsGeometry titlePadding, contentPadding, actionsPadding;
  final EdgeInsets insetPadding;
  final AlignmentGeometry? alignment;
  final double maxWidth;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = content ??
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children ?? const [],
        );
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      alignment: alignment,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: GlassMenuSurface(
          child: child ??
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    Padding(
                      padding: titlePadding,
                      child: Semantics(
                        namesRoute: true,
                        child: DefaultTextStyle.merge(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800),
                          child: title!,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                  ],
                  if (content != null || children != null)
                    Flexible(
                      child: Padding(
                        padding: contentPadding,
                        child: scrollable
                            ? SingleChildScrollView(child: body)
                            : body,
                      ),
                    ),
                  if (actions?.isNotEmpty ?? false)
                    Padding(
                      padding: actionsPadding,
                      child: OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 8,
                        overflowSpacing: 8,
                        children: actions!,
                      ),
                    ),
                ],
              ),
        ),
      ),
    );
  }
}
