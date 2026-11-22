import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tvos/flutter_tvos.dart';
import 'package:nox_iptv/services/apple_tv_remote.dart';

/// Siri Remote touch surface (Discord, itSoTek 2026-11-21: the slightest
/// touch moved the selection on an Apple TV 4K).
void main() {
  test('Normal is the default and calmer than the engine; High is stock', () {
    expect(AppleTvRemote.levelOf(null), AppleTvRemote.normal);
    expect(AppleTvRemote.levelOf('bogus'), AppleTvRemote.normal);
    const stock = TvRemoteConfig();
    final normal = AppleTvRemote.configFor(AppleTvRemote.normal);
    final low = AppleTvRemote.configFor(AppleTvRemote.low);
    final high = AppleTvRemote.configFor(AppleTvRemote.high);
    expect(high.shortSwipeThreshold, stock.shortSwipeThreshold);
    expect(
        high.continuousSwipeMoveThreshold, stock.continuousSwipeMoveThreshold);
    expect(normal.shortSwipeThreshold, greaterThan(stock.shortSwipeThreshold));
    expect(normal.continuousSwipeMoveThreshold,
        greaterThan(stock.continuousSwipeMoveThreshold));
    expect(low.shortSwipeThreshold, greaterThan(normal.shortSwipeThreshold));
    expect(low.continuousSwipeMoveThreshold,
        greaterThan(normal.continuousSwipeMoveThreshold));
    for (final c in [low, normal, high]) {
      expect(c.fastSwipeThreshold, greaterThanOrEqualTo(c.shortSwipeThreshold));
    }
  });

  test('applying off Apple TV does nothing', () {
    AppleTvRemote.apply(AppleTvRemote.low);
    expect(TvRemoteController.instance.config.shortSwipeThreshold,
        const TvRemoteConfig().shortSwipeThreshold);
  });
}
