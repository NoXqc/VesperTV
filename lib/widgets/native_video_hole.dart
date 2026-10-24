import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native video surface (beta, Android, [AppPreferences.nativeVideoSurface]).
///
/// With it on, MainActivity starts Flutter transparent and the vendored
/// player draws the main video into one plain Android SurfaceView *behind*
/// Flutter (`NativeVideoSurface.java`), like a native player — no platform
/// view around it. A [NativeVideoHole] stands where the video goes: it clears
/// its rect to transparent and, after every frame, the topmost visible hole's
/// rect (physical pixels) and player id go to the native side, which moves
/// the SurfaceView there. No hole on screen = the surface is moved off screen
/// (kept alive, so playback isn't disturbed).
///
/// Why: through the platform view AMD's Fire TV Cube showed 4K HDR10 as
/// washed-out 1080p (LOG-CFN2FE) and Sam's NVIDIA Shield green flicker under
/// the guide. Every step logs `NativeSurface:` lines for Send log.
class NativeVideoSurface {
  NativeVideoSurface._();

  /// Read once at startup (main.dart): the transparent Flutter view is fixed
  /// at launch, so a change in Settings applies after a restart.
  static bool active = false;

  static const _channel = MethodChannel('vespertv/native_surface');
  static final _holes = <_NativeVideoHoleState>[];
  static bool _hooked = false;
  static int? _attached;
  static Rect? _sentRect;
  static bool _shown = false;
  static Timer? _diagTimer;

  static void _register(_NativeVideoHoleState hole) {
    _holes.add(hole);
    if (!_hooked) {
      _hooked = true;
      // Registered after the renderer's own callback, so it runs once layout
      // and paint for the frame are done.
      SchedulerBinding.instance.addPersistentFrameCallback(_afterFrame);
    }
    SchedulerBinding.instance.scheduleFrame();
  }

  static void _unregister(_NativeVideoHoleState hole) {
    _holes.remove(hole);
    SchedulerBinding.instance.scheduleFrame();
  }

  static void _afterFrame(Duration _) {
    _NativeVideoHoleState? top;
    // Last registered visible hole wins (a pushed full-screen player over the
    // guide's preview). Holes on routes covered by an opaque route have their
    // tickers off.
    for (final hole in _holes.reversed) {
      if (hole.visible) {
        top = hole;
        break;
      }
    }
    final box = top?.renderBox;
    if (top == null || box == null || !box.attached || !box.hasSize) {
      if (_shown) {
        _shown = false;
        _sentRect = null;
        _invoke('hide');
      }
      return;
    }
    final id = top.widget.playerId;
    if (id != _attached) {
      _attached = id;
      debugPrint('NativeSurface: attach player $id');
      _invoke('attach', {'playerId': id});
      _diagTimer?.cancel();
      _diagTimer = Timer(const Duration(seconds: 5), logDiagnostics);
    }
    final dpr = top.devicePixelRatio;
    final origin = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      (origin.dx * dpr).roundToDouble(),
      (origin.dy * dpr).roundToDouble(),
      (box.size.width * dpr).roundToDouble(),
      (box.size.height * dpr).roundToDouble(),
    );
    if (rect == _sentRect && _shown) return;
    if (_sentRect?.size != rect.size || !_shown) {
      debugPrint('NativeSurface: hole ${rect.width.toInt()}x'
          '${rect.height.toInt()} at ${rect.left.toInt()},${rect.top.toInt()}'
          ' (dpr $dpr)');
    }
    _sentRect = rect;
    _shown = true;
    _invoke('setRect', {
      'left': rect.left.toInt(),
      'top': rect.top.toInt(),
      'width': rect.width.toInt(),
      'height': rect.height.toInt(),
    });
  }

  static void _invoke(String method, [Map<String, Object?>? args]) {
    unawaited(_channel.invokeMethod<Object?>(method, args).catchError((e) {
      debugPrint('NativeSurface: $method failed: $e');
      return null;
    }));
  }

  /// Writes what the native side knows (decoder, input format incl. HDR
  /// colour info, video/surface size, display mode + HDR support, dropped
  /// frames, tunneling) into the session log — logcat rolls over, this
  /// doesn't. Runs 5 s after each attach.
  static Future<void> logDiagnostics() async {
    try {
      final d = await _channel.invokeMapMethod<String, Object?>('diagnostics');
      if (d == null) return;
      for (final e in d.entries) {
        debugPrint('NativeSurface: ${e.key} = ${e.value}');
      }
    } catch (e) {
      debugPrint('NativeSurface: diagnostics failed: $e');
    }
  }
}

/// Where the main player's video shows when [NativeVideoSurface.active]:
/// a transparent hole the native SurfaceView behind Flutter shows through.
class NativeVideoHole extends StatefulWidget {
  const NativeVideoHole({super.key, required this.playerId});

  /// The plugin's player id (`VideoPlayerHdrController.textureId`).
  final int playerId;

  @override
  State<NativeVideoHole> createState() => _NativeVideoHoleState();
}

class _NativeVideoHoleState extends State<NativeVideoHole> {
  final _key = GlobalKey();
  bool _tickerOn = true;
  double devicePixelRatio = 1;

  RenderBox? get renderBox =>
      _key.currentContext?.findRenderObject() as RenderBox?;

  bool get visible => mounted && _tickerOn;

  @override
  void initState() {
    super.initState();
    NativeVideoSurface._register(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Off on a route covered by an opaque one (and in hidden Visibility).
    _tickerOn = TickerMode.valuesOf(context).enabled;
    devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    NativeVideoSurface._unregister(this);
    super.dispose();
  }

  // Own repaint boundary: the clear must be its own tiny picture, drawn onto
  // the frame after what's behind it. Inside a bigger cached picture it
  // would only clear that picture's pixels.
  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: _Hole(key: _key));
}

class _Hole extends LeafRenderObjectWidget {
  const _Hole({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHole();
}

class _RenderHole extends RenderBox {
  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas
        .drawRect(offset & size, Paint()..blendMode = BlendMode.clear);
  }
}
