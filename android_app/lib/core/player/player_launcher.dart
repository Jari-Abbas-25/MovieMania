import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bridge/moviebox_bridge.dart';
import '../models/media_models.dart';
import 'web_video_modal.dart';

enum TargetPlayer {
  mpv,
  vlc,
  chooser,
}

class PlayerLauncher {
  static const MethodChannel _channel = MethodChannel('com.moviebox.app/player');

  static Future<bool> isPlayerInstalled(TargetPlayer player) async {
    if (kIsWeb) return true;
    if (player == TargetPlayer.chooser) return true;
    try {
      final name = player == TargetPlayer.mpv ? 'mpv' : 'vlc';
      final bool? result = await _channel.invokeMethod<bool>('isPlayerInstalled', {'player': name});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Resolves the stream, determines if in-process proxy is needed for headers/DASH, and launches player.
  static Future<void> playStream({
    required BuildContext context,
    required String title,
    required PlaybackSourceInfo source,
    TargetPlayer player = TargetPlayer.chooser,
  }) async {
    String playbackUrl = source.url;

    // Check if we need to route through the in-process proxy (for DASH or if headers/cookies exist)
    final needsProxy = source.headers.isNotEmpty ||
        source.url.contains('.mpd') ||
        source.url.contains('dash') ||
        source.url.contains('cloudfront') ||
        source.provider.toLowerCase() == 'moviebox';

    if (needsProxy && !kIsWeb) {
      try {
        final headersList = source.headers.entries
            .map((e) => [e.key, e.value])
            .toList();

        final proxyResult = await MovieBoxBridge.startProxy(
          targetUrl: source.url,
          headers: headersList,
          subtitleUrl: source.subtitleUrl,
        );

        if (proxyResult['success'] == true && proxyResult['proxy_url'] != null) {
          playbackUrl = proxyResult['proxy_url'].toString();
        }
      } catch (e) {
        // Fallback to direct URL if proxy fails to bind
        debugPrint('[PlayerLauncher] In-process proxy start error: $e. Falling back to direct URL.');
      }
    }

    final playerName = player == TargetPlayer.mpv
        ? 'mpv'
        : player == TargetPlayer.vlc
            ? 'vlc'
            : 'chooser';

    if (kIsWeb) {
      if (player == TargetPlayer.chooser) {
        if (context.mounted) {
          showWebVideoModal(
            context,
            title: title,
            videoUrl: playbackUrl,
            subtitleUrl: source.subtitleUrl,
            playerName: 'Browser Preview',
          );
        }
        return;
      }

      // Try launching Windows mpv via the local desktop bridge
      final res = await MovieBoxBridge.launchDesktopPlayer(
        title: title,
        url: source.url,
        headers: source.headers,
        subtitleUrl: source.subtitleUrl,
        provider: source.provider,
      );

      if (res['success'] == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.play_circle_fill, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Launched Windows mpv for "$title"'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1E1E),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        final errorMsg = res['error']?.toString() ?? 'Could not launch desktop mpv.';
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Row(
                children: [
                  Icon(Icons.desktop_windows, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text('Windows Desktop mpv', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMsg,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'cargo run -- --dev-bridge',
                      style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showWebVideoModal(
                      context,
                      title: title,
                      videoUrl: playbackUrl,
                      subtitleUrl: source.subtitleUrl,
                      playerName: 'Browser Preview',
                    );
                  },
                  child: const Text('Open Browser Preview', style: TextStyle(color: Colors.blueAccent)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          );
        }
      }
      return;
    }

    try {
      await _channel.invokeMethod('launchPlayer', {
        'url': playbackUrl,
        'player': playerName,
        'title': title,
        'headers': source.headers,
        'subtitleUrl': source.subtitleUrl,
      });
    } on PlatformException catch (e) {
      if (e.code == 'PLAYER_NOT_INSTALLED') {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text('$playerName is not installed', style: const TextStyle(color: Colors.white)),
              content: Text(
                'Please install $playerName from the Play Store / F-Droid, or choose another player.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Retry with system chooser
                    playStream(
                      context: context,
                      title: title,
                      source: source,
                      player: TargetPlayer.chooser,
                    );
                  },
                  child: const Text('Open with Other Player', style: TextStyle(color: Colors.blueAccent)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to launch player: ${e.message}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Shows player choice modal sheet (mpv, VLC, or System Chooser)
  static void showPlayerChoiceSheet({
    required BuildContext context,
    required String title,
    required PlaybackSourceInfo source,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Play: $title',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                'Source: ${source.sourceLabel} (${source.provider})',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const Divider(color: Colors.white24, height: 24),
              ListTile(
                leading: const Icon(Icons.play_circle_fill, color: Colors.deepOrangeAccent, size: 28),
                title: const Text('Play with mpv', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Recommended for DASH & subtitles', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  playStream(
                    context: context,
                    title: title,
                    source: source,
                    player: TargetPlayer.mpv,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.traffic, color: Colors.orangeAccent, size: 28),
                title: const Text('Play with VLC', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Standard Android external player', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  playStream(
                    context: context,
                    title: title,
                    source: source,
                    player: TargetPlayer.vlc,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 28),
                title: const Text('Choose Other Player...', style: TextStyle(color: Colors.white)),
                subtitle: const Text('System player chooser', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  playStream(
                    context: context,
                    title: title,
                    source: source,
                    player: TargetPlayer.chooser,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
