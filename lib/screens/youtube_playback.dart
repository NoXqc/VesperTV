import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../models/youtube_embed.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/desktop_mini_player.dart';
import '../services/playback_service.dart';
import 'youtube_player_screen.dart';

Future<void> playYouTubeVideo(
    BuildContext context, String id, String title) async {
  if (!Platform.isAndroid && !Platform.isWindows) {
    await launchUrl(YouTubeEmbedDocument(id).externalUrl,
        mode: LaunchMode.externalApplication);
    return;
  }
  if (Platform.isWindows) {
    await DesktopMiniPlayer.instance.controller?.player.pause();
  } else {
    await context.read<PlaybackService?>()?.controller?.pause();
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => YouTubePlayerScreen(videoId: id, title: title)));
}
