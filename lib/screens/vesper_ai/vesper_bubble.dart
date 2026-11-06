import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/vesper_ai/vesper_ai.dart';

/// Vesper's bottom-of-screen line: a reply after the panel closed ("Playing
/// TSN 1"), or a message from a linked AI app. Never takes focus; gone after
/// a few seconds. Sits above the navigator (main.dart's builder Stack).
class VesperBubbleOverlay extends StatefulWidget {
  const VesperBubbleOverlay({super.key});

  @override
  State<VesperBubbleOverlay> createState() => _VesperBubbleOverlayState();
}

class _VesperBubbleOverlayState extends State<VesperBubbleOverlay> {
  VesperBubble? _shown;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    VesperAi.instance.bubble.addListener(_changed);
  }

  @override
  void dispose() {
    VesperAi.instance.bubble.removeListener(_changed);
    _hide?.cancel();
    super.dispose();
  }

  void _changed() {
    final b = VesperAi.instance.bubble.value;
    if (b == null) return;
    _hide?.cancel();
    setState(() => _shown = b);
    final seconds = (4 + b.text.length / 25).clamp(4, 12).round();
    _hide = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _shown = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _shown;
    final gold = Theme.of(context).colorScheme.primary;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 36,
      child: IgnorePointer(
        child: ExcludeFocus(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: b == null
                ? const SizedBox.shrink()
                : Center(
                    key: ValueKey(b),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.82),
                        shape: StadiumBorder(
                            side:
                                BorderSide(color: gold.withValues(alpha: 0.6))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, color: gold, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text.rich(
                                  TextSpan(children: [
                                    if (b.from != null)
                                      TextSpan(
                                          text: '${b.from}  ',
                                          style: TextStyle(
                                              color: gold,
                                              fontWeight: FontWeight.w600)),
                                    TextSpan(text: b.text),
                                  ]),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
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
