import 'package:flutter/material.dart';

import '../../services/phone_pairing_service.dart';
import '../../widgets/phone_pair_panel.dart';
import '../../widgets/settings_scaffold.dart';

/// The QR page behind "From phone" for one pasted value (add-on link, poster
/// pattern, API key); pops with what the phone sent.
class PhoneLinkScreen extends StatefulWidget {
  const PhoneLinkScreen(
      {super.key, required this.title, this.kind = PairingKind.link})
      : assert(kind == PairingKind.link ||
            kind == PairingKind.apiKey ||
            kind == PairingKind.poster);

  final String title;
  final PairingKind kind;

  /// Shows the page; the value the phone sent, or null.
  static Future<String?> open(BuildContext context,
          {required String title, PairingKind kind = PairingKind.link}) =>
      Navigator.of(context).push<String>(MaterialPageRoute(
          builder: (_) => PhoneLinkScreen(title: title, kind: kind)));

  @override
  State<PhoneLinkScreen> createState() => _PhoneLinkScreenState();
}

class _PhoneLinkScreenState extends State<PhoneLinkScreen> {
  final _toggleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The panel's only focusable control; without it the remote has
    // nothing focused (CLAUDE.md §10).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _toggleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: widget.title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: PhonePairPanel(
          kind: widget.kind,
          toggleFocusNode: _toggleFocus,
          onResult: (r) {
            if (mounted) Navigator.of(context).pop(r.link);
          },
        ),
      ),
    );
  }
}
