import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/l10n.dart';

/// Computers: a horizontal row of posters the mouse can drag (hold the left
/// button and move) and page with floating arrows at both ends. The arrows
/// show while the pointer is over the row, and only toward a side with more
/// to see (owner, 2026-11-19: the TV's jump-to-the-left on every pick felt
/// weird with a mouse).
///
/// The drag is done here, not by the list's own Scrollable: Flutter starts a
/// mouse drag after 1 px (`computeHitSlop`), so a click with the smallest
/// hand movement became a drag and never opened the card. This one starts
/// after [kTouchSlop], the same distance at which the card's tap and the
/// hold menu's long press give up, so a press is either a click or a drag,
/// never both.
class DesktopRowScroller extends StatefulWidget {
  const DesktopRowScroller({
    super.key,
    required this.controller,
    required this.child,
    this.arrowTop = 0,
    this.arrowHeight,
    this.onNearEnd,
  });

  final ScrollController controller;
  final Widget child;

  /// The band the arrows centre on (the posters, not their titles).
  final double arrowTop;
  final double? arrowHeight;

  /// Less than one screen of the row left to the right: time to load more.
  final VoidCallback? onNearEnd;

  @override
  State<DesktopRowScroller> createState() => _DesktopRowScrollerState();
}

class _DesktopRowScrollerState extends State<DesktopRowScroller> {
  bool _hover = false;
  bool _canBack = false;
  bool _canForward = false;

  int? _pointer;
  Offset _downAt = Offset.zero;
  Drag? _drag;
  VelocityTracker? _velocity;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(DesktopRowScroller old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _drag?.cancel();
    super.dispose();
  }

  ScrollPosition? get _position {
    final c = widget.controller;
    return c.hasClients && c.positions.length == 1 ? c.position : null;
  }

  void _sync() {
    if (!mounted) return;
    final p = _position;
    if (p == null || !p.hasContentDimensions || !p.hasPixels) return;
    final back = p.pixels > p.minScrollExtent + 1;
    final forward = p.pixels < p.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
      } else {
        setState(() {
          _canBack = back;
          _canForward = forward;
        });
      }
    }
    if (p.extentAfter < p.viewportDimension) widget.onNearEnd?.call();
  }

  void _page(int direction) {
    final p = _position;
    if (p == null || !p.hasContentDimensions) return;
    final to = (p.pixels + direction * p.viewportDimension * 0.8)
        .clamp(p.minScrollExtent, p.maxScrollExtent);
    // Computers only, one screen at most per click: the rule against
    // animateTo (a long jump on a weak TV box froze it) is about remote
    // focus jumps, not this.
    widget.controller.animateTo(to,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic);
  }

  void _onDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse ||
        e.buttons & kPrimaryMouseButton == 0 ||
        _pointer != null) {
      return;
    }
    _pointer = e.pointer;
    _downAt = e.position;
    _velocity = VelocityTracker.withKind(e.kind)
      ..addPosition(e.timeStamp, e.position);
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    _velocity?.addPosition(e.timeStamp, e.position);
    final drag = _drag;
    if (drag == null) {
      if ((e.position - _downAt).distance <= kTouchSlop) return;
      final p = _position;
      if (p == null) return;
      setState(() {
        _drag = p.drag(
            DragStartDetails(
                globalPosition: e.position, sourceTimeStamp: e.timeStamp),
            () => _drag = null);
      });
      return;
    }
    drag.update(DragUpdateDetails(
      globalPosition: e.position,
      sourceTimeStamp: e.timeStamp,
      delta: Offset(e.delta.dx, 0),
      primaryDelta: e.delta.dx,
    ));
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    final speed = _velocity?.getVelocity().pixelsPerSecond.dx ?? 0;
    _drag?.end(DragEndDetails(
      velocity: Velocity(pixelsPerSecond: Offset(speed, 0)),
      primaryVelocity: speed,
    ));
    _endPointer();
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _drag?.cancel();
    _endPointer();
  }

  void _endPointer() {
    _pointer = null;
    _velocity = null;
    if (_drag != null || mounted) setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: _drag != null ? SystemMouseCursors.grabbing : MouseCursor.defer,
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: _onCancel,
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (n) {
                  if (n.depth == 0) _sync();
                  return false;
                },
                child: widget.child,
              ),
            ),
          ),
          _arrow(forward: false),
          _arrow(forward: true),
        ],
      ),
    );
  }

  Widget _arrow({required bool forward}) {
    final show = _hover && _drag == null && (forward ? _canForward : _canBack);
    final height = widget.arrowHeight;
    return Positioned(
      left: forward ? null : 4,
      right: forward ? 4 : null,
      top: widget.arrowTop,
      height: height,
      bottom: height == null ? 0 : null,
      child: IgnorePointer(
        ignoring: !show,
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Center(
            child: _RowArrow(
              forward: forward,
              onTap: () => _page(forward ? 1 : -1),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowArrow extends StatefulWidget {
  const _RowArrow({required this.forward, required this.onTap});

  final bool forward;
  final VoidCallback onTap;

  @override
  State<_RowArrow> createState() => _RowArrowState();
}

class _RowArrowState extends State<_RowArrow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: widget.forward ? tr('Next') : tr('Previous'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: _hover ? 0.85 : 0.65),
              border: Border.all(
                  color: _hover ? accent : Colors.white24, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 10),
              ],
            ),
            child: Icon(
              widget.forward
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              size: 30,
              color: _hover ? accent : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
