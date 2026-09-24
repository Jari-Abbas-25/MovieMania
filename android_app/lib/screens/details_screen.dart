import 'package:flutter/material.dart';
import '../core/bridge/moviebox_bridge.dart';
import '../core/models/media_models.dart';
import '../core/player/player_launcher.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_skeleton.dart';
import 'playback_selection_modal.dart';

class DetailsScreen extends StatefulWidget {
  final String id;
  final String provider;
  final String initialTitle;
  final String? initialPoster;
  final bool initialIsSeries;

  const DetailsScreen({
    super.key,
    required this.id,
    required this.provider,
    required this.initialTitle,
    this.initialPoster,
    this.initialIsSeries = false,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  MediaDetailInfo? _details;

  int _selectedSeason = 1;
  int _selectedEpisode = 1;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await MovieBoxBridge.details(
        provider: widget.provider,
        id: widget.id,
      );

      if (res['success'] == true && res['details'] != null) {
        final detailsMap = res['details'] as Map<String, dynamic>;
        final details = MediaDetailInfo.fromJson(detailsMap, widget.provider);
        if (mounted) {
          setState(() {
            _details = details;
            _isLoading = false;
            if (details.seasons.isNotEmpty) {
              _selectedSeason = details.seasons.first.seasonNumber;
              if (details.seasons.first.episodes.isNotEmpty) {
                _selectedEpisode = details.seasons.first.episodes.first.episodeNumber;
              }
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res['error']?.toString() ?? 'Failed to load details.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading details: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startPlaybackSelection({required int season, required int episode}) {
    final title = _details?.title ?? widget.initialTitle;
    PlaybackSelectionModal.show(
      context: context,
      provider: widget.provider,
      mediaId: widget.id,
      title: title,
      season: season,
      episode: episode,
      dubs: _details?.dubs ?? [],
      defaultPlayer: TargetPlayer.mpv,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    final title = _details?.title ?? widget.initialTitle;
    final posterUrl = _details?.poster ?? widget.initialPoster;
    final isSeries = _details?.isSeries ?? widget.initialIsSeries;
    final favService = FavoritesService();

    final currentCatalogItem = CatalogMediaItem(
      id: widget.id,
      title: title,
      poster: posterUrl,
      year: _details?.year,
      provider: widget.provider,
      isSeries: isSeries,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const SingleChildScrollView(
              physics: NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonHero(),
                  SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 200, height: 24, borderRadius: 4),
                        SizedBox(height: 12),
                        ShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
                        SizedBox(height: 20),
                        ShimmerBox(width: double.infinity, height: 80, borderRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to Load Title',
                  description: _errorMessage!,
                  actionLabel: 'Retry',
                  onAction: _loadDetails,
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Backdrop Sliver App Bar
                    SliverAppBar(
                      expandedHeight: isDesktop ? 440.0 : 340.0,
                      pinned: true,
                      backgroundColor: AppColors.background,
                      elevation: 0,
                      leading: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (posterUrl != null && posterUrl.isNotEmpty)
                              Image.network(
                                posterUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceElevated),
                              )
                            else
                              Container(color: AppColors.surfaceElevated),

                            // Backdrop Gradient
                            Container(
                              decoration: const BoxDecoration(
                                gradient: AppColors.heroVignette,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Details Body Content
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 60.0 : 20.0,
                          vertical: 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Metadata Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isSeries ? 'TV SERIES' : 'MOVIE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                if (_details?.year != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_details!.year}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'HD',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Title
                            Text(
                              title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isDesktop ? 32 : 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                height: 1.15,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Main Action Buttons
                            Row(
                              children: [
                                // Watch Button (Full width on mobile or expanded)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_arrow, size: 22, color: Colors.black),
                                    label: Text(
                                      isSeries ? 'Watch S${_selectedSeason}E$_selectedEpisode' : 'Watch Movie',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                    onPressed: () {
                                      _startPlaybackSelection(
                                        season: isSeries ? _selectedSeason : 0,
                                        episode: isSeries ? _selectedEpisode : 0,
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // My List Button
                                AnimatedBuilder(
                                  animation: favService,
                                  builder: (context, _) {
                                    final isFav = favService.isFavorite(widget.id);
                                    return OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: AppColors.surfaceElevated,
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: isFav ? AppColors.primary : AppColors.cardBorder,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: Icon(
                                        isFav ? Icons.check : Icons.add,
                                        size: 18,
                                        color: isFav ? AppColors.primaryGlow : Colors.white,
                                      ),
                                      label: Text(
                                        isFav ? 'Added' : 'My List',
                                        style: TextStyle(
                                          color: isFav ? AppColors.primaryGlow : Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      onPressed: () => favService.toggleFavorite(currentCatalogItem),
                                    );
                                  },
                                ),
                              ],
                            ),

                            // Genres chips
                            if (_details?.genres.isNotEmpty == true) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _details!.genres.map((g) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.cardBorder),
                                    ),
                                    child: Text(
                                      g,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Synopsis
                            const Text(
                              'Synopsis',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _details?.description ?? 'No description available.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),

                            // TV Series Season & Episodes Picker
                            if (isSeries && _details != null && _details!.seasons.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              const Text(
                                'Episodes',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Season Selector Rail
                              SizedBox(
                                height: 38,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _details!.seasons.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final season = _details!.seasons[index];
                                    final isSelected = season.seasonNumber == _selectedSeason;

                                    return ChoiceChip(
                                      label: Text(season.title ?? 'Season ${season.seasonNumber}'),
                                      selected: isSelected,
                                      selectedColor: AppColors.primary,
                                      backgroundColor: AppColors.surfaceElevated,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textSecondary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                      side: BorderSide(
                                        color: isSelected ? AppColors.primary : AppColors.cardBorder,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedSeason = season.seasonNumber;
                                            if (season.episodes.isNotEmpty) {
                                              _selectedEpisode = season.episodes.first.episodeNumber;
                                            }
                                          });
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Episode List Cards
                              Builder(builder: (context) {
                                final currentSeason = _details!.seasons.firstWhere(
                                  (s) => s.seasonNumber == _selectedSeason,
                                  orElse: () => _details!.seasons.first,
                                );

                                if (currentSeason.episodes.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Text(
                                      'No episodes listed for this season.',
                                      style: TextStyle(color: AppColors.textMuted),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: currentSeason.episodes.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final ep = currentSeason.episodes[index];
                                    final isSelected = ep.episodeNumber == _selectedEpisode;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withValues(alpha: 0.12)
                                            : AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : AppColors.cardBorder,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        leading: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${ep.episodeNumber}',
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : AppColors.textSecondary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          ep.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : AppColors.textPrimary,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: isSelected ? AppColors.primaryGlow : AppColors.textMuted,
                                          size: 26,
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedEpisode = ep.episodeNumber;
                                          });
                                          _startPlaybackSelection(
                                            season: _selectedSeason,
                                            episode: ep.episodeNumber,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                );
                              }),
                            ],

                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
