import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../services/desktop_mini_player.dart';
import '../services/playback_service.dart';
import '../services/trailer_service.dart';
import 'detail_header.dart';

class TrailerButton extends StatefulWidget {
  const TrailerButton(
      {super.key,
      required this.request,
      required this.focusNode,
      this.scale = 1,
      this.onFocused,
      this.service,
      this.available,
      this.open});
  final TrailerRequest request;
  final FocusNode focusNode;
  final double scale;
  final VoidCallback? onFocused;
  final TrailerService? service;
  final Future<bool> Function(Uri)? available;
  final Future<bool> Function(Uri)? open;
  @override
  State<TrailerButton> createState() => _TrailerButtonState();
}

class _TrailerButtonState extends State<TrailerButton> {
  Uri? _url;
  int _generation = 0;
  bool _launching = false;
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(TrailerButton old) {
    super.didUpdateWidget(old);
    if (old.request.cacheKey != widget.request.cacheKey) {
      _url = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final generation = ++_generation;
    try {
      final url = await (widget.service ?? TrailerService.instance)
          .resolve(widget.request);
      final canOpen =
          url != null && await (widget.available ?? canLaunchUrl)(url);
      if (mounted && generation == _generation) {
        setState(() => _url = canOpen ? url : null);
      }
    } catch (_) {/* Hidden without an external handler. */}
  }

  Future<void> _launch() async {
    final url = _url;
    if (url == null || _launching) return;
    _launching = true;
    try {
      if (Platform.isWindows) {
        await DesktopMiniPlayer.instance.controller?.player.pause();
      } else {
        await context.read<PlaybackService>().controller?.pause();
      }
      final opened = await (widget.open?.call(url) ??
          launchUrl(url, mode: LaunchMode.externalApplication));
      if (!opened) throw StateError('No handler');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(tr('Unable to open trailer'))));
        widget.focusNode.requestFocus();
      }
    } finally {
      _launching = false;
    }
  }

  @override
  Widget build(BuildContext context) => _url == null
      ? const SizedBox.shrink()
      : DetailPillButton(
          focusNode: widget.focusNode,
          icon: Icons.movie_outlined,
          label: tr('Trailer'),
          scale: widget.scale,
          onFocused: widget.onFocused,
          onPressed: _launch,
        );
}
