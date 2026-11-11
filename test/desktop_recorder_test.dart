import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/desktop_recorder.dart';

/// A small file server with Range support, like a provider's VOD link.
class _Server {
  _Server(this.body);
  final Uint8List body;
  late HttpServer server;
  final ranges = <String?>[];
  String type = 'video/x-matroska';
  int status = 200;

  String get url => 'http://127.0.0.1:${server.port}/movie.mkv';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final range = req.headers.value('range');
      ranges.add(range);
      final res = req.response;
      if (status != 200) {
        res.statusCode = status;
        await res.close();
        return;
      }
      res.headers.contentType = ContentType.parse(type);
      final from = range == null
          ? 0
          : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      if (range != null) {
        res.statusCode = 206;
        res.headers
            .set('content-range', 'bytes $from-${body.length - 1}/${body.length}');
      }
      res.contentLength = body.length - from;
      res.add(body.sublist(from));
      await res.close();
    });
  }
}

Future<Map<String, dynamic>> _waitFor(
    File status, bool Function(Map<String, dynamic>) done) async {
  final until = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(until)) {
    if (status.existsSync()) {
      try {
        final m = jsonDecode(status.readAsStringSync()) as Map<String, dynamic>;
        if (done(m)) return m;
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('status never matched: '
      '${status.existsSync() ? status.readAsStringSync() : 'none'}');
}

void main() {
  late Directory dir;
  late DesktopRecorder recorder;
  final body = Uint8List.fromList(
      List<int>.generate(6 * 1024 * 1024 + 123, (i) => (i * 31) & 0xff));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('desktop-recorder');
    recorder = DesktopRecorder(videosDir: dir.path);
    await recorder.invoke('policy', {'speed': 'none', 'streams': {}});
  });
  tearDown(() async {
    await recorder.invoke('schedule', {'items': '[]'});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await dir.delete(recursive: true);
  });

  Map<String, Object?> item(String url, {String id = 'dl1', String account = ''}) => {
        'id': id,
        'kind': 'download',
        'url': url,
        'path': '${dir.path}/$id.mkv',
        'statusPath': '${dir.path}/status/$id.status',
        'startAt': DateTime.now().millisecondsSinceEpoch - 1000,
        'endAt': 0,
        'account': account,
        'maxConnections': 1,
        'minFreeBytes': 0,
      };

  test('paths: the network folder is the Windows share', () {
    expect(DesktopRecorder.localPath('smb://nas/Media/VesperTV/a b.mkv'),
        r'\\nas\Media\VesperTV\a b.mkv');
    expect(DesktopRecorder.localPath(r'C:\Videos\x.mkv'), r'C:\Videos\x.mkv');
    expect(DesktopRecorder.detailsPath('smb://nas/Media/VesperTV/x.mkv'),
        'smb://nas/Media/VesperTV/.vespertv/x.mkv.json');
    expect(DesktopRecorder.describeCode(1326), 'Wrong user name or password');
    expect(DesktopRecorder.describeCode(67), 'No shared folder with that name');
  });

  test('storage is the Videos folder with its free space', () async {
    final list = await recorder.invoke('storage', {}) as List;
    final v = list.single as Map;
    expect(v['path'], dir.path);
    if (Platform.isWindows) {
      expect(v['free'] as int, greaterThan(0));
      expect(v['total'] as int, greaterThanOrEqualTo(v['free'] as int));
    }
  });

  test('downloads the whole file and reports done', () async {
    final server = _Server(body);
    await server.start();
    addTearDown(() => server.server.close(force: true));
    await recorder.invoke(
        'schedule', {'items': jsonEncode([item(server.url)])});
    final status = File('${dir.path}/status/dl1.status');
    final m = await _waitFor(status, (m) => m['state'] == 'done');
    expect(m['bytes'], body.length);
    expect(m['total'], body.length);
    expect(await File('${dir.path}/dl1.mkv').readAsBytes(), body);
    expect(await recorder.invoke('active', {}), isEmpty);
  });

  test('resumes a partial file with a Range request', () async {
    final server = _Server(body);
    await server.start();
    addTearDown(() => server.server.close(force: true));
    await File('${dir.path}/dl1.mkv').writeAsBytes(body.sublist(0, 2000000));
    await recorder.invoke(
        'schedule', {'items': jsonEncode([item(server.url)])});
    await _waitFor(File('${dir.path}/status/dl1.status'),
        (m) => m['state'] == 'done');
    expect(server.ranges.first, 'bytes=2000000-');
    expect(await File('${dir.path}/dl1.mkv').readAsBytes(), body);
  });

  test('a page instead of a video fails with the reason', () async {
    final server = _Server(Uint8List.fromList(utf8.encode(
        '<html><body>Account expired</body></html>')))
      ..type = 'text/html';
    await server.start();
    addTearDown(() => server.server.close(force: true));
    await recorder.invoke(
        'schedule', {'items': jsonEncode([item(server.url)])});
    final m = await _waitFor(File('${dir.path}/status/dl1.status'),
        (m) => m['state'] == 'failed');
    expect(m['error'], contains('The link sent a page, not a video'));
    expect(m['error'], contains('Account expired'));
  });

  test('a file gone at the provider fails at once', () async {
    final server = _Server(body)..status = 404;
    await server.start();
    addTearDown(() => server.server.close(force: true));
    await recorder.invoke(
        'schedule', {'items': jsonEncode([item(server.url)])});
    final m = await _waitFor(File('${dir.path}/status/dl1.status'),
        (m) => m['state'] == 'failed');
    expect(m['error'], contains('HTTP 404'));
  });

  test('waits while the app uses the account\'s only connection', () async {
    final server = _Server(body);
    await server.start();
    addTearDown(() => server.server.close(force: true));
    await recorder.invoke('policy', {
      'speed': 'none',
      'streams': {'acc': 1}
    });
    await recorder.invoke('schedule', {
      'items': jsonEncode([item(server.url, account: 'acc')])
    });
    final status = File('${dir.path}/status/dl1.status');
    final paused = await _waitFor(status, (m) => m['state'] == 'paused');
    expect(paused['note'], 'connection');
    expect(server.ranges, isEmpty);
    // The player stopped: it carries on.
    await recorder.invoke('policy', {'speed': 'none', 'streams': {}});
    await _waitFor(status, (m) => m['state'] == 'done');
    expect(await File('${dir.path}/dl1.mkv').readAsBytes(), body);
  });

  test('stop ends a download and keeps it stopped', () async {
    final server = _Server(body);
    await server.start();
    addTearDown(() => server.server.close(force: true));
    // Slow enough to stop before the end.
    await recorder.invoke('policy', {'speed': '10', 'streams': {}});
    await recorder.invoke(
        'schedule', {'items': jsonEncode([item(server.url)])});
    final status = File('${dir.path}/status/dl1.status');
    await _waitFor(status, (m) => m['state'] == 'downloading');
    await recorder.invoke('stop', {'id': 'dl1'});
    final m = await _waitFor(status, (m) => m['state'] == 'stopped');
    expect(m['bytes'] as int, lessThan(body.length));
  });
}
