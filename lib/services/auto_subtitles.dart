import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Automatic subtitles for live channels that carry none (beta, Android;
/// owner, 2026-11-12: movies have the online subtitle add-ons, live TV is
/// what needs this). The main player's decoded sound (vendored player's
/// `AudioTap`, 16 kHz mono) goes to a speech recognizer running on the TV
/// itself (sherpa-onnx streaming Zipformer), in an isolate; the words show
/// in [SubtitleOverlay] a second or two after they're said. Nothing leaves
/// the TV. The engine's native libraries and the language model download on
/// first use (pinned archives, checked), so the APK doesn't grow. Not with
/// surround passthrough (the sound is never decoded). See
/// dev-notes/auto-subtitles.md.
class AutoSubtitleModel {
  const AutoSubtitleModel({
    required this.language,
    required this.repo,
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.megabytes,
  });

  /// ISO 639-1 ("en").
  final String language;

  /// Hugging Face repository (Apache-2.0 models by the sherpa-onnx authors).
  final String repo;
  final String encoder;
  final String decoder;
  final String joiner;

  /// Download size, shown before downloading.
  final int megabytes;

  List<String> get files => [encoder, decoder, joiner, 'tokens.txt'];
  String get folder => repo.split('/').last;
  String urlOf(String file) =>
      'https://huggingface.co/$repo/resolve/main/$file';
}

/// The languages offered. Streaming Zipformer transducers, int8 (decoder in
/// float: the int8 one costs accuracy for almost no size).
const autoSubtitleModels = [
  AutoSubtitleModel(
    language: 'en',
    repo: 'csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17',
    encoder: 'encoder-epoch-99-avg-1.int8.onnx',
    decoder: 'decoder-epoch-99-avg-1.onnx',
    joiner: 'joiner-epoch-99-avg-1.int8.onnx',
    megabytes: 46,
  ),
  AutoSubtitleModel(
    language: 'fr',
    repo: 'shaojieli/sherpa-onnx-streaming-zipformer-fr-2023-04-14',
    encoder: 'encoder-epoch-29-avg-9-with-averaged-model.int8.onnx',
    decoder: 'decoder-epoch-29-avg-9-with-averaged-model.onnx',
    joiner: 'joiner-epoch-29-avg-9-with-averaged-model.int8.onnx',
    megabytes: 130,
  ),
];

AutoSubtitleModel? autoSubtitleModel(String? language) {
  for (final m in autoSubtitleModels) {
    if (m.language == language) return m;
  }
  return null;
}

/// sherpa-onnx 2.0.1's Android libraries (the version of the Dart bindings in
/// third_party/sherpa_onnx_dart), from pub.dev's immutable package archives,
/// checked against these SHA-256 before anything is loaded.
const _engineVersion = '2.0.1';
const _engines = {
  Abi.androidArm64: (
    url: 'https://pub.dev/api/archives/sherpa_onnx_android_arm64-2.0.1.tar.gz',
    sha256: 'eceb1fd5de24d07c5aa618f6fa913f3f950018e6c009b899d076ba08209d08ec',
    abi: 'arm64-v8a',
    megabytes: 11,
  ),
  Abi.androidArm: (
    url:
        'https://pub.dev/api/archives/sherpa_onnx_android_armeabi-2.0.1.tar.gz',
    sha256: '7ea0ed1d1964d124398239ea137ef4f901b8e6b79632279f85db7e2205b7c0a5',
    abi: 'armeabi-v7a',
    megabytes: 10,
  ),
};

const _engineFiles = ['libonnxruntime.so', 'libsherpa-onnx-c-api.so'];

class AutoSubtitles {
  AutoSubtitles._();
  static final instance = AutoSubtitles._();

  static const _tap = EventChannel('vespertv/audio_tap');

  /// This device can run it (Android on an ARM processor).
  static bool get supported =>
      !kIsWeb && Platform.isAndroid && _engines.containsKey(Abi.current());

  /// The caption to draw now ('' = nothing).
  final ValueNotifier<String> text = ValueNotifier('');

  /// The language listening now, or null.
  final ValueNotifier<String?> active = ValueNotifier(null);

  /// 0..1 while downloading, else null.
  final ValueNotifier<double?> progress = ValueNotifier(null);

  /// Megabytes to download before [language] can run (0 = ready).
  Future<int> downloadSize(String language) async {
    final model = autoSubtitleModel(language);
    if (model == null) return 0;
    var mb = 0;
    if (!await _engineReady()) mb += _engines[Abi.current()]?.megabytes ?? 0;
    if (!await _modelReady(model)) mb += model.megabytes;
    return mb;
  }

  Future<Directory> _root() async => Directory(
      '${(await getApplicationSupportDirectory()).path}/auto_subtitles');

  Future<Directory> _engineDir() async {
    final abi = _engines[Abi.current()]?.abi ?? 'none';
    return Directory('${(await _root()).path}/engine-$_engineVersion-$abi');
  }

  Future<Directory> _modelDir(AutoSubtitleModel m) async =>
      Directory('${(await _root()).path}/${m.folder}');

  Future<bool> _engineReady() async {
    final dir = await _engineDir();
    for (final f in _engineFiles) {
      if (!await File('${dir.path}/$f').exists()) return false;
    }
    return true;
  }

  Future<bool> _modelReady(AutoSubtitleModel m) async {
    final dir = await _modelDir(m);
    return File('${dir.path}/.complete').exists();
  }

  /// Languages downloaded on this TV and the space everything takes.
  Future<(List<String>, int)> downloaded() async {
    final root = await _root();
    if (!await root.exists()) return (const <String>[], 0);
    var bytes = 0;
    await for (final e in root.list(recursive: true)) {
      if (e is File) bytes += await e.length();
    }
    return (
      [
        for (final m in autoSubtitleModels)
          if (await _modelReady(m)) m.language
      ],
      bytes
    );
  }

  /// Frees the space (stops listening first).
  Future<void> deleteAll() async {
    await stop();
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  }

  bool _cancel = false;
  void cancelDownload() => _cancel = true;

  /// Downloads what [language] still needs, reporting [progress]. False =
  /// cancelled; throws on a failed or altered download.
  Future<bool> install(String language) async {
    final model = autoSubtitleModel(language);
    final engine = _engines[Abi.current()];
    if (model == null || engine == null) {
      throw StateError('Automatic subtitles do not run on this device.');
    }
    _cancel = false;
    final client = http.Client();
    try {
      final total = (await downloadSize(language)) * 1000000;
      var done = 0;
      void tick(int n) {
        done += n;
        progress.value = total == 0 ? null : (done / total).clamp(0.0, 1.0);
      }

      progress.value = 0;
      if (!await _engineReady()) {
        final bytes = await _fetch(client, engine.url, tick);
        if (bytes == null) return false;
        if (sha256.convert(bytes).toString() != engine.sha256) {
          throw StateError('The speech engine download did not check out.');
        }
        final dir = await _engineDir();
        await dir.create(recursive: true);
        final wanted = {
          for (final f in _engineFiles)
            'android/src/main/jniLibs/${engine.abi}/$f': f
        };
        for (final (name, data) in untar(gzip.decode(bytes))) {
          final target = wanted[name];
          if (target != null) {
            await File('${dir.path}/$target').writeAsBytes(data, flush: true);
          }
        }
        if (!await _engineReady()) {
          throw StateError('The speech engine download was incomplete.');
        }
        // Android 14 refuses writable downloaded code: read-only now.
        await Process.run('chmod', [
          '555',
          for (final f in _engineFiles) '${dir.path}/$f',
        ]).catchError((Object _) => ProcessResult(0, 1, '', ''));
      }
      if (!await _modelReady(model)) {
        final dir = await _modelDir(model);
        await dir.create(recursive: true);
        for (final f in model.files) {
          final file = File('${dir.path}/$f');
          final ok = await _fetchTo(client, model.urlOf(f), file, tick);
          if (!ok) return false;
        }
        await File('${dir.path}/.complete').writeAsString('ok');
      }
      debugPrint('AutoSubs: installed $language');
      return true;
    } finally {
      client.close();
      progress.value = null;
    }
  }

  Future<Uint8List?> _fetch(
      http.Client client, String url, void Function(int) tick) async {
    final res = await client.send(http.Request('GET', Uri.parse(url)));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}');
    }
    final out = BytesBuilder(copy: false);
    await for (final chunk in res.stream) {
      if (_cancel) return null;
      out.add(chunk);
      tick(chunk.length);
    }
    return out.takeBytes();
  }

  Future<bool> _fetchTo(http.Client client, String url, File file,
      void Function(int) tick) async {
    final res = await client.send(http.Request('GET', Uri.parse(url)));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}');
    }
    final part = File('${file.path}.part');
    final sink = part.openWrite();
    try {
      await for (final chunk in res.stream) {
        if (_cancel) return false;
        sink.add(chunk);
        tick(chunk.length);
      }
    } finally {
      await sink.close();
    }
    if (_cancel) return false;
    await part.rename(file.path);
    return true;
  }

  /// (name, bytes) of every regular file in a ustar archive.
  @visibleForTesting
  static Iterable<(String, Uint8List)> untar(List<int> tar) sync* {
    final data = tar is Uint8List ? tar : Uint8List.fromList(tar);
    var at = 0;
    String field(int from, int len) {
      final bytes = data.sublist(at + from, at + from + len);
      final end = bytes.indexOf(0);
      return ascii.decode(end < 0 ? bytes : bytes.sublist(0, end),
          allowInvalid: true);
    }

    while (at + 512 <= data.length) {
      final name = field(0, 100);
      if (name.isEmpty) break;
      final size = int.tryParse(field(124, 12).trim(), radix: 8) ?? 0;
      final type = data[at + 156];
      final prefix = field(345, 155);
      final body = at + 512;
      if ((type == 0x30 || type == 0) && body + size <= data.length) {
        yield (
          prefix.isEmpty ? name : '$prefix/$name',
          data.sublist(body, body + size)
        );
      }
      at = body + ((size + 511) ~/ 512) * 512;
    }
  }

  // ------------------------------------------------------------- listening

  Isolate? _isolate;
  SendPort? _toIsolate;
  ReceivePort? _fromIsolate;
  StreamSubscription<dynamic>? _audio;
  Timer? _clear;
  String _done = '';
  String _now = '';

  /// Chunks sent but not decoded yet: over 2 s behind, new sound is dropped
  /// (a slow box falls back instead of drifting further behind the picture).
  int _behind = 0;
  int _dropped = 0;
  int _run = 0;

  /// Starts listening in [language] (installed). Restarts when another
  /// language runs.
  Future<void> start(String language) async {
    if (active.value == language && _isolate != null) return;
    await stop();
    final model = autoSubtitleModel(language);
    if (model == null || !supported) return;
    final run = ++_run;
    final engine = (await _engineDir()).path;
    final dir = (await _modelDir(model)).path;
    final port = ReceivePort();
    _fromIsolate = port;
    active.value = language;
    try {
      _isolate = await Isolate.spawn(_listen, (
        port.sendPort,
        engine,
        {
          'encoder': '$dir/${model.encoder}',
          'decoder': '$dir/${model.decoder}',
          'joiner': '$dir/${model.joiner}',
          'tokens': '$dir/tokens.txt',
        },
      ));
    } catch (e) {
      debugPrint('AutoSubs: could not start: $e');
      await stop();
      return;
    }
    if (run != _run) return;
    port.listen((m) => _onIsolate(m, language));
    debugPrint('AutoSubs: listening ($language)');
  }

  void _onIsolate(Object? m, String language) {
    if (m is SendPort) {
      _toIsolate = m;
      _audio = _tap.receiveBroadcastStream().listen(_onAudio);
      return;
    }
    if (m is! List || m.isEmpty) return;
    switch (m[0]) {
      case 'ack':
        if (_behind > 0) _behind--;
      case 'partial':
        _now = tidy(m[1] as String, language);
        _show();
      case 'final':
        final line = tidy(m[1] as String, language);
        if (line.isNotEmpty) _done = line;
        _now = '';
        _show();
      case 'error':
        debugPrint('AutoSubs: ${m[1]}');
        unawaited(stop());
    }
  }

  void _onAudio(dynamic data) {
    final to = _toIsolate;
    if (to == null || data is! Uint8List) return;
    if (_behind > 20) {
      if (_dropped++ % 50 == 0) {
        debugPrint('AutoSubs: this device is behind, skipping sound '
            '(${_dropped ~/ 10} s so far)');
      }
      return;
    }
    final samples = Float32List(data.length ~/ 2);
    final view = ByteData.sublistView(data);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    _behind++;
    to.send(samples);
  }

  /// The models write in capitals without punctuation: sentence case, "I".
  @visibleForTesting
  static String tidy(String raw, String language) {
    var t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return '';
    if (t == t.toUpperCase()) t = t.toLowerCase();
    if (language == 'en') {
      t = t.replaceAllMapped(RegExp(r"\bi\b(?='|\s|$)"), (_) => 'I');
    }
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Two short lines: the last finished sentence and the one being said,
  /// each cut to its last ~45 characters (whole words). Cleared after 5 s
  /// of silence.
  void _show() {
    String tail(String s) {
      if (s.length <= 45) return s;
      final cut = s.substring(s.length - 45);
      final space = cut.indexOf(' ');
      return space < 0 ? cut : cut.substring(space + 1);
    }

    final lines = [
      if (_done.isNotEmpty && _now.isNotEmpty) tail(_done),
      tail(_now.isNotEmpty ? _now : _done),
    ].where((l) => l.isNotEmpty).toList();
    text.value = lines.join('\n');
    _clear?.cancel();
    _clear = Timer(const Duration(seconds: 5), () {
      _done = '';
      _now = '';
      text.value = '';
    });
  }

  Future<void> stop() async {
    _run++;
    await _audio?.cancel();
    _audio = null;
    _toIsolate?.send(null);
    _toIsolate = null;
    final isolate = _isolate;
    _isolate = null;
    _fromIsolate?.close();
    _fromIsolate = null;
    // The isolate frees the recognizer on null; kill it if it doesn't go.
    if (isolate != null) {
      Timer(const Duration(seconds: 2),
          () => isolate.kill(priority: Isolate.immediate));
    }
    _clear?.cancel();
    _done = '';
    _now = '';
    _behind = 0;
    _dropped = 0;
    if (active.value != null) debugPrint('AutoSubs: stopped');
    active.value = null;
    text.value = '';
  }
}

/// The recognizer isolate: loads the engine from [args].$2, the model files
/// from $3, then decodes every Float32List it's sent (16 kHz mono) and posts
/// partial / final text back; null ends it.
void _listen((SendPort, String, Map<String, String>) args) {
  final (reply, engine, files) = args;
  final inbox = ReceivePort();
  sherpa.OnlineRecognizer? recognizer;
  sherpa.OnlineStream? stream;
  try {
    sherpa.initBindings(engine);
    recognizer = sherpa.OnlineRecognizer(sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: files['encoder']!,
          decoder: files['decoder']!,
          joiner: files['joiner']!,
        ),
        tokens: files['tokens']!,
        // Two of a TV box's four cores: the picture and the app keep theirs.
        numThreads: 2,
        debug: false,
        modelType: 'zipformer',
      ),
      // A pause ends a line: 1.2 s after speech, 2.4 s with none at all.
      rule2MinTrailingSilence: 1.2,
      rule3MinUtteranceLength: 15,
    ));
    stream = recognizer.createStream();
  } catch (e) {
    reply.send(['error', 'engine did not start: $e']);
    inbox.close();
    return;
  }
  reply.send(inbox.sendPort);
  var last = '';
  final rec = recognizer;
  final s = stream;
  inbox.listen((m) {
    if (m is! Float32List) {
      s.free();
      rec.free();
      inbox.close();
      return;
    }
    s.acceptWaveform(samples: m, sampleRate: 16000);
    while (rec.isReady(s)) {
      rec.decode(s);
    }
    final text = rec.getResult(s).text;
    if (rec.isEndpoint(s)) {
      if (text.trim().isNotEmpty) reply.send(['final', text]);
      rec.reset(s);
      last = '';
    } else if (text != last) {
      last = text;
      reply.send(['partial', text]);
    }
    reply.send(['ack']);
  });
}
