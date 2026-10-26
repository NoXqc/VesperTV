import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import '../utils/route_observer.dart';

/// Keeps the existing fullscreen player mounted while Android resizes it.
/// Only the visible phone player owns the bridge; browsing/pause disables PiP.
class PhonePictureInPicture extends StatefulWidget {
  const PhonePictureInPicture({
    super.key,
    required this.controller,
    required this.isTelevision,
    required this.builder,
  });

  final VideoPlayerHdrController? controller;
  final bool isTelevision;
  final Widget Function(BuildContext context, bool inPictureInPicture) builder;

  @override
  State<PhonePictureInPicture> createState() => _PhonePictureInPictureState();
}

class _PhonePictureInPictureState extends State<PhonePictureInPicture>
    with RouteAware {
  static const _channel = MethodChannel('vespertv/phone_pip');
  static _PhonePictureInPictureState? _owner;
  PageRoute<void>? _route;
  bool _visible = true;
  bool _active = false;
  String? _lastConfiguration;

  bool get _phone =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !widget.isTelevision;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route && route is PageRoute<void>) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    _visible = route?.isCurrent ?? true;
    _sync();
  }

  @override
  void didUpdateWidget(PhonePictureInPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_sync);
      widget.controller?.addListener(_sync);
    }
    _sync();
  }

  @override
  void didPushNext() {
    _visible = false;
    _sync();
  }

  @override
  void didPopNext() {
    _visible = true;
    _sync();
  }

  void _sync() {
    if (!_phone) {
      _release();
      return;
    }
    if (_visible && _owner != this) {
      _owner = this;
      _lastConfiguration = null;
      _channel.setMethodCallHandler(_onNative);
    }
    if (_owner != this) return;
    final value = widget.controller?.value;
    final enabled = _visible &&
        value != null &&
        value.isInitialized &&
        value.isPlaying &&
        !value.hasError;
    final aspect = value?.aspectRatio ?? (16 / 9);
    final configuration = '$enabled:$aspect';
    if (_lastConfiguration == configuration) return;
    _lastConfiguration = configuration;
    unawaited(_configure(enabled, aspect));
  }

  Future<void> _configure(bool enabled, double aspect) async {
    try {
      await _channel.invokeMethod<void>(
          'configure', {'enabled': enabled, 'aspect': aspect});
    } on PlatformException {
      // PiP may be unavailable or disabled in Android's per-app settings.
    } on MissingPluginException {
      // Older/unsupported platform builds continue ordinary playback.
    }
  }

  Future<void> _onNative(MethodCall call) async {
    if (!mounted || _owner != this) return;
    if (call.method == 'modeChanged') {
      setState(() => _active = call.arguments == true);
    } else if (call.method == 'stopped') {
      await widget.controller?.pause();
    }
  }

  void _release() {
    if (_owner != this) return;
    _owner = null;
    _channel.setMethodCallHandler(null);
    unawaited(_configure(false, 16 / 9));
    _lastConfiguration = null;
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    widget.controller?.removeListener(_sync);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _active);
}
