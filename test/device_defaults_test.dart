import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/device_defaults.dart';

void main() {
  const cube =
      DeviceFingerprint(manufacturer: 'Amazon', model: 'AFTGAZL', sdk: '28');
  const stick =
      DeviceFingerprint(manufacturer: 'Amazon', model: 'AFTKM', sdk: '28');

  test('Fire TV Cube gets Background video on, other sticks do not', () {
    const rules = DeviceDefaults.bundledRules;
    expect(DeviceDefaults.rulesFor(cube, rules).map((r) => r.id),
        ['fire-tv-cube-3']);
    expect(DeviceDefaults.rulesFor(stick, rules), isEmpty);
  });

  test('match is case-insensitive and needs every field', () {
    const rule = DeviceRule(
        id: 'x',
        match: {'manufacturer': 'nvidia', 'model': 'SHIELD Android TV'},
        set: {DeviceDefaults.compatVideo: true});
    expect(
        rule.matches(const DeviceFingerprint(
            manufacturer: 'NVIDIA', model: 'shield android tv')),
        isTrue);
    expect(rule.matches(const DeviceFingerprint(model: 'SHIELD Android TV')),
        isFalse);
  });

  test('remote rule replaces the bundled one with the same id', () {
    final remote = DeviceDefaults.parse(
        '{"rules":[{"id":"fire-tv-cube-3","match":{"model":"AFTGAZL"},'
        '"set":{}}]}');
    final merged = DeviceDefaults.merge(DeviceDefaults.bundledRules, remote);
    expect(DeviceDefaults.rulesFor(cube, merged), isEmpty);
  });

  test('bad JSON, unknown settings and match-everything rules are ignored', () {
    expect(DeviceDefaults.parse('not json'), isNull);
    expect(DeviceDefaults.parse('{"rules": 3}'), isNull);
    final rules = DeviceDefaults.parse(
        '{"rules":[{"id":"a","match":{},"set":{"compatVideo":true}},'
        '{"id":"b","match":{"model":"X"},"set":{"deleteAll":true,'
        '"compatVideo":"yes"}}]}')!;
    expect(rules.map((r) => r.id), ['b']);
    expect(rules.single.set, isEmpty);
  });

  test('the site copy parses and matches the bundled list', () {
    final site = DeviceDefaults.parse(
        File('docs/device-defaults.json').readAsStringSync())!;
    String key(DeviceRule r) => '${r.id} ${r.match} ${r.set}';
    expect(site.map(key).toSet(),
        containsAll(DeviceDefaults.bundledRules.map(key)));
  });
}
