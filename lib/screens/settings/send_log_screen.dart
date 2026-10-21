import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/app_log.dart';
import '../../services/playlist_manager.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/mode_button.dart';
import '../../widgets/settings_scaffold.dart';

/// Settings > Device & data > Send log — see [AppLog]. One button; the
/// result is a code the user quotes when reporting the problem.
class SendLogScreen extends StatefulWidget {
  const SendLogScreen({super.key});

  @override
  State<SendLogScreen> createState() => _SendLogScreenState();
}

enum _Status { idle, sending, sent, error }

class _SendLogScreenState extends State<SendLogScreen> {
  final _sendNode = FocusNode();
  _Status _status = _Status.idle;
  String _code = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    // The screen's only control: give the remote something focused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sendNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _sendNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_status == _Status.sending) return;
    final profiles = context.read<PlaylistManager>().profiles;
    setState(() => _status = _Status.sending);
    final code = AppLog.newCode();
    try {
      final text = AppLog.redact(await AppLog.collect(), profiles);
      await AppLog.send(code, text);
      if (!mounted) return;
      setState(() {
        _code = code;
        _status = _Status.sent;
      });
    } on TooManyLogsException {
      if (!mounted) return;
      setState(() {
        _error = tr('Too many logs sent from here. Try again in an hour.');
        _status = _Status.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = tr(
            'Couldn\'t send the log. Check the internet connection and try again.');
        _status = _Status.error;
      });
    }
    if (mounted) _sendNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return withTvThemeIfNeeded(
      context,
      (context) => SettingsScaffold(
        title: tr('Send log'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('Something not working? Send the app\'s log to the VesperTV developer. It holds what the app did recently (this session and the last one) and your device model, nothing else.'),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              tr('Server addresses, user names, passwords and other private details are removed before sending.'),
              style: text.bodySmall,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: ModeButton(
                focusNode: _sendNode,
                icon: Icons.bug_report_outlined,
                label: _status == _Status.sending
                    ? tr('Sending...')
                    : _status == _Status.sent
                        ? tr('Send again')
                        : tr('Send log'),
                selected: false,
                onTap: _send,
              ),
            ),
            const SizedBox(height: 20),
            if (_status == _Status.sent) ...[
              Text(tr('Log sent. Your code:'), style: text.bodyMedium),
              const SizedBox(height: 6),
              SelectableText(_code,
                  style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 6),
              Text(
                tr('Mention this code on Reddit or Discord with what happened, so the developer can find your log.'),
                style: text.bodySmall,
              ),
            ],
            if (_status == _Status.error)
              Text(_error,
                  style: text.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    );
  }
}
