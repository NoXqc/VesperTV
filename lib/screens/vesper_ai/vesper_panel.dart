import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/vesper_ai/vesper_ai.dart';
import '../../services/vesper_ai/voice_input.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'phone_mic_sheet.dart';
import '../../utils/refined_finish.dart';

/// Opens the Vesper panel over [navigator]'s current screen (the remote's
/// voice button, the mic buttons, the assistant launch). [listen] starts
/// the microphone at once; [text] is asked at once instead (the phone).
Future<void> showVesperPanel(NavigatorState navigator,
    {bool listen = true, String? text}) {
  if (VesperPanel._open) return Future.value();
  return navigator.push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black38,
    barrierLabel: 'Vesper AI',
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, __, ___) => VesperPanel(listen: listen, text: text),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  ));
}

/// The bottom card: what was heard, Vesper's answer, Talk / Type / Phone.
/// iPhone: microphone and speech recognition are allowed in its own
/// Settings app, not Android's.
String _iosMicDenied() => tr(
    'VesperTV may not use the microphone. Allow Microphone and Speech Recognition in Settings > VesperTV, or type instead.');

extension on String {
  String ifNotIos(String Function() ios) => Platform.isIOS ? ios() : this;
}

class VesperPanel extends StatefulWidget {
  const VesperPanel({super.key, this.listen = true, this.text});

  final bool listen;
  final String? text;

  static bool _open = false;

  @override
  State<VesperPanel> createState() => _VesperPanelState();
}

enum _Stage { idle, listening, thinking, answered }

class _VesperPanelState extends State<VesperPanel> {
  final _talkFocus = FocusNode(debugLabel: 'vesper-talk');
  final _typeFocus = FocusNode(debugLabel: 'vesper-type');
  final _field = TextEditingController();

  _Stage _stage = _Stage.idle;
  String _heard = '';
  String _answer = '';
  bool _voice = false;
  double _level = 0;
  StreamSubscription<VoiceEvent>? _listening;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    VesperPanel._open = true;
    unawaited(_start());
  }

  @override
  void dispose() {
    VesperPanel._open = false;
    _autoClose?.cancel();
    _listening?.cancel();
    unawaited(VoiceInput.instance.cancel());
    _talkFocus.dispose();
    _typeFocus.dispose();
    _field.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _voice = await VoiceInput.instance.available;
    if (!mounted) return;
    setState(() {});
    final text = widget.text?.trim();
    if (text != null && text.isNotEmpty) {
      _talkFocus.requestFocus();
      await _ask(text);
      return;
    }
    if (_voice && widget.listen) {
      _talkFocus.requestFocus();
      await _listen();
    } else {
      (_voice ? _talkFocus : _typeFocus).requestFocus();
    }
  }

  Future<void> _listen() async {
    _autoClose?.cancel();
    await _listening?.cancel();
    if (!await VoiceInput.instance.ensurePermission()) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.answered;
        _answer =
            tr('VesperTV may not use the microphone. Allow it in Android Settings > Apps > VesperTV, or type instead.')
                .ifNotIos(_iosMicDenied);
      });
      return;
    }
    if (!mounted) return;
    unawaited(VoiceInput.instance.stopSpeaking());
    setState(() {
      _stage = _Stage.listening;
      _heard = '';
      _answer = '';
      _level = 0;
    });
    var finalText = '';
    _listening = VoiceInput.instance.listen().listen((e) {
      if (!mounted) return;
      switch (e.type) {
        case 'partial':
          setState(() => _heard = e.text);
        case 'final':
          finalText = e.text;
          setState(() => _heard = e.text);
        case 'level':
          setState(() => _level = ((e.level + 2) / 12).clamp(0.0, 1.0));
        case 'error':
          setState(() {
            _stage = _Stage.answered;
            _answer = switch (e.code) {
              'nomatch' => tr('I did not hear anything.'),
              'network' => tr('Voice needs the internet.'),
              'permission' =>
                tr('VesperTV may not use the microphone. Allow it in Android Settings > Apps > VesperTV, or type instead.')
                    .ifNotIos(_iosMicDenied),
              'busy' => tr('The microphone is busy. Try again.'),
              _ => tr(
                  'Voice is not available on this device. Type, or talk from your phone.'),
            };
          });
      }
    }, onDone: () {
      if (!mounted) return;
      if (finalText.trim().isNotEmpty) {
        unawaited(_ask(finalText));
      } else if (_stage == _Stage.listening) {
        setState(() {
          _stage = _Stage.answered;
          _answer = tr('I did not hear anything.');
        });
      }
    });
  }

  Future<void> _ask(String text) async {
    _autoClose?.cancel();
    setState(() {
      _stage = _Stage.thinking;
      _heard = text;
      _answer = '';
    });
    final route = ModalRoute.of(context);
    final reply = await VesperAi.instance.ask(text);
    // An action (play, open) closed every screen above the home, this panel
    // included: the answer goes to the bottom-of-screen line instead.
    if (!mounted || !(route?.isActive ?? false)) {
      if (reply.text.isNotEmpty) VesperAi.instance.showBubble(reply.text);
      return;
    }
    if (reply.acted) {
      Navigator.of(context).pop();
      if (reply.text.isNotEmpty) VesperAi.instance.showBubble(reply.text);
      return;
    }
    setState(() {
      _stage = _Stage.answered;
      _answer = reply.text;
    });
    unawaited(VoiceInput.instance.speakIfWanted(reply.text));
    _autoClose = Timer(const Duration(seconds: 20), () {
      if (mounted && _stage == _Stage.answered) {
        Navigator.of(context).maybePop();
      }
    });
  }

  void _submitTyped() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    _field.clear();
    _talkFocus.requestFocus();
    unawaited(_ask(text));
  }

  Future<void> _phone() async {
    _autoClose?.cancel();
    await showPhoneMicSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gold = scheme.primary;
    final width = MediaQuery.sizeOf(context).width;
    final status = switch (_stage) {
      _Stage.idle => _voice
          ? tr('Press Talk and say what you want to watch.')
          : tr('Type what you want, or talk from your phone.'),
      _Stage.listening => tr('Listening...'),
      _Stage.thinking => tr('Thinking...'),
      _Stage.answered => _answer,
    };
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        // A pushed route without a Scaffold: nothing else makes room for
        // the on-screen keyboard (it hid the typed text on an iPhone).
        padding: EdgeInsets.fromLTRB(16, 16, 16,
            (width < 600 ? 16 : 40) + MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              enabled: GlassBlur.live,
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Material(
                color: Colors.black.withValues(alpha: 0.78),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: gold.withValues(alpha: 0.55)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        _Orb(
                            active: _stage == _Stage.listening,
                            thinking: _stage == _Stage.thinking,
                            level: _level,
                            color: gold),
                        const SizedBox(width: 12),
                        Text('Vesper',
                            style: TextStyle(
                                color: gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6)),
                        const Spacer(),
                        if (!VesperAi.instance.hasOwnAi)
                          Text(tr('Built-in commands'),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                      ]),
                      if (_heard.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('"$_heard"',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w500)),
                      ],
                      const SizedBox(height: 10),
                      Text(status,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _stage == _Stage.answered
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: _stage == _Stage.answered ? 18 : 15,
                              height: 1.3)),
                      const SizedBox(height: 16),
                      TvTextFieldGate(
                        focusNode: _typeFocus,
                        builder: (context, readOnly) => TextField(
                          controller: _field,
                          focusNode: _typeFocus,
                          readOnly: readOnly,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitTyped(),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: tr('Or type here'),
                            prefixIcon: const Icon(Icons.keyboard, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if (_voice)
                            FilledButton.icon(
                              focusNode: _talkFocus,
                              onPressed: _stage == _Stage.listening
                                  ? () => VoiceInput.instance.stop()
                                  : _listen,
                              icon: Icon(_stage == _Stage.listening
                                  ? Icons.stop
                                  : Icons.mic),
                              label: Text(_stage == _Stage.listening
                                  ? tr('Done')
                                  : tr('Talk')),
                            ),
                          OutlinedButton.icon(
                            focusNode: _voice ? null : _talkFocus,
                            onPressed: _phone,
                            icon: const Icon(Icons.smartphone),
                            label: Text(tr('Talk from my phone')),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: Text(tr('Close')),
                          ),
                        ],
                      ),
                      if (!VesperAi.instance.hasOwnAi &&
                          _stage == _Stage.idle) ...[
                        const SizedBox(height: 10),
                        Text(tr('Try: "play TSN 1", "what\'s on", "pause", "go back 30 seconds", "open the movies", "put on the Habs game".'),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ],
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

/// The breathing gold orb: bigger with the voice level while listening,
/// pulsing while thinking.
class _Orb extends StatefulWidget {
  const _Orb(
      {required this.active,
      required this.thinking,
      required this.level,
      required this.color});
  final bool active;
  final bool thinking;
  final double level;
  final Color color;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Orb old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Pulses only while thinking: a pulse that never stopped drew a frame
  /// 60 times a second, under a blur, for as long as the panel was open
  /// (frame cost audit, 2026-11-13).
  void _sync() {
    if (widget.thinking && !widget.active) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final grow = widget.active
            ? widget.level
            : widget.thinking
                ? _pulse.value * 0.6
                : 0.0;
        return SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 24 + 14 * grow,
              height: 24 + 14 * grow,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white,
                  widget.color,
                  widget.color.withValues(alpha: 0.2),
                ], stops: const [
                  0.0,
                  0.45,
                  1.0
                ]),
                boxShadow: [
                  BoxShadow(
                      color: widget.color.withValues(alpha: 0.5 + 0.4 * grow),
                      blurRadius: 10 + 14 * grow),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 14, color: Colors.black87),
            ),
          ),
        );
      },
    );
  }
}
