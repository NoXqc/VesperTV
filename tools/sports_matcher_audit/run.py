"""Generate an ignored Flutter runner from the exact production matcher.

Appending diagnostics in the same Dart library exposes private decision helpers
without adding hooks or switches to the shipped application. Never edit the copy.
"""
import hashlib
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'lib/services/sports_channel_matcher.dart'
original = source.read_text(encoding='utf-8')
lines = []
for line in original.splitlines():
    if line.startswith("import '") and not line.startswith("import 'dart:"):
        spec = line.split("'")[1]
        if not spec.startswith('package:'):
            relative = (source.parent / spec).resolve().relative_to(ROOT / 'lib').as_posix()
            line = line.replace(spec, 'package:nox_iptv/' + relative)
    lines.append(line)
extra_imports = """import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nox_iptv/services/sports_service.dart';
"""
folder = ROOT / '.dart_tool/matcher-audit'
folder.mkdir(parents=True, exist_ok=True)
(folder / 'matcher.sha256').write_text(hashlib.sha256(source.read_bytes()).hexdigest())
runner = folder / 'runner_test.dart'
runner.write_text(extra_imports + '\n'.join(lines) + '\n' +
                  (ROOT / 'tools/sports_matcher_audit/runner.dart.inc').read_text(encoding='utf-8'), encoding='utf-8')
raise SystemExit(subprocess.call(['flutter.bat', 'test', '--no-pub', str(runner), '--reporter', 'expanded', *sys.argv[1:]], cwd=ROOT))
