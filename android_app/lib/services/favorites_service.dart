import 'package:flutter/foundation.dart';
import '../core/models/media_models.dart';

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final Map<String, CatalogMediaItem> _favorites = {};

  List<CatalogMediaItem> get items => _favorites.values.toList();
  int get count => _favorites.length;

  bool isFavorite(String id) => _favorites.containsKey(id);

  void toggleFavorite(CatalogMediaItem item) {
    if (_favorites.containsKey(item.id)) {
      _favorites.remove(item.id);
    } else {
      _favorites[item.id] = item;
    }
    notifyListeners();
  }

  void add(CatalogMediaItem item) {
    if (!_favorites.containsKey(item.id)) {
      _favorites[item.id] = item;
      notifyListeners();
    }
  }

  void remove(String id) {
    if (_favorites.remove(id) != null) {
      notifyListeners();
    }
  }

  void clear() {
    _favorites.clear();
    notifyListeners();
  }
}
