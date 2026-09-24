import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/movie_card.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;
    final favService = FavoritesService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'My List',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: favService,
            builder: (context, _) {
              if (favService.count == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceElevated,
                      title: const Text('Clear My List', style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'Are you sure you want to remove all saved items from your list?',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () {
                            favService.clear();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: favService,
        builder: (context, _) {
          final items = favService.items;

          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Your Watchlist is Empty',
              description: 'Save your favorite movies and shows to watch them later anytime.',
            );
          }

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
        },
      ),
    );
  }
}
