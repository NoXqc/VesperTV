import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/phone_pairing_service.dart' show PairingKind;
import '../../services/storage_service.dart';
import '../../services/vesper_ai/ai_provider.dart';
import '../../services/vesper_ai/anthropic_provider.dart';
import '../../services/vesper_ai/gemini_provider.dart';
import '../../services/vesper_ai/mcp_bridge.dart';
import '../../services/vesper_ai/openai_provider.dart';
import '../../services/vesper_ai/vesper_ai.dart';
import '../../services/vesper_ai/vesper_tools.dart';
import '../../services/vesper_ai/voice_key.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_switch_list_tile.dart';
import '../../widgets/tv_text_field_gate.dart';
import '../vesper_ai/phone_mic_sheet.dart';
import 'phone_link_screen.dart';

/// Settings > Vesper AI: the voice button, the viewer's own AI (key, model)
/// and AI apps linked over MCP. Non-lazy column: every row must be
/// reachable with the remote (CLAUDE.md §10).
class VesperAiSettingsScreen extends StatefulWidget {
  const VesperAiSettingsScreen({super.key});

  @override
  State<VesperAiSettingsScreen> createState() => _VesperAiSettingsScreenState();
}

class _VesperAiSettingsScreenState extends State<VesperAiSettingsScreen> {
  late final StorageService _storage = context.read<StorageService>();
  late String? _provider = _storage.getAiProvider();
  late final _model = TextEditingController(text: _storage.getAiModel() ?? '');
  late final _key = TextEditingController(text: _storage.getAiApiKey() ?? '');
  late final _baseUrl =
      TextEditingController(text: _storage.getAiBaseUrl() ?? '');
  final _modelFocus = FocusNode();
  final _keyFocus = FocusNode();
  final _baseFocus = FocusNode();
  final _saveFocus = FocusNode();
  final _learnFocus = FocusNode();
  bool _testing = false;
  bool _learning = false;

  @override
  void dispose() {
    if (VoiceKey.learning != null) VoiceKey.learning = null;
    for (final n in [
      _modelFocus,
      _keyFocus,
      _baseFocus,
      _saveFocus,
      _learnFocus
    ]) {
      n.dispose();
    }
    _model.dispose();
    _key.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- voice

  void _learn() {
    setState(() => _learning = true);
    VoiceKey.learning = (event) {
      if (VoiceKey.isNavigation(event)) {
        // Back / OK / arrows cancel; they keep their normal job.
        VoiceKey.learning = null;
        if (mounted) setState(() => _learning = false);
        return event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter;
      }
      VoiceKey.learning = null;
      unawaited(_storage.setAiLearnedKey(event.logicalKey.keyId));
      unawaited(_storage.setAiVoiceButton(true));
      if (mounted) {
        setState(() => _learning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Learned: {key}',
                {'key': VoiceKey.describe(event.logicalKey.keyId)}))));
      }
      return true;
    };
  }

  // ------------------------------------------------------------ your AI

  String get _defaultModel => switch (_provider) {
        'anthropic' => AnthropicProvider.defaultModel,
        'gemini' => GeminiProvider.defaultModel,
        _ => '',
      };

  Future<void> _save({bool test = true}) async {
    await _storage.setAiConfig(
        provider: _provider,
        model: _model.text,
        apiKey: _key.text,
        baseUrl: _provider == 'openai' ? _baseUrl.text : '');
    if (!mounted) return;
    if (_provider == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Vesper uses its built-in commands only.'))));
      return;
    }
    final provider = AiProvider.fromSettings(
        provider: _provider,
        model: _model.text,
        apiKey: _key.text,
        baseUrl: _baseUrl.text);
    if (provider == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_provider == 'openai'
              ? tr('Saved. Add the model name (and the key for OpenAI).')
              : tr('Saved. Add your key to use it.'))));
      return;
    }
    if (!test) return;
    setState(() => _testing = true);
    String message;
    var ok = false;
    try {
      final words = await provider.send(
          'Say hello to the viewer in a few words.',
          system: VesperAi.systemPrompt(L10n.code),
          tools: const <VesperTool>[],
          runTool: (_, __) async => const {});
      ok = true;
      message = tr('Saved — it answered: {text}', {'text': words});
    } on AiProviderError catch (e) {
      message = e.message;
    } catch (e) {
      message = '$e';
    }
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, maxLines: 4, overflow: TextOverflow.ellipsis),
      backgroundColor: ok ? null : Colors.red.shade900,
    ));
  }

  Future<void> _fromPhone() async {
    final key = await PhoneLinkScreen.open(context,
        title: tr('Your AI key'), kind: PairingKind.apiKey);
    if (key == null || !mounted) return;
    _key.text = key;
    _saveFocus.requestFocus();
  }

  Widget _field(
      TextEditingController c, FocusNode focus, FocusNode next, String label,
      {String? hint, bool obscure = false}) {
    return TvTextFieldGate(
      focusNode: focus,
      builder: (context, readOnly) => TextField(
        controller: c,
        focusNode: focus,
        readOnly: readOnly,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => next.requestFocus(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _heading(IconData icon, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(text,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: Colors.white60)),
      );

  @override
  Widget build(BuildContext context) {
    final learned = _storage.getAiLearnedKey();
    final android = Platform.isAndroid;
    final linkOn = _storage.getAiLinkEnabled();
    final connector = McpBridge.instance.connectorUrl;
    return SettingsScaffold(
      title: 'Vesper AI',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr(
                'Tell VesperTV what you want: "play TSN 1", "what\'s on", "pause", "go back 30 seconds", "put on the Habs game". Everyday commands work without any AI. Add your own AI below for anything else ("make me a movie night list", "hide every Turkish group"), or link the AI app you already use.')),
            const SizedBox(height: 12),
            TvMenuTile(
              icon: Icons.auto_awesome,
              title: tr('Talk to Vesper now'),
              subtitle: tr('Opens the Vesper panel'),
              onTap: () => VesperAi.instance.openPanel(),
            ),

            // ------------------------------------------------- voice
            _heading(Icons.mic, tr('Voice')),
            if (android) ...[
              TvSwitchListTile(
                title: Text(tr('Remote voice button opens Vesper')),
                subtitle: Text(tr(
                    'The microphone / search button of your remote, while VesperTV is open. Off: it opens the device\'s own assistant.')),
                value: _storage.getAiVoiceButton(),
                onChanged: (v) async {
                  await _storage.setAiVoiceButton(v);
                  setState(() {});
                },
              ),
              TvMenuTile(
                icon: Icons.settings_remote_outlined,
                title: _learning
                    ? tr('Press your remote\'s button now...')
                    : tr('Teach it your remote\'s button'),
                subtitle: learned == null
                    ? tr('For a remote whose button is not found by itself')
                    : tr('Learned: {key}', {'key': VoiceKey.describe(learned)}),
                focusNode: _learnFocus,
                onTap: () {
                  if (!_learning) _learn();
                },
              ),
              if (learned != null)
                TvMenuTile(
                  icon: Icons.delete_outline,
                  title: tr('Forget the learned button'),
                  onTap: () async {
                    await _storage.setAiLearnedKey(null);
                    setState(() {});
                  },
                ),
              _note(tr(
                  'If nothing happens, your TV keeps that button for its own assistant (Fire TV always does). Use Talk to Vesper, the mic in Search, or your phone.')),
            ],
            TvSwitchListTile(
              title: Text(tr('Read replies aloud')),
              value: _storage.getAiSpeakReplies(),
              onChanged: (v) async {
                await _storage.setAiSpeakReplies(v);
                setState(() {});
              },
            ),
            TvMenuTile(
              icon: Icons.smartphone,
              title: tr('Talk from my phone'),
              subtitle: tr('A QR code for your phone: type or speak there'),
              onTap: () => showPhoneMicSheet(context),
            ),
            if (android)
              ExpansionTile(
                leading: const Icon(Icons.terminal),
                title: Text(tr('Make Vesper the TV\'s assistant (advanced)')),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  Text(tr(
                      'On some Android TV boxes the remote\'s assistant button can open Vesper even outside VesperTV. From a computer with ADB connected to the box, run:')),
                  const SizedBox(height: 8),
                  const SelectableText(
                      'adb shell settings put secure assistant com.nox.nox_iptv/.MainActivity',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(tr('To undo it, pick your assistant again in the TV\'s settings (Apps > Default apps > Assistant), or run: adb shell settings delete secure assistant. Google TV and Fire TV may ignore it.'),
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white60)),
                ],
              ),

            // ------------------------------------------------- your AI
            _heading(Icons.psychology_outlined, tr('Your AI')),
            _note(tr(
                'Bring your own AI key: VesperTV sends what you say and what it finds in your playlists straight to that AI, never through us. You pay the AI service for what you use.')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, label) in [
                  (null, tr('None')),
                  ('anthropic', 'Claude'),
                  ('openai', tr('OpenAI-compatible')),
                  ('gemini', 'Gemini'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _provider == id,
                    onSelected: (_) => setState(() => _provider = id),
                  ),
              ],
            ),
            if (_provider != null) ...[
              const SizedBox(height: 12),
              if (_provider == 'anthropic')
                _note(tr('Key from console.anthropic.com. Models: {list}.',
                    {'list': AnthropicProvider.suggestedModels.join(', ')})),
              if (_provider == 'gemini')
                _note(tr('Key from aistudio.google.com.')),
              if (_provider == 'openai')
                _note(tr(
                    'OpenAI, or any service with the same API (OpenRouter, Groq, Mistral, a local Ollama or LM Studio): its address, model name and key.')),
              _field(_model, _modelFocus, _keyFocus, tr('Model'),
                  hint: _defaultModel.isEmpty
                      ? null
                      : tr('Default: {model}', {'model': _defaultModel})),
              const SizedBox(height: 12),
              _field(
                  _key,
                  _keyFocus,
                  _provider == 'openai' ? _baseFocus : _saveFocus,
                  tr('API key'),
                  obscure: true),
              if (_provider == 'openai') ...[
                const SizedBox(height: 12),
                _field(_baseUrl, _baseFocus, _saveFocus, tr('Address'),
                    hint: OpenAiProvider.defaultBaseUrl),
              ],
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              FilledButton(
                focusNode: _saveFocus,
                onPressed: _testing ? null : _save,
                child: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        _provider == null ? tr('Save') : tr('Save and test')),
              ),
              if (_provider != null)
                OutlinedButton.icon(
                  onPressed: _fromPhone,
                  icon: const Icon(Icons.smartphone),
                  label: Text(tr('Key from phone')),
                ),
            ]),

            // ------------------------------------------------- AI apps
            _heading(Icons.hub_outlined, tr('AI apps')),
            _note(tr(
                'Use VesperTV from the AI app you already have (Claude, ChatGPT or any app with MCP connectors), on your phone or computer, by voice or text, with your own subscription. Plays and changes are confirmed on the TV.')),
            TvSwitchListTile(
              title: Text(tr('Let AI apps control VesperTV')),
              subtitle: Text(tr(
                  'Requests pass through the VesperTV relay to this TV while the app is open. The relay keeps nothing.')),
              value: linkOn,
              onChanged: (v) async {
                await McpBridge.instance.setEnabled(v);
                setState(() {});
              },
            ),
            if (linkOn && connector != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: connector,
                      size: 168,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(
                            'Scan with your phone to copy this connector address, then add it in your AI app:')),
                        const SizedBox(height: 6),
                        Text(tr('Claude: Settings > Connectors > Add custom connector. ChatGPT: Settings > Connectors > Create (developer mode, no authentication).'),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
                        const SizedBox(height: 8),
                        SelectableText(connector,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<DateTime?>(
                          valueListenable: McpBridge.instance.lastContact,
                          builder: (context, at, _) => Text(
                            at == null
                                ? tr('Connecting to the relay...')
                                : tr('Connected to the relay'),
                            style: TextStyle(
                                fontSize: 13,
                                color: at == null
                                    ? Colors.white54
                                    : Colors.greenAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _note(tr(
                  'Keep this address private: anyone with it can control VesperTV while it is open.')),
              TvSwitchListTile(
                title: Text(tr('Ask on the TV first')),
                subtitle: Text(tr(
                    'An AI app\'s play, hide or show waits for OK on the TV.')),
                value: _storage.getAiConfirmRemotePlay(),
                onChanged: (v) async {
                  await _storage.setAiConfirmRemotePlay(v);
                  setState(() {});
                },
              ),
              TvMenuTile(
                icon: Icons.restart_alt,
                title: tr('Reset the address'),
                subtitle: tr('The old address stops working; add the new one'),
                onTap: () async {
                  await McpBridge.instance.reset();
                  setState(() {});
                },
              ),
              ValueListenableBuilder<List<String>>(
                valueListenable: McpBridge.instance.activity,
                builder: (context, lines, _) => lines.isEmpty
                    ? const SizedBox.shrink()
                    : _note('${tr('Recent requests')}: ${lines.join(' · ')}'),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
