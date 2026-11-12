import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../utils/refined_finish.dart';

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
}) =>
    showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black38,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    );

/// Shared glass surface for context menus, including anchored roll-down menus.
/// One clipped blur per panel; interactive children retain their focus nodes.
class GlassMenuSurface extends StatelessWidget {
  const GlassMenuSurface({super.key, required this.child, this.radius = 20});

  final Widget child;
  final double radius;

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
    final menuTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: accent,
        onPrimary:
            ThemeData.estimateBrightnessForColor(accent) == Brightness.light
                ? Colors.black
                : Colors.white,
        primaryContainer: readableAccent(theme.colorScheme.primaryContainer),
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
    return _GlassMenuScope(
      child: Theme(
        data: menuTheme,
        child: RefinedFinishBackdrop(
          translucent: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54,
                    blurRadius: 28,
                    offset: Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  type: MaterialType.transparency,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: const Color(0xC20D1016),
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
                    child: child,
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
  final _node =
      FocusNode(canRequestFocus: false, skipTraversal: true);

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
          child: widget.child,
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
      this.blur = false});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  /// Blur what is behind (a panel floating over another page). Off on a
  /// panel over the Settings backdrop, which is already blurred.
  final bool blur;

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
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
    if (blur) {
      glass = BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: glass);
    }
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
