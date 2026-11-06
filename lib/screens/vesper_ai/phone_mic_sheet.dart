import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/storage_service.dart';
import '../../services/vesper_ai/mcp_bridge.dart';
import '../../services/vesper_ai/phone_mic_server.dart';

/// "Talk from my phone": a QR code for the phone page. Same Wi-Fi = the TV's
/// own server (nothing leaves the home); with AI apps linked, a second code
/// works from anywhere through the relay and gets the phone's own
/// microphone button.
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
  bool _loading = true;
  bool _anywhere = false;

  @override
  void initState() {
    super.initState();
    () async {
      final url =
          await PhoneMicServer.instance.start(context.read<StorageService>());
      if (!mounted) return;
      setState(() {
        _lan = url;
        _loading = false;
      });
    }();
  }

  @override
  Widget build(BuildContext context) {
    final relay = McpBridge.instance.phoneUrl;
    final url = _anywhere ? relay : _lan;
    return AlertDialog(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      title: Text(tr('Talk from my phone')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              if (!_anywhere)
                SelectableText(url,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ],
        ),
      ),
      actions: [
        if (relay != null)
          TextButton(
            onPressed: () => setState(() => _anywhere = !_anywhere),
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
