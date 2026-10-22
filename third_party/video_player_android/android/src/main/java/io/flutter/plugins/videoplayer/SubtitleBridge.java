// VesperTV patch: embedded subtitle tracks (MKV/MP4 text tracks) for the Flutter side.
//
// The stock plugin exposes audio/video tracks only. This adds, beside the pigeon API:
//  * MethodChannel "vespertv/subtitles": getTextTracks(playerId) -> list of maps,
//    selectTextTrack(playerId, group, track) (group < 0 = subtitles off);
//  * EventChannel "vespertv/subtitles/cues": complete text/row snapshots, selected format and reset
//    events. Flutter draws the text and briefly bridges empty CEA-608/708 updates.
// Text tracks start disabled on every player (Multiview tiles and live channels never want them);
// selecting one enables the text renderer. Image subtitles (PGS/VobSub) are not listed: their
// cues are bitmaps, which this text-only bridge can't carry.

package io.flutter.plugins.videoplayer;

import android.util.LongSparseArray;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.Player;
import androidx.media3.common.TrackSelectionOverride;
import androidx.media3.common.Tracks;
import androidx.media3.common.text.Cue;
import androidx.media3.common.text.CueGroup;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;

@OptIn(markerClass = UnstableApi.class)
final class SubtitleBridge implements MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private final LongSparseArray<VideoPlayer> players;
  private final MethodChannel methods;
  private final EventChannel events;
  @Nullable private EventChannel.EventSink sink;
  private final Map<VideoPlayer, Selection> selections = new WeakHashMap<>();

  private static final class Selection {
    boolean enabled;
    @Nullable String mime;

    boolean isClosedCaption() {
      return MimeTypes.APPLICATION_CEA608.equals(mime) || MimeTypes.APPLICATION_CEA708.equals(mime);
    }
  }

  SubtitleBridge(@NonNull BinaryMessenger messenger, @NonNull LongSparseArray<VideoPlayer> players) {
    this.players = players;
    methods = new MethodChannel(messenger, "vespertv/subtitles");
    events = new EventChannel(messenger, "vespertv/subtitles/cues");
    methods.setMethodCallHandler(this);
    events.setStreamHandler(this);
  }

  void dispose() {
    methods.setMethodCallHandler(null);
    events.setStreamHandler(null);
    sink = null;
    selections.clear();
  }

  /** Called for every new player: text off, and its cues forwarded to Flutter. */
  void attach(@NonNull VideoPlayer player, long id) {
    Selection selection = new Selection();
    selections.put(player, selection);
    DefaultTrackSelector selector = player.trackSelector;
    if (selector != null) {
      selector.setParameters(
          selector.buildUponParameters().setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true).build());
    }
    player
        .getExoPlayer()
        .addListener(
            new Player.Listener() {
              @Override
              public void onCues(@NonNull CueGroup cueGroup) {
                sendCues(id, selection, cueGroup.cues, false);
              }
            });
  }

  private void sendCues(long id, Selection selection, List<Cue> cues, boolean reset) {
    EventChannel.EventSink s = sink;
    if (s == null) return;
    StringBuilder text = new StringBuilder();
    List<Map<String, Object>> rows = new ArrayList<>();
    if (selection.enabled && !reset) {
      for (Cue cue : cues) {
        if (cue.text == null) continue;
        if (text.length() > 0) text.append('\n');
        text.append(cue.text);
        Map<String, Object> row = new HashMap<>();
        row.put("text", cue.text.toString());
        if (cue.line != Cue.DIMEN_UNSET) {
          row.put("line", (double) cue.line);
          row.put("lineType", cue.lineType);
        }
        if (cue.position != Cue.DIMEN_UNSET) row.put("position", (double) cue.position);
        rows.add(row);
      }
    }
    Map<String, Object> event = new HashMap<>();
    event.put("playerId", id);
    event.put("text", text.toString());
    event.put("cues", rows);
    event.put("enabled", selection.enabled);
    event.put("cc", selection.isClosedCaption());
    event.put("mime", selection.mime);
    event.put("reset", reset);
    s.success(event);
  }

  private static boolean isTextFormat(@Nullable String mime) {
    return mime != null
        && !MimeTypes.APPLICATION_PGS.equals(mime)
        && !MimeTypes.APPLICATION_VOBSUB.equals(mime)
        && !MimeTypes.APPLICATION_DVBSUBS.equals(mime);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    Number idArg = call.argument("playerId");
    VideoPlayer player = idArg == null ? null : players.get(idArg.longValue());
    if (player == null) {
      result.error("no_player", "No player " + idArg, null);
      return;
    }
    switch (call.method) {
      case "getTextTracks":
        result.success(textTracks(player));
        break;
      case "selectTextTrack":
        Number group = call.argument("group");
        Number track = call.argument("track");
        try {
          select(
              player,
              idArg.longValue(),
              group == null ? -1 : group.intValue(),
              track == null ? 0 : track.intValue());
          result.success(null);
        } catch (RuntimeException e) {
          result.error("select_failed", e.getMessage(), null);
        }
        break;
      default:
        result.notImplemented();
    }
  }

  private static List<Map<String, Object>> textTracks(@NonNull VideoPlayer player) {
    List<Map<String, Object>> out = new ArrayList<>();
    Tracks tracks = player.getExoPlayer().getCurrentTracks();
    for (int g = 0; g < tracks.getGroups().size(); g++) {
      Tracks.Group group = tracks.getGroups().get(g);
      if (group.getType() != C.TRACK_TYPE_TEXT) continue;
      for (int t = 0; t < group.length; t++) {
        Format f = group.getTrackFormat(t);
        String mime = f.sampleMimeType != null ? f.sampleMimeType : f.codecs;
        if (!isTextFormat(mime)) continue;
        Map<String, Object> m = new HashMap<>();
        m.put("group", g);
        m.put("track", t);
        m.put("language", f.language);
        m.put("label", f.label);
        m.put("mime", mime);
        m.put("forced", (f.selectionFlags & C.SELECTION_FLAG_FORCED) != 0);
        // Live closed captions (see HttpVideoAsset.liveCaptionExtractors).
        m.put(
            "cc",
            MimeTypes.APPLICATION_CEA608.equals(mime) || MimeTypes.APPLICATION_CEA708.equals(mime));
        m.put("selected", group.isTrackSelected(t));
        out.add(m);
      }
    }
    return out;
  }

  private void select(@NonNull VideoPlayer player, long id, int groupIndex, int trackIndex) {
    DefaultTrackSelector selector = player.trackSelector;
    if (selector == null) throw new IllegalStateException("No track selector");
    Selection selection = selections.get(player);
    if (selection == null) throw new IllegalStateException("No subtitle bridge");
    if (groupIndex < 0) {
      selector.setParameters(
          selector
              .buildUponParameters()
              .clearOverridesOfType(C.TRACK_TYPE_TEXT)
              .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
              .build());
      selection.enabled = false;
      selection.mime = null;
      sendCues(id, selection, Collections.emptyList(), true);
      return;
    }
    Tracks tracks = player.getExoPlayer().getCurrentTracks();
    if (groupIndex >= tracks.getGroups().size()) {
      throw new IllegalArgumentException("groupIndex out of range");
    }
    Tracks.Group group = tracks.getGroups().get(groupIndex);
    if (group.getType() != C.TRACK_TYPE_TEXT || trackIndex < 0 || trackIndex >= group.length) {
      throw new IllegalArgumentException("not a text track");
    }
    selector.setParameters(
        selector
            .buildUponParameters()
            .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
            .setOverrideForType(new TrackSelectionOverride(group.getMediaTrackGroup(), trackIndex))
            .build());
    Format format = group.getTrackFormat(trackIndex);
    selection.enabled = true;
    selection.mime = format.sampleMimeType != null ? format.sampleMimeType : format.codecs;
    // Format only: never log caption text, stream URLs or user credentials.
    Log.i(
        "VesperSubtitles",
        "player=" + id + " mime=" + selection.mime + " cc=" + selection.isClosedCaption());
    sendCues(id, selection, Collections.emptyList(), true);
  }

  @Override
  public void onListen(Object arguments, EventChannel.EventSink events) {
    sink = events;
  }

  @Override
  public void onCancel(Object arguments) {
    sink = null;
  }
}
