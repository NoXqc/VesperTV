import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Bounded, rate-limited diagnostics. Never log a URL, path, title or error text.
class ImageDiagnostics {
  static final _seen = <int, DateTime>{};
  static final _counts = <String, int>{};

  static void failure(String url, Object error, {int? status}) {
    final host = Uri.tryParse(url)?.host ?? '';
    final code =
        status ?? (error is HttpExceptionWithStatus ? error.statusCode : null);
    final kind = error.runtimeType.toString();
    final now = DateTime.now();
    _seen.removeWhere(
        (_, at) => now.difference(at) > const Duration(minutes: 1));
    final signature = Object.hash(url, kind, code);
    if (_seen.containsKey(signature)) return;
    if (_seen.length >= 256) _seen.remove(_seen.keys.first);
    _seen[signature] = now;
    final key =
        '${host.isEmpty ? 'cache/local' : host} status=${code ?? '-'} type=$kind';
    if (_counts.length >= 128 && !_counts.containsKey(key)) {
      _counts.remove(_counts.keys.first);
    }
    final count = (_counts[key] ?? 0) + 1;
    _counts[key] = count;
    if (count == 1 || count % 16 == 0) {
      debugPrint('ImageLoad: $key failures=$count');
    }
  }
}

class DiagnosticImageFileService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    try {
      final response = await super.get(url, headers: headers);
      if (response.statusCode >= 400) {
        ImageDiagnostics.failure(url, const ImageHttpFailure(),
            status: response.statusCode);
      }
      return response;
    } catch (error) {
      ImageDiagnostics.failure(url, error);
      rethrow;
    }
  }
}

class ImageHttpFailure {
  const ImageHttpFailure();
}
