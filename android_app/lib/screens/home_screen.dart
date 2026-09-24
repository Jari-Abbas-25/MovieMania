import 'package:flutter/material.dart';
import '../core/bridge/moviebox_bridge.dart';
import '../core/models/media_models.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/hero_banner.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/movie_rail.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<CatalogMediaItem> _trending = [];
  List<CatalogMediaItem> _movies = [];
  List<CatalogMediaItem> _tvShows = [];
  List<CatalogMediaItem> _newReleases = [];

  CatalogMediaItem? get _heroItem {
    if (_trending.isNotEmpty) return _trending.first;
    if (_movies.isNotEmpty) return _movies.first;
    if (_tvShows.isNotEmpty) return _tvShows.first;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadAllCatalogRails();
  }

  Future<void> _loadAllCatalogRails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load tabs in parallel:
      // Tab '1': Trending / Featured
      // Tab '2': Movies
      // Tab '3': TV Shows & Series
      // Tab '5': New Releases
      final results = await Future.wait([
        MovieBoxBridge.homepage(tab: '1', page: 1),
        MovieBoxBridge.homepage(tab: '2', page: 1),
        MovieBoxBridge.homepage(tab: '3', page: 1),
        MovieBoxBridge.homepage(tab: '5', page: 1),
      ]);

      List<CatalogMediaItem> parseItems(Map<String, dynamic> res) {
        if (res['success'] == true && res['items'] is List) {
          return (res['items'] as List)
              .map((item) => CatalogMediaItem.fromJson(item as Map<String, dynamic>))
              .where((item) => item.title.isNotEmpty)
              .toList();
        }
        return [];
      }

      final trendingList = parseItems(results[0]);
      final moviesList = parseItems(results[1]);
      final tvList = parseItems(results[2]);
      final newReleasesList = parseItems(results[3]);

      if (mounted) {
        setState(() {
          _trending = trendingList;
          _movies = moviesList;
          _tvShows = tvList;
          _newReleases = newReleasesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not connect to MovieMania catalog. $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            SkeletonHero(),
            SizedBox(height: 16),
            SkeletonRail(),
            SizedBox(height: 16),
            SkeletonRail(),
          ],
        ),
      );
    }

    if (_errorMessage != null && _trending.isEmpty && _movies.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Catalog Unavailable',
          description: _errorMessage!,
          actionLabel: 'Retry Connection',
          onAction: _loadAllCatalogRails,
        ),
      );
    }

    final hero = _heroItem;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: _loadAllCatalogRails,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // Top App Bar (Floating transparent/glass)
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.background.withValues(alpha: 0.85),
              elevation: 0,
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'MOVIEMANIA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 24),
                  tooltip: 'Search',
                  onPressed: () {
                    if (widget.onNavigateToTab != null) {
                      widget.onNavigateToTab!(1); // Switch to Search tab
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Hero Banner
            if (hero != null)
              SliverToBoxAdapter(
                child: HeroBanner(item: hero),
              ),

            // Rails
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // Trending Now Rail (Tab 1)
                  if (_trending.isNotEmpty)
                    MovieRail(
                      title: 'Trending Now',
                      subtitle: 'Popular movies & shows this week',
                      icon: Icons.local_fire_department_rounded,
                      items: _trending,
                    ),

                  const SizedBox(height: 16),

                  // Top Movies Rail (Tab 2)
                  if (_movies.isNotEmpty)
                    MovieRail(
                      title: 'Popular Movies',
                      subtitle: 'Blockbusters & trending films',
                      icon: Icons.movie_outlined,
                      items: _movies,
                    ),

                  const SizedBox(height: 16),

                  // TV Shows Rail (Tab 3)
                  if (_tvShows.isNotEmpty)
                    MovieRail(
                      title: 'TV Shows & Series',
                      subtitle: 'Binge-worthy shows & anime',
                      icon: Icons.tv_rounded,
                      items: _tvShows,
                    ),

                  const SizedBox(height: 16),

                  // New Releases Rail (Tab 5)
                  if (_newReleases.isNotEmpty)
                    MovieRail(
                      title: 'Recently Added',
                      subtitle: 'Fresh arrivals in MovieMania',
                      icon: Icons.fiber_new_rounded,
                      items: _newReleases,
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
