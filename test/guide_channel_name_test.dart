import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/real_4k_channels.dart';

/// A 4K channel's name on two lines stops short of the 4K tag in the row's
/// corner (owner photos, 2026-11-21); a one-line name keeps its full width.
void main() {
  Channel ch(String name) => Channel(
      id: 'p::$name',
      rawId: name,
      playlistId: 'p',
      name: name,
      group: 'Sports',
      url: 'http://host/1.ts');

  Future<void> pump(WidgetTester tester, Channel c) =>
      tester.pumpWidget(MaterialApp(
          home: Center(
              child: SizedBox(
                  width: 160,
                  child: GuideChannelName(
                      channel: c,
                      twoLines: true,
                      style: const TextStyle(fontSize: 12))))));

  bool padded(WidgetTester tester) => find
      .byWidgetPredicate((w) =>
          w is Padding &&
          w.padding == const EdgeInsets.only(right: GuideChannelName.tagRoom))
      .evaluate()
      .isNotEmpty;

  tearDown(() => Real4kChannels.ids.value = const {});

  testWidgets('a long 4K name wraps before the tag', (tester) async {
    final c = ch('TNT Sports Ultimate 4K UHD Extra Long');
    Real4kChannels.ids.value = {c.id};
    await pump(tester, c);
    expect(padded(tester), isTrue);
  });

  testWidgets('a short 4K name keeps its width', (tester) async {
    final c = ch('ESPN 2 4K');
    Real4kChannels.ids.value = {c.id};
    await pump(tester, c);
    expect(padded(tester), isFalse);
  });

  testWidgets('a long name without 4K keeps its width', (tester) async {
    await pump(tester, ch('TNT Sports Box Office FHD Extra Long'));
    expect(padded(tester), isFalse);
  });
}
