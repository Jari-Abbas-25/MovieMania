import 'package:flutter_test/flutter_test.dart';
import 'package:moviebox_app/core/models/media_models.dart';

void main() {
  test('CatalogMediaItem fromJson parses correctly', () {
    final json = {
      'id': 'mock-avengers',
      'title': 'The Avengers',
      'media_type': 'movie',
      'year': 2012,
      'rating': '8.0',
      'poster_url': 'https://image.tmdb.org/t/p/w500/test.jpg',
      'provider': 'moviebox',
    };

    final item = CatalogMediaItem.fromJson(json);
    expect(item.id, 'mock-avengers');
    expect(item.title, 'The Avengers');
    expect(item.isSeries, false);
    expect(item.year, 2012);
  });

  test('MediaDetailInfo fromJson parses movie and TV correctly', () {
    final json = {
      'id': 'mock-breaking-bad',
      'title': 'Breaking Bad',
      'media_type': 'tv',
      'is_series': true,
      'year': 2008,
      'genres': ['Drama', 'Crime'],
      'seasons': [
        {
          'season_number': 1,
          'title': 'Season 1',
          'episodes': [
            {'episode_number': 1, 'title': 'Pilot'},
          ]
        }
      ]
    };

    final details = MediaDetailInfo.fromJson(json, 'moviebox');
    expect(details.id, 'mock-breaking-bad');
    expect(details.isSeries, true);
    expect(details.genres, contains('Drama'));
    expect(details.seasons.length, 1);
    expect(details.seasons.first.episodes.length, 1);
  });
}
