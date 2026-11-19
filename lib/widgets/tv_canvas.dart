import 'package:flutter/widgets.dart';

/// [box]'s rect in the root Overlay's coordinates, where menus and hints
/// are placed (Flutter's own menus measure the same way). Not the screen's:
/// on Apple TV the whole app is scaled up ([TvCanvas]), so screen pixels
/// are twice the app's; elsewhere the two are the same.
Rect overlayRectOf(BuildContext context, RenderBox box) {
  final overlay =
      Overlay.maybeOf(context, rootOverlay: true)?.context.findRenderObject();
  final ancestor = overlay is RenderBox && overlay.attached ? overlay : null;
  return box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
}

/// The whole app drawn on an Android TV box's canvas: a 1080p box reports
/// 960x540 (2x density) and every TV screen was laid out for it. Apple TV
/// reports its 1920x1080 points at 1x, so the same screens came out at half
/// size there: small text, 17 posters a row (Apple TV tester, 2026-11-19:
/// "font and display too small", "movie covers very small").
///
/// [child] lays out at [height] tall (960x540 on a 16:9 screen) and is
/// scaled up to the screen, like Sports Trak's own scaling. The
/// devicePixelRatio goes up by the same factor, so pictures decode at the
/// screen's real size and text is drawn at full resolution, not stretched.
class TvCanvas extends StatelessWidget {
  const TvCanvas({super.key, required this.child});

  /// Logical height of an Android TV box's screen.
  static const double height = 540;

  final Widget child;

  /// How much [screen] (logical size) is scaled up; 1 = drawn as is.
  static double scaleFor(Size screen) {
    final scale = screen.shortestSide / height;
    return scale > 1.05 ? scale : 1;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = scaleFor(mq.size);
    if (scale == 1) return child;
    final size = mq.size / scale;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: mq.copyWith(
            size: size,
            devicePixelRatio: mq.devicePixelRatio * scale,
            padding: mq.padding / scale,
            viewPadding: mq.viewPadding / scale,
            viewInsets: mq.viewInsets / scale,
            systemGestureInsets: mq.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
