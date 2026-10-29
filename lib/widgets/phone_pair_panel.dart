import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/phone_pairing_service.dart';
import 'live_resume_hint.dart';
import '../l10n/l10n.dart';

/// The middle pane of Add Playlist > "From my phone": a QR code to scan,
/// what to do, and a switch to the relay code for a phone that isn't on the
/// TV's Wi-Fi. Owns one [PhonePairingSession] for as long as it's on screen.
class PhonePairPanel extends StatefulWidget {
  const PhonePairPanel({
    super.key,
    required this.toggleFocusNode,
    required this.onResult,
    this.kind = PairingKind.playlist,
  });

  /// [PairingKind.link]: the phone shows one link box instead of the
  /// playlist form (Settings > Archive sources); [PairingKind.mediaServer]
  /// a Jellyfin / Emby sign-in. Both are Wi-Fi only (see [PairingKind]).
  final PairingKind kind;

  /// The "Phone not on this Wi-Fi?" button (Cancel for a Wi-Fi-only kind)
  /// — the screen's Right-arrow target into this pane, and its focus.
  final FocusNode toggleFocusNode;
  final ValueChanged<PairingResult> onResult;

  @override
  State<PhonePairPanel> createState() => _PhonePairPanelState();
}

class _PhonePairPanelState extends State<PhonePairPanel> {
  PhonePairingSession? _session;
  StreamSubscription<PairingResult>? _sub;
  bool _starting = true;
  bool _relay = false;
  bool _expired = false;

  /// The "Hold > to resume" pill sat on top of the steps.
  late final VoidCallback _showResumeHint;

  @override
  void initState() {
    super.initState();
    _showResumeHint = LiveResumeHint.hideWhileMounted();
    unawaited(_start());
  }

  Future<void> _start() async {
    await _sub?.cancel();
    await _session?.stop();
    final session = PhonePairingSession(kind: widget.kind);
    _session = session;
    setState(() {
      _starting = true;
      _expired = false;
    });
    _sub = session.results.listen(widget.onResult, onDone: () {
      if (mounted && identical(_session, session)) {
        setState(() => _expired = true);
      }
    });
    await session.start();
    if (!mounted || !identical(_session, session)) return;
    setState(() {
      _starting = false;
      // No LAN address (unusual) — only the relay can work (not for a
      // Wi-Fi-only kind: the relay's page has no such form).
      if (session.lanUrl == null && !widget.kind.isWifiOnly) _relay = true;
    });
    if (_relay) session.startRelayPolling();
  }

  void _toggle() {
    final session = _session;
    if (session == null) return;
    if (_expired) {
      unawaited(_start());
      return;
    }
    if (session.lanUrl == null) return;
    setState(() => _relay = !_relay);
    if (_relay) {
      session.startRelayPolling();
    } else {
      session.stopRelayPolling();
    }
  }

  @override
  void dispose() {
    _showResumeHint();
    unawaited(_sub?.cancel());
    unawaited(_session?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final theme = Theme.of(context);
    final url =
        session == null ? null : (_relay ? session.relayUrl : session.lanUrl);
    final muted = theme.textTheme.bodySmall?.copyWith(color: Colors.white60);

    Widget code;
    if (_starting || url == null) {
      code = const SizedBox(
          width: 220,
          height: 220,
          child: Center(child: CircularProgressIndicator()));
    } else if (_expired) {
      code = SizedBox(
        width: 220,
        height: 220,
        child: Center(
          child: Text(tr('Code expired'), style: theme.textTheme.titleMedium),
        ),
      );
    } else {
      code = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: QrImageView(
          data: url,
          size: 196,
          // A long relay URL needs a denser code; M keeps it scannable
          // off a TV across the room.
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          backgroundColor: Colors.white,
        ),
      );
    }

    final isLink = widget.kind.isLink;
    final isKey = widget.kind == PairingKind.apiKey;
    final saves = isKey || widget.kind == PairingKind.poster;
    final isServer = widget.kind == PairingKind.mediaServer;
    final isPhoto = widget.kind == PairingKind.photo;
    final wifiOnly = widget.kind.isWifiOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Add from your phone'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          isPhoto
              ? tr('Scan with your phone to add a photo')
              : isKey
                  ? tr(
                      'Typing a key with a remote is painful. Scan this code with your phone camera and paste the key there — it appears here for you to check and save.')
                  : saves
                      ? tr(
                          'Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and save.')
                      : isLink
                          ? tr(
                              'Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and add.')
                          : isServer
                              ? tr(
                                  'Typing a server address and password with a remote is painful. Scan this code with your phone camera and sign in there — the details appear here for you to check and connect.')
                              : tr(
                                  'Typing a long password with a remote is painful. Scan this code with your phone camera and fill in the form there — it appears here for you to check and add.'),
          style: muted,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
            builder: (context, limits) => Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  children: [
                    code,
                    SizedBox(
                      width: limits.maxWidth < 520
                          ? limits.maxWidth
                          : limits.maxWidth - 240,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Step(
                              n: 1,
                              text: _relay
                                  ? tr(
                                      'Scan with your phone (mobile data is fine).')
                                  : tr(
                                      'Connect your phone to the same Wi-Fi as this TV, then scan.')),
                          _Step(
                              n: 2,
                              text: isPhoto
                                  ? tr('Choose a photo and tap Send to TV.')
                                  : isKey
                                      ? tr('Paste the key and tap Send to TV.')
                                      : isLink
                                          ? tr(
                                              'Paste the link and tap Send to TV.')
                                          : tr(
                                              'Fill in the form and tap Send to TV.')),
                          _Step(
                              n: 3,
                              text: isPhoto
                                  ? tr('Your photo appears here automatically.')
                                  : saves
                                      ? tr('Check it here, then press Save.')
                                      : isLink
                                          ? tr(
                                              'Check the link here, then press Add.')
                                          : isServer
                                              ? tr(
                                                  'Check the details here, then press Connect.')
                                              : tr(
                                                  'Check the details here, then press Add Playlist.')),
                          const SizedBox(height: 12),
                          if (!_starting && !_expired)
                            Row(
                              children: [
                                const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                const SizedBox(width: 10),
                                Text(tr('Waiting for your phone…'),
                                    style: muted),
                              ],
                            ),
                          if (!_relay && url != null && !_expired) ...[
                            const SizedBox(height: 10),
                            Text(tr('Or open on the phone:'), style: muted),
                            SelectableText(url,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 13)),
                          ],
                          if (_relay)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                tr('Your details are encrypted on the phone; the relay only passes along scrambled data and deletes it.'),
                                style: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                )),
        const SizedBox(height: 16),
        // Wi-Fi-only kinds: no relay code to switch to — the button just
        // leaves (it's still the screen's focus target, CLAUDE.md §10).
        if (wifiOnly && !_expired)
          OutlinedButton.icon(
            focusNode: widget.toggleFocusNode,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
            label: Text(tr('Cancel')),
          )
        else
          OutlinedButton.icon(
            focusNode: widget.toggleFocusNode,
            onPressed: _starting ? null : _toggle,
            icon: Icon(_expired
                ? Icons.refresh
                : (_relay ? Icons.wifi : Icons.signal_cellular_alt)),
            label: Text(_expired
                ? tr('New code')
                : (_relay
                    ? tr('Phone on this Wi-Fi? Use the Wi-Fi code')
                    : tr('Phone not on this Wi-Fi? Use the other code'))),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: gold),
            child: Text('$n',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
