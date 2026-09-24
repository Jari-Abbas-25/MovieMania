import 'dart:async';
import 'package:flutter/material.dart';
import '../core/bridge/moviebox_bridge.dart';
import '../core/models/media_models.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/movie_card.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Timer? _debounceTimer;
  bool _isSearching = false;
  String? _errorMessage;
  bool _hasSearched = false;

  List<CatalogMediaItem> _results = [];
  List<CatalogMediaItem> _recommended = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    } else {
      _loadRecommendations();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    try {
      final res = await MovieBoxBridge.homepage(tab: '1', page: 1);
      if (res['success'] == true && res['items'] is List) {
        final items = (res['items'] as List)
            .map((item) => CatalogMediaItem.fromJson(item as Map<String, dynamic>))
            .where((item) => item.title.isNotEmpty)
            .toList();
        if (mounted) {
          setState(() {
            _recommended = items;
          });
        }
      }
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _hasSearched = false;
        _results = [];
        _isSearching = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final res = await MovieBoxBridge.search(
        provider: 'moviebox',
        query: trimmed,
        page: 1,
      );

      if (res['success'] == true && res['results'] is List) {
        final items = (res['results'] as List)
            .map((item) => CatalogMediaItem.fromJson(item as Map<String, dynamic>))
            .where((item) => item.title.isNotEmpty)
            .toList();

        if (mounted) {
          setState(() {
            _results = items;
            _isSearching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res['error']?.toString() ?? 'Search request failed.';
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Search error: $e';
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header Box
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40.0 : 16.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search TextField
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _searchFocus.hasFocus ? AppColors.primary : AppColors.cardBorder,
                        width: _searchFocus.hasFocus ? 1.5 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: 'Search movies, TV shows, actors...',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: _performSearch,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.cardBorder, height: 1),

            // Search Content / Results Grid
            Expanded(
              child: _isSearching
                  ? const SingleChildScrollView(child: SkeletonGrid(itemCount: 12))
                  : _errorMessage != null
                      ? EmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Search Failed',
                          description: _errorMessage!,
                          actionLabel: 'Try Again',
                          onAction: () => _performSearch(_searchController.text),
                        )
                      : _hasSearched
                          ? _results.isEmpty
                              ? EmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: 'No Results Found',
                                  description: 'We couldn\'t find any titles matching "${_searchController.text.trim()}". Try searching for a different keyword or title.',
                                )
                              : _buildResultsGrid(_results, isDesktop, width)
                          : _recommended.isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 40.0 : 16.0,
                                        vertical: 12.0,
                                      ),
                                      child: const Text(
                                        'Top Searches & Popular',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildResultsGrid(_recommended, isDesktop, width),
                                    ),
                                  ],
                                )
                              : const EmptyState(
                                  icon: Icons.search_rounded,
                                  title: 'Find Your Next Watch',
                                  description: 'Search by movie title, TV show, or keywords.',
                                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsGrid(List<CatalogMediaItem> items, bool isDesktop, double width) {
    int crossAxisCount = 2;
    if (width > 1200) {
      crossAxisCount = 6;
    } else if (width > 800) {
      crossAxisCount = 4;
    } else if (width > 500) {
      crossAxisCount = 3;
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40.0 : 16.0,
        vertical: 16.0,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return MovieCard(
          item: items[index],
          width: double.infinity,
        );
      },
    );
  }
}
