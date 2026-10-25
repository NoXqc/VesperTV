import 'dart:convert';
import 'trailer.dart';

/// Only a validated id and public app origin enter the official YouTube player.
/// No stream extraction, API key, add-on URL or playback credentials are used.
class YouTubeEmbedDocument {
  YouTubeEmbedDocument(String video, {this.muted = false, this.controls = true})
      : videoId = TrailerLinks.videoId(video) ??
            (throw ArgumentError('Invalid YouTube video id'));

  final String videoId;
  final bool muted;
  final bool controls;
  static final url = Uri.parse('https://vespertv.app/_local/youtube.html');
  Uri get externalUrl => Uri.https('www.youtube.com', '/watch', {'v': videoId});
  static bool needsExternalPlayer(int error) => error == 101 || error == 150;
  static String command(String action) => switch (action) {
        'toggle' => 'window.vesperToggle();',
        'back' => 'window.vesperSeek(-10);',
        'forward' => 'window.vesperSeek(10);',
        'pause' => 'window.vesperPause();',
        _ => throw ArgumentError('Unknown player command'),
      };

  String get html => '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body,#player{margin:0;width:100%;height:100%;background:black;overflow:hidden}</style>
</head><body><div id="player"></div><script>
var player,queued=[],bridgeReady=false;
function report(data){
  if(bridgeReady&&window.flutter_inappwebview&&window.flutter_inappwebview.callHandler){
    window.flutter_inappwebview.callHandler('YouTubeEvent',data);
  }else{queued.push(data);}
}
window.vesperBridgeConnected=function(){bridgeReady=true;var events=queued;queued=[];events.forEach(report);};
window.addEventListener('flutterInAppWebViewPlatformReady',window.vesperBridgeConnected);
function onYouTubeIframeAPIReady(){player=new YT.Player('player',{
  width:'100%',height:'100%',videoId:${jsonEncode(videoId)},
  playerVars:{autoplay:1,controls:${controls ? 1 : 0},disablekb:1,playsinline:1,origin:'https://vespertv.app'},
  events:{onReady:function(){${muted ? 'player.mute();' : ''}report({type:'ready'});player.playVideo();},
    onStateChange:function(event){if(event.data===1){report({type:'playing'});}if(event.data===0){report({type:'ended'});}},
    onError:function(event){report({type:'error',code:event.data});}}
});}
window.vesperToggle=function(){if(player&&player.getPlayerState){
  if(player.getPlayerState()===1){player.pauseVideo();}else{player.playVideo();}
}};
window.vesperSeek=function(delta){if(player&&player.getCurrentTime){
  player.seekTo(Math.max(0,player.getCurrentTime()+delta),true);
}};
window.vesperPause=function(){if(player&&player.pauseVideo){player.pauseVideo();}};
</script><script src="https://www.youtube.com/iframe_api"></script></body></html>''';
}
