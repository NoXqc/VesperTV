import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/phone_pairing_service.dart' show deviceOnVpn;
import '../../services/storage_service.dart';
import '../../services/vesper_ai/mcp_bridge.dart';
import '../../services/vesper_ai/phone_mic_server.dart';

/// "Talk from my phone": a QR code for the phone page. Same Wi-Fi = the TV's
/// own server (nothing leaves the home); the second code works from any
/// network through the relay and gets the phone's own microphone button.
///
/// Most IPTV users run a VPN on the TV box (owner, 2026-11-07), which also
/// catches the replies to a phone on the home Wi-Fi: on a VPN the dialog
/// opens on the relay code. That code no longer needs AI apps turned on
/// (`McpBridge.startPhoneLink`: phone page only, ends after an idle hour).
Future<void> showPhoneMicSheet(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _PhoneMicDialog(),
    );

class _PhoneMicDialog extends StatefulWidget {
  const _PhoneMicDialog();

  @override
  State<_PhoneMicDialog> createState() => _PhoneMicDialogState();
}

class _PhoneMicDialogState extends State<_PhoneMicDialog> {
  String? _lan;
  String? _relay;
  bool _loading = true;
  bool _anywhere = false;
  bool _vpn = false;

  @override
  void initState() {
    super.initState();
    () async {
      final storage = context.read<StorageService>();
      final vpn = await deviceOnVpn();
      final url = await PhoneMicServer.instance.start(storage);
      final relay = vpn || url == null
          ? await McpBridge.instance.startPhoneLink()
          : McpBridge.instance.phoneUrl;
      if (!mounted) return;
      setState(() {
        _vpn = vpn;
        _lan = url;
        _relay = relay;
        // A VPN on the TV (or no home network address): the relay code.
        _anywhere = (vpn || url == null) && relay != null;
        _loading = false;
      });
    }();
  }

  Future<void> _toggle() async {
    if (_anywhere) {
      setState(() => _anywhere = false);
      return;
    }
    final relay = await McpBridge.instance.startPhoneLink();
    if (!mounted) return;
    setState(() {
      _relay = relay;
      _anywhere = relay != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = _anywhere ? _relay : _lan;
    return AlertDialog(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      title: Text(tr('Talk from my phone')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_vpn && _anywhere) ...[
                Text(
                  tr('This TV is on a VPN, so this code goes through the internet.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                _anywhere
                    ? tr(
                        'Scan with your phone. Works on any network, and the page has its own microphone button.')
                    : tr(
                        'Scan with your phone on the same Wi-Fi as this TV, then type or tap the microphone on your phone\'s keyboard.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )
              else if (url == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tr('This TV is not on a Wi-Fi or wired network.'),
                      textAlign: TextAlign.center),
                )
              else ...[
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(10),
                  child: QrImageView(
                    data: url,
                    size: 220,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                if (!_anywhere) ...[
                  SelectableText(url,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    tr('Page does not open? A VPN on this TV can block it: use "Phone not on this Wi-Fi?" below.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_loading)
          TextButton(
            onPressed: _toggle,
            child: Text(_anywhere
                ? tr('Same Wi-Fi instead')
                : tr('Phone not on this Wi-Fi?')),
          ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Close')),
        ),
      ],
    );
  }
}
