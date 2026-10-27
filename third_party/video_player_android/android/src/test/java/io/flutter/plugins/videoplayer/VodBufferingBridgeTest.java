package io.flutter.plugins.videoplayer;

import static org.mockito.Mockito.*;
import android.util.LongSparseArray;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.Map;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 30)
public final class VodBufferingBridgeTest {
  @Test public void explicitModeTargetsOnlyRequestedPlayerAndDoesNotEnableFiniteRecovery() {
    VideoPlayer player = mock(VideoPlayer.class);
    VideoPlayer other = mock(VideoPlayer.class);
    LongSparseArray<VideoPlayer> players = new LongSparseArray<>();
    players.put(7, player);
    players.put(8, other);
    StatsBridge bridge = new StatsBridge(mock(BinaryMessenger.class), players);
    MethodChannel.Result result = mock(MethodChannel.Result.class);
    bridge.onMethodCall(new MethodCall("setOnDemandBuffering",
        Map.of("playerId", 7, "on", true)), result);
    verify(player).setOnDemandBuffering(true);
    verify(player, never()).setFiniteMode(anyBoolean());
    verifyNoInteractions(other);
    verify(result).success(null);
    bridge.dispose();
  }

  @Test public void missingPlayerHasTheExistingBridgeError() {
    StatsBridge bridge = new StatsBridge(mock(BinaryMessenger.class), new LongSparseArray<>());
    MethodChannel.Result result = mock(MethodChannel.Result.class);
    bridge.onMethodCall(new MethodCall("setOnDemandBuffering",
        Map.of("playerId", 7, "on", true)), result);
    verify(result).error(eq("no_player"), anyString(), isNull());
    bridge.dispose();
  }
}
