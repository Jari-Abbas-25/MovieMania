class CatalogMediaItem {
  final String id;
  final String title;
  final int? year;
  final String? poster;
  final String provider;
  final bool isSeries;
  final String? rating;

  CatalogMediaItem({
    required this.id,
    required this.title,
    this.year,
    this.poster,
    required this.provider,
    required this.isSeries,
    this.rating,
  });

  factory CatalogMediaItem.fromJson(Map<String, dynamic> json) {
    String idVal = '';
    String providerVal = 'moviebox';

    if (json['id'] is Map) {
      final idMap = json['id'] as Map<String, dynamic>;
      idVal = (idMap['value'] ?? idMap['id'] ?? '').toString();
      providerVal = (idMap['provider'] ?? 'moviebox').toString().toLowerCase();
    } else if (json['id'] != null) {
      idVal = json['id'].toString();
    } else if (json['subject_id'] != null) {
      idVal = json['subject_id'].toString();
    }

    if (json['provider'] != null && json['provider'] is String) {
      providerVal = json['provider'].toString().toLowerCase();
    }

    final rawType = json['media_type'] ?? json['subject_type'] ?? json['type'];
    bool isSeries = false;
    if (rawType is int) {
      isSeries = rawType == 2;
    } else if (rawType is String) {
      final lower = rawType.toLowerCase();
      isSeries = lower == 'series' || lower.contains('series') || lower.contains('tv') || lower == '2';
    }

    return CatalogMediaItem(
      id: idVal,
      title: (json['title'] ?? json['name'] ?? 'Untitled').toString(),
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? ''),
      poster: json['poster_url']?.toString() ?? json['poster']?.toString(),
      provider: providerVal,
      isSeries: isSeries,
      rating: json['imdb_rating']?.toString() ?? json['rating']?.toString(),
    );
  }
}

class AudioTrackInfo {
  final String subjectId;
  final String language;
  final String label;

  AudioTrackInfo({
    required this.subjectId,
    required this.language,
    required this.label,
  });

  factory AudioTrackInfo.fromJson(Map<String, dynamic> json) {
    return AudioTrackInfo(
      subjectId: (json['subject_id'] ?? json['id'] ?? '').toString(),
      language: (json['language'] ?? 'Default').toString(),
      label: (json['label'] ?? json['language'] ?? 'Default').toString(),
    );
  }
}

class SubtitleTrackInfo {
  final String name;
  final String url;

  SubtitleTrackInfo({
    required this.name,
    required this.url,
  });

  factory SubtitleTrackInfo.fromJson(Map<String, dynamic> json) {
    return SubtitleTrackInfo(
      name: (json['name'] ?? json['language'] ?? json['label'] ?? 'Unknown').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }
}

class MediaDetailInfo {
  final String id;
  final String title;
  final int? year;
  final String? poster;
  final String? backdrop;
  final String description;
  final String provider;
  final bool isSeries;
  final List<String> genres;
  final List<SeasonInfo> seasons;
  final List<AudioTrackInfo> dubs;

  MediaDetailInfo({
    required this.id,
    required this.title,
    this.year,
    this.poster,
    this.backdrop,
    required this.description,
    required this.provider,
    required this.isSeries,
    required this.genres,
    required this.seasons,
    this.dubs = const [],
  });

  factory MediaDetailInfo.fromJson(Map<String, dynamic> json, String fallbackProvider) {
    String idVal = '';
    String providerVal = fallbackProvider;

    if (json['id'] is Map) {
      final idMap = json['id'] as Map<String, dynamic>;
      idVal = (idMap['value'] ?? idMap['id'] ?? '').toString();
      providerVal = (idMap['provider'] ?? fallbackProvider).toString().toLowerCase();
    } else if (json['id'] != null) {
      idVal = json['id'].toString();
    } else if (json['subject_id'] != null) {
      idVal = json['subject_id'].toString();
    }

    if (json['provider'] != null && json['provider'] is String) {
      providerVal = json['provider'].toString().toLowerCase();
    }

    final rawType = json['media_type'] ?? json['subject_type'] ?? json['type'];
    bool isSeries = false;
    if (json['is_series'] is bool) {
      isSeries = json['is_series'];
    } else if (rawType is int) {
      isSeries = rawType == 2;
    } else if (rawType is String) {
      final lower = rawType.toLowerCase();
      isSeries = lower == 'series' || lower.contains('series') || lower.contains('tv') || lower == '2';
    }

    final genresList = <String>[];
    if (json['genres'] is List) {
      for (final g in json['genres']) {
        if (g != null && g.toString().isNotEmpty) genresList.add(g.toString());
      }
    }

    final seasonsList = <SeasonInfo>[];
    if (json['seasons'] is List) {
      for (final s in json['seasons']) {
        if (s is Map<String, dynamic>) {
          seasonsList.add(SeasonInfo.fromJson(s));
        }
      }
    }

    final dubsList = <AudioTrackInfo>[];
    if (json['dubs'] is List) {
      for (final d in json['dubs']) {
        if (d is Map<String, dynamic>) {
          dubsList.add(AudioTrackInfo.fromJson(d));
        }
      }
    }

    return MediaDetailInfo(
      id: idVal,
      title: (json['title'] ?? json['name'] ?? 'Untitled').toString(),
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? ''),
      poster: json['poster_url']?.toString() ?? json['poster']?.toString(),
      backdrop: json['backdrop_url']?.toString() ?? json['backdrop']?.toString() ?? json['poster_url']?.toString(),
      description: (json['description'] ?? json['synopsis'] ?? json['overview'] ?? 'No description available.').toString(),
      provider: providerVal,
      isSeries: isSeries || seasonsList.isNotEmpty,
      genres: genresList,
      seasons: seasonsList,
      dubs: dubsList,
    );
  }
}

class SeasonInfo {
  final int seasonNumber;
  final String? title;
  final List<EpisodeInfo> episodes;

  SeasonInfo({
    required this.seasonNumber,
    this.title,
    required this.episodes,
  });

  factory SeasonInfo.fromJson(Map<String, dynamic> json) {
    final epList = <EpisodeInfo>[];
    if (json['episodes'] is List) {
      for (final ep in json['episodes']) {
        if (ep is Map<String, dynamic>) {
          epList.add(EpisodeInfo.fromJson(ep));
        }
      }
    }

    final sNum = json['number'] ?? json['season_number'] ?? json['season'] ?? 1;
    final parsedNum = sNum is int ? sNum : int.tryParse(sNum.toString()) ?? 1;

    return SeasonInfo(
      seasonNumber: parsedNum,
      title: json['title']?.toString() ?? 'Season $parsedNum',
      episodes: epList,
    );
  }
}

class EpisodeInfo {
  final int episodeNumber;
  final String title;
  final String? id;

  EpisodeInfo({
    required this.episodeNumber,
    required this.title,
    this.id,
  });

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    final epNum = json['number'] ?? json['episode_number'] ?? json['episode'] ?? 1;
    final parsedNum = epNum is int ? epNum : int.tryParse(epNum.toString()) ?? 1;
    return EpisodeInfo(
      episodeNumber: parsedNum,
      title: (json['title'] ?? json['name'] ?? 'Episode $parsedNum').toString(),
      id: json['id']?.toString() ?? json['episode_id']?.toString(),
    );
  }
}

class ReleaseSource {
  final String title;
  final String? quality;
  final List<String> qualities;
  final String provider;
  final String? resourceId;
  final Map<String, dynamic> rawJson;

  ReleaseSource({
    required this.title,
    this.quality,
    this.qualities = const [],
    required this.provider,
    this.resourceId,
    required this.rawJson,
  });

  factory ReleaseSource.fromJson(Map<String, dynamic> json, String defaultProvider) {
    final qualitiesList = <String>[];
    if (json['qualities'] is List) {
      for (final q in json['qualities']) {
        if (q != null && q.toString().isNotEmpty) {
          qualitiesList.add(q.toString());
        }
      }
    }
    return ReleaseSource(
      title: (json['title'] ?? json['source_label'] ?? json['filename'] ?? 'Standard Stream').toString(),
      quality: json['quality']?.toString() ?? json['resolution']?.toString(),
      qualities: qualitiesList,
      provider: (json['provider'] ?? defaultProvider).toString(),
      resourceId: json['resource_id']?.toString(),
      rawJson: json,
    );
  }
}

class PlaybackSourceInfo {
  final String url;
  final String provider;
  final Map<String, String> headers;
  final String? subtitleUrl;
  final String sourceLabel;

  PlaybackSourceInfo({
    required this.url,
    required this.provider,
    required this.headers,
    this.subtitleUrl,
    required this.sourceLabel,
  });

  factory PlaybackSourceInfo.fromJson(Map<String, dynamic> json) {
    final headersMap = <String, String>{};
    if (json['headers'] is List) {
      for (final h in json['headers']) {
        if (h is List && h.length >= 2) {
          headersMap[h[0].toString()] = h[1].toString();
        }
      }
    } else if (json['headers'] is Map) {
      json['headers'].forEach((k, v) {
        if (k != null && v != null) {
          headersMap[k.toString()] = v.toString();
        }
      });
    }

    return PlaybackSourceInfo(
      url: (json['url'] ?? '').toString(),
      provider: (json['provider'] ?? 'moviebox').toString(),
      headers: headersMap,
      subtitleUrl: json['subtitle']?.toString(),
      sourceLabel: (json['source_label'] ?? json['label'] ?? 'Default').toString(),
    );
  }
}
