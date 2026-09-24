import 'dart:convert';

class MovieBoxNative {
  static final MovieBoxNative _instance = MovieBoxNative._internal();
  factory MovieBoxNative() => _instance;

  MovieBoxNative._internal();

  static const String _sample1080p = 'https://vjs.zencdn.net/v/oceans.mp4';
  static const String _sample720p = 'https://vjs.zencdn.net/v/oceans.mp4';
  static const String _sample480p = 'https://vjs.zencdn.net/v/oceans.mp4';
  static const String _sample360p = 'https://vjs.zencdn.net/v/oceans.mp4';

  String init({String? dataDir, String? cacheDir}) {
    return jsonEncode({
      'success': true,
      'message': 'Web development environment initialized',
    });
  }

  String homepage({String tabId = 'movie', int page = 1}) {
    return jsonEncode({
      'success': true,
      'items': [
        {
          'id': 'mock-avengers-infinity-war',
          'title': 'Avengers: Infinity War (Chrome Dev)',
          'media_type': 'movie',
          'year': 2018,
          'rating': '8.4',
          'poster_url': 'https://image.tmdb.org/t/p/w500/7WsyChQLEftFiDOVTGkv3hFpyyt.jpg',
          'provider': 'moviebox',
          'overview': 'The Avengers and their allies must be willing to sacrifice all in an attempt to defeat the powerful Thanos.',
        },
        {
          'id': 'mock-inception',
          'title': 'Inception',
          'media_type': 'movie',
          'year': 2010,
          'rating': '8.8',
          'poster_url': 'https://image.tmdb.org/t/p/w500/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg',
          'provider': 'moviebox',
          'overview': 'A thief steals corporate secrets through dream-sharing technology.',
        },
        {
          'id': 'mock-breaking-bad',
          'title': 'Breaking Bad',
          'media_type': 'tv',
          'year': 2008,
          'rating': '9.5',
          'poster_url': 'https://image.tmdb.org/t/p/w500/ggFHVNu6YYI5L9pCfOacjizRGt.jpg',
          'provider': 'moviebox',
          'overview': 'A chemistry teacher diagnosed with lung cancer turns to making methamphetamine.',
        },
      ],
      'metrics': {}
    });
  }

  String search(String query, {String provider = 'moviebox', int page = 1}) {
    final q = query.trim().toLowerCase();
    final results = <Map<String, dynamic>>[];

    if (q.contains('avenger')) {
      results.addAll([
        {
          'id': 'mock-avengers-infinity-war',
          'title': 'Avengers: Infinity War',
          'media_type': 'movie',
          'year': 2018,
          'rating': '8.4',
          'poster_url': 'https://image.tmdb.org/t/p/w500/7WsyChQLEftFiDOVTGkv3hFpyyt.jpg',
          'provider': provider,
          'overview': 'The Avengers and their allies must be willing to sacrifice all in an attempt to defeat Thanos.',
        },
        {
          'id': 'mock-avengers-endgame',
          'title': 'Avengers: Endgame',
          'media_type': 'movie',
          'year': 2019,
          'rating': '8.4',
          'poster_url': 'https://image.tmdb.org/t/p/w500/or06FN3Dka5tukK1e9sl16pB3iy.jpg',
          'provider': provider,
          'overview': 'After the devastating events of Infinity War, the universe is in ruins.',
        },
        {
          'id': 'mock-avengers-1',
          'title': 'The Avengers',
          'media_type': 'movie',
          'year': 2012,
          'rating': '8.0',
          'poster_url': 'https://image.tmdb.org/t/p/w500/RYMX2wcKCBAr24UyPD7xwmjaTn.jpg',
          'provider': provider,
          'overview': 'Earth\'s mightiest heroes must come together and learn to fight as a team.',
        },
      ]);
    } else if (q.contains('inception')) {
      results.add({
        'id': 'mock-inception',
        'title': 'Inception',
        'media_type': 'movie',
        'year': 2010,
        'rating': '8.8',
        'poster_url': 'https://image.tmdb.org/t/p/w500/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg',
        'provider': provider,
        'overview': 'A thief who steals corporate secrets through dream-sharing technology.',
      });
    } else if (q.contains('breaking') || q.contains('bad')) {
      results.add({
        'id': 'mock-breaking-bad',
        'title': 'Breaking Bad',
        'media_type': 'tv',
        'year': 2008,
        'rating': '9.5',
        'poster_url': 'https://image.tmdb.org/t/p/w500/ggFHVNu6YYI5L9pCfOacjizRGt.jpg',
        'provider': provider,
        'overview': 'A chemistry teacher diagnosed with inoperable lung cancer turns to manufacturing methamphetamine.',
      });
    } else {
      results.addAll([
        {
          'id': 'mock-movie-${query.hashCode}',
          'title': query,
          'media_type': 'movie',
          'year': 2024,
          'rating': '8.1',
          'poster_url': 'https://image.tmdb.org/t/p/w500/RYMX2wcKCBAr24UyPD7xwmjaTn.jpg',
          'provider': provider,
          'overview': 'Movie result for query "$query".',
        },
        {
          'id': 'mock-tv-${query.hashCode}',
          'title': '$query: The Series',
          'media_type': 'tv',
          'year': 2023,
          'rating': '8.6',
          'poster_url': 'https://image.tmdb.org/t/p/w500/ggFHVNu6YYI5L9pCfOacjizRGt.jpg',
          'provider': provider,
          'overview': 'TV Show series for query "$query".',
        }
      ]);
    }

    return jsonEncode({
      'success': true,
      'results': results,
    });
  }

  String suggest(String query) {
    return jsonEncode({
      'success': true,
      'suggestions': [
        '$query 2024',
        '$query series',
        '$query movie',
        '$query 4k',
      ]
    });
  }

  String details(String id, {String provider = 'moviebox'}) {
    final isTv = id.contains('tv') || id.contains('breaking') || id.contains('series');
    final title = id.contains('endgame')
        ? 'Avengers: Endgame'
        : id.contains('infinity')
            ? 'Avengers: Infinity War'
            : id.contains('inception')
                ? 'Inception'
                : id.contains('breaking')
                    ? 'Breaking Bad'
                    : isTv
                        ? 'Mock TV Series'
                        : 'The Avengers';

    final poster = id.contains('endgame')
        ? 'https://image.tmdb.org/t/p/w500/or06FN3Dka5tukK1e9sl16pB3iy.jpg'
        : id.contains('inception')
            ? 'https://image.tmdb.org/t/p/w500/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg'
            : id.contains('breaking')
                ? 'https://image.tmdb.org/t/p/w500/ggFHVNu6YYI5L9pCfOacjizRGt.jpg'
                : 'https://image.tmdb.org/t/p/w500/RYMX2wcKCBAr24UyPD7xwmjaTn.jpg';

    return jsonEncode({
      'success': true,
      'details': {
        'id': id,
        'title': title,
        'media_type': isTv ? 'tv' : 'movie',
        'is_series': isTv,
        'year': isTv ? 2008 : 2018,
        'rating': isTv ? '9.5' : '8.4',
        'duration': isTv ? '45 min' : '149 min',
        'genres': ['Action', 'Adventure', 'Sci-Fi'],
        'description': isTv
            ? 'A high school chemistry teacher diagnosed with terminal lung cancer teams up with a former student to manufacture methamphetamine.'
            : 'The Avengers and their allies must be willing to sacrifice all in an attempt to defeat the powerful Thanos before his blitz of devastation puts an end to the universe.',
        'poster_url': poster,
        'backdrop_url': 'https://image.tmdb.org/t/p/w1280/7RyHsO4yDXtBv1zUU3mTpHeQ0d5.jpg',
        'provider': provider,
        'seasons': isTv
            ? [
                {
                  'season_number': 1,
                  'title': 'Season 1',
                  'episodes': [
                    {'episode_number': 1, 'title': 'Pilot'},
                    {'episode_number': 2, 'title': 'Cat\'s in the Bag...'},
                    {'episode_number': 3, 'title': '...And the Bag\'s in the River'},
                  ]
                },
                {
                  'season_number': 2,
                  'title': 'Season 2',
                  'episodes': [
                    {'episode_number': 1, 'title': 'Seven Thirty-Seven'},
                    {'episode_number': 2, 'title': 'Grilled'},
                  ]
                }
              ]
            : [],
      }
    });
  }

  String episodeStreams(String id, int season, int episode,
      {String provider = 'moviebox'}) {
    final labelSuffix = season > 0 ? ' (S${season}E$episode)' : '';
    return jsonEncode({
      'success': true,
      'releases': [
        {
          'title': '1080p FHD (Browser MP4)$labelSuffix',
          'quality': '1080p',
          'source_label': '1080p FHD (Browser MP4)$labelSuffix',
          'provider': provider,
          'url': _sample1080p,
          'headers': {},
        },
        {
          'title': '720p HD (Browser MP4)$labelSuffix',
          'quality': '720p',
          'source_label': '720p HD (Browser MP4)$labelSuffix',
          'provider': provider,
          'url': _sample720p,
          'headers': {},
        },
        {
          'title': '480p SD (Browser MP4)$labelSuffix',
          'quality': '480p',
          'source_label': '480p SD (Browser MP4)$labelSuffix',
          'provider': provider,
          'url': _sample480p,
          'headers': {},
        },
        {
          'title': '360p Low (Browser MP4)$labelSuffix',
          'quality': '360p',
          'source_label': '360p Low (Browser MP4)$labelSuffix',
          'provider': provider,
          'url': _sample360p,
          'headers': {},
        },
      ]
    });
  }

  String resolveStream(String releaseJson, {String provider = 'moviebox', String intent = 'playback'}) {
    Map<String, dynamic> releaseMap = {};
    try {
      releaseMap = jsonDecode(releaseJson) as Map<String, dynamic>;
    } catch (_) {}

    final chosenUrl = releaseMap['url']?.toString().isNotEmpty == true
        ? releaseMap['url'].toString()
        : _sample1080p;

    return jsonEncode({
      'success': true,
      'source': {
        'url': chosenUrl,
        'provider': provider,
        'headers': {},
        'subtitle': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/subtitles.vtt',
        'source_label': releaseMap['source_label'] ?? releaseMap['title'] ?? '1080p FHD',
      }
    });
  }

  String getCaptions(String subjectId, String resourceId,
      {List<String> siblingIds = const [], int season = 0, int episode = 0}) {
    return jsonEncode({
      'success': true,
      'captions': [
        {'language': 'English', 'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/subtitles.vtt', 'format': 'vtt'},
      ]
    });
  }

  String startProxy(String targetUrl,
      {Map<String, String> headers = const {}, String? subtitleUrl}) {
    return jsonEncode({
      'success': true,
      'proxy_url': _sample1080p,
      'port': 8888,
    });
  }
}
