import 'package:flutter/material.dart';
import '../core/models/media_models.dart';
import '../screens/details_screen.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';

class HeroBanner extends StatelessWidget {
  final CatalogMediaItem item;
  final VoidCallback? onPlay;

  const HeroBanner({
    super.key,
    required this.item,
    this.onPlay,
  });

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DetailsScreen(
          id: item.id,
          provider: item.provider,
          initialTitle: item.title,
          initialPoster: item.poster,
          initialIsSeries: item.isSeries,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;
    final bannerHeight = isDesktop ? 480.0 : 380.0;
    final favService = FavoritesService();

    return SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Backdrop/Poster Image
          if (item.poster != null && item.poster!.isNotEmpty)
            Image.network(
              item.poster!,
              fit: BoxFit.cover,
              alignment: isDesktop ? Alignment.topCenter : Alignment.center,
              errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceElevated),
            )
          else
            Container(color: AppColors.surfaceElevated),

          // Horizontal Vignette for Desktop
          if (isDesktop)
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.horizontalVignette,
              ),
            ),

          // Top and Bottom Dark Gradient Overlays
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.heroVignette,
            ),
          ),

          // Content Layer
          Positioned(
            left: isDesktop ? 40 : 20,
            right: isDesktop ? size.width * 0.35 : 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tag & Meta Line
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FEATURED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.isSeries ? 'TV SERIES' : 'MOVIE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (item.year != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${item.year}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (item.rating != null && item.rating!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.accentGold, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            item.rating!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Hero Title
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 34 : 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.15,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        offset: const Offset(0, 2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    // Play Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 28 : 20,
                          vertical: isDesktop ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 22, color: Colors.black),
                      label: const Text(
                        'Play',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
                        if (onPlay != null) {
                          onPlay!();
                        } else {
                          _openDetails(context);
                        }
                      },
                    ),
                    const SizedBox(width: 12),

                    // My List Button
                    AnimatedBuilder(
                      animation: favService,
                      builder: (context, _) {
                        final isFav = favService.isFavorite(item.id);
                        return OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.4),
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: isFav ? AppColors.primary : Colors.white.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 20 : 14,
                              vertical: isDesktop ? 16 : 12,
                            ),
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
                            isFav ? 'In My List' : 'My List',
                            style: TextStyle(
                              color: isFav ? AppColors.primaryGlow : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () => favService.toggleFavorite(item),
                        );
                      },
                    ),
                    const SizedBox(width: 12),

                    // Info Button
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                      onPressed: () => _openDetails(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
