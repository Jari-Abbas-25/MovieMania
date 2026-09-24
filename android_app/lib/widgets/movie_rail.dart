import 'package:flutter/material.dart';
import '../core/models/media_models.dart';
import '../theme/app_theme.dart';
import 'movie_card.dart';

class MovieRail extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<CatalogMediaItem> items;
  final VoidCallback? onSeeAll;

  const MovieRail({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.items,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;
    final cardWidth = isDesktop ? 150.0 : 125.0;
    final cardHeight = cardWidth * 1.48;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40.0 : 16.0,
            vertical: 10.0,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Content Rail
        SizedBox(
          height: cardHeight + 64, // Card height + title, year, hover & padding
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40.0 : 16.0,
              vertical: 6.0,
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return MovieCard(
                item: items[index],
                width: cardWidth,
                height: cardHeight,
              );
            },
          ),
        ),
      ],
    );
  }
}
