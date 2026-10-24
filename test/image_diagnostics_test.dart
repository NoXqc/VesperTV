import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/image_diagnostics.dart';

void main() {
  test(
      'image diagnostics log host/type/status without URL credentials or error text',
      () {
    final previous = debugPrint;
    final lines = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) lines.add(message);
    };
    addTearDown(() => debugPrint = previous);
    const url =
        'https://private-user:private-password@art.example.com/private-path?token=private-token';
    const error = HttpException('private-password at private-path');
    ImageDiagnostics.failure(url, error, status: 403);
    ImageDiagnostics.failure(url, error, status: 403);
    expect(lines, hasLength(1));
    expect(lines.single,
        contains('art.example.com status=403 type=HttpException'));
    expect(lines.single, isNot(contains('private-')));
    expect(lines.single, isNot(contains('https://')));
  });
}
