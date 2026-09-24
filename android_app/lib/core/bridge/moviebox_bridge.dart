import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'desktop_bridge_client.dart';
import 'moviebox_native.dart';

class BridgeResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  BridgeResponse({required this.success, this.data, this.error});

  factory BridgeResponse.fromJson(
      String rawJson, T Function(dynamic json) parser) {
    try {
      final Map<String, dynamic> map = jsonDecode(rawJson);
      final bool success = map['success'] == true;
      if (success) {
        return BridgeResponse(
          success: true,
          data: parser(map),
        );
      } else {
        return BridgeResponse(
          success: false,
          error: map['error']?.toString() ?? 'Unknown error from Rust core',
        );
      }
    } catch (e) {
      return BridgeResponse(
        success: false,
        error: 'JSON parse failure: $e',
      );
    }
  }
}

class MovieBoxBridge {
  static final MovieBoxBridge _instance = MovieBoxBridge._internal();
  factory MovieBoxBridge() => _instance;

  static final MovieBoxNative _native = MovieBoxNative();
  static bool _initialized = false;

  MovieBoxBridge._internal();

  static bool get isInitialized => _initialized;

  static Future<Map<String, dynamic>> init({String? dataDir, String? cacheDir}) async {
    if (kIsWeb) {
      final health = await DesktopBridgeClient.get('/health');
      _initialized = true;
      return {
        'success': true,
        'desktop_bridge': health,
      };
    }

    return Future(() {
      try {
        final raw = _native.init(dataDir: dataDir, cacheDir: cacheDir);
        final Map<String, dynamic> map = jsonDecode(raw);
        if (map['success'] == true) {
          _initialized = true;
        }
        return map;
      } catch (e) {
        return {'success': false, 'error': 'Init error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> homepage({String tab = 'movie', int page = 1}) async {
    if (kIsWeb) {
      final res = await DesktopBridgeClient.post('/api/homepage', {'tab': tab, 'page': page});
      if (res['success'] == true) {
        return res;
      }
    }

    return Future(() {
      try {
        final raw = _native.homepage(tabId: tab, page: page);
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Homepage error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> search({
    String provider = 'moviebox',
    required String query,
    int page = 1,
  }) async {
    if (kIsWeb) {
      final res = await DesktopBridgeClient.post('/api/search', {
        'query': query,
        'provider': provider,
        'page': page,
      });
      if (res['success'] == true) {
        return res;
      }
    }

    return Future(() {
      try {
        final raw = _native.search(query, provider: provider, page: page);
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Search error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> suggest(String query) async {
    return Future(() {
      try {
        final raw = _native.suggest(query);
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Suggest error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> details({
    String provider = 'moviebox',
    required String id,
  }) async {
    if (kIsWeb) {
      final res = await DesktopBridgeClient.post('/api/details', {
        'id': id,
        'provider': provider,
      });
      if (res['success'] == true) {
        return res;
      }
    }

    return Future(() {
      try {
        final raw = _native.details(id, provider: provider);
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Details error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> episodeStreams({
    String provider = 'moviebox',
    required String id,
    int season = 0,
    int episode = 0,
  }) async {
    if (kIsWeb) {
      final res = await DesktopBridgeClient.post('/api/episode_streams', {
        'id': id,
        'provider': provider,
        'season': season,
        'episode': episode,
      });
      if (res['success'] == true) {
        return res;
      }
    }

    return Future(() {
      try {
        final raw = _native.episodeStreams(id, season, episode, provider: provider);
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Episode streams error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> resolveStream({
    String provider = 'moviebox',
    required Map<String, dynamic> release,
    String intent = 'playback',
  }) async {
    if (kIsWeb) {
      final res = await DesktopBridgeClient.post('/api/resolve_stream', {
        'release': release,
        'provider': provider,
      });
      if (res['success'] == true) {
        return res;
      }
    }

    return Future(() {
      try {
        final rawRelease = jsonEncode(release);
        final raw = _native.resolveStream(rawRelease, provider: provider, intent: intent);
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Resolve stream error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> getCaptions({
    required String subjectId,
    required String resourceId,
    List<String> siblingIds = const [],
    int season = 0,
    int episode = 0,
  }) async {
    if (kIsWeb) {
      final res = await DesktopBridgeClient.post('/api/captions', {
        'subject_id': subjectId,
        'resource_id': resourceId,
        'sibling_ids': siblingIds,
        'season': season,
        'episode': episode,
      });
      if (res['success'] == true) {
        return res;
      }
    }

    return Future(() {
      try {
        final raw = _native.getCaptions(subjectId, resourceId, siblingIds: siblingIds, season: season, episode: episode);
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Get captions error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> startProxy({
    required String targetUrl,
    List<List<String>> headers = const [],
    String? subtitleUrl,
  }) async {
    return Future(() {
      try {
        final mapHeaders = <String, String>{};
        for (final pair in headers) {
          if (pair.length >= 2) {
            mapHeaders[pair[0]] = pair[1];
          }
        }
        final raw = _native.startProxy(targetUrl, headers: mapHeaders, subtitleUrl: subtitleUrl);
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        return {'success': false, 'error': 'Start proxy error: $e'};
      }
    });
  }

  static Future<Map<String, dynamic>> launchDesktopPlayer({
    required String title,
    required String url,
    Map<String, String> headers = const {},
    String? subtitleUrl,
    String provider = 'moviebox',
    String? subjectId,
    int season = 0,
    int episode = 0,
  }) async {
    return DesktopBridgeClient.post('/api/play', {
      'title': title,
      'url': url,
      'headers': headers,
      'subtitle': subtitleUrl,
      'provider': provider,
      'subject_id': subjectId,
      'season': season,
      'episode': episode,
    });
  }
}
