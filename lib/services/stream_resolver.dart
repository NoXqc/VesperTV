import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Where [url] really serves from, after following its redirects once.
///
/// A debrid add-on's stream link is a redirect chain (add-on → debrid API
/// → CDN), and the player opens a big file with several separate requests
/// (header, the index at the end of an MKV, the resume point): each one
/// walked the whole chain again — 6.5 s before the first frame of a 4K
/// episode on a Shield, where other players start at once (user log,
/// 2026-10-21). Resolving once and handing the player the CDN link cuts
/// that to one walk.
///
/// Never throws: on any failure (timeout, refused, an error status) the
/// original [url] comes back and the player deals with it as before.
Future<String> resolveRedirects(String url,
    {int maxHops = 8, Duration timeout = const Duration(seconds: 8)}) async {
  var uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return url;
  }
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    for (var hop = 0; hop < maxHops; hop++) {
      final req = await client.getUrl(uri!).timeout(timeout);
      req.followRedirects = false;
      // Headers only: a one-byte range, and the body is never read.
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final res = await req.close().timeout(timeout);
      final location = res.headers.value(HttpHeaders.locationHeader);
      unawaited(res.listen(null).cancel());
      if (res.isRedirect && location != null) {
        uri = uri.resolve(location);
        continue;
      }
      return res.statusCode < 400 ? uri.toString() : url;
    }
    return url;
  } catch (e) {
    debugPrint('resolveRedirects: $e');
    return url;
  } finally {
    client.close(force: true);
  }
}
