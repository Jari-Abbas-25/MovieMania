import 'package:flutter/material.dart';
import '../core/models/media_models.dart';
import '../screens/details_screen.dart';
import '../theme/app_theme.dart';

class MovieCard extends StatefulWidget {
  final CatalogMediaItem item;
  final double width;
  final double? height;
  final bool showTitle;
  final VoidCallback? onTap;

  const MovieCard({
    super.key,
    required this.item,
    this.width = 130,
    this.height,
    this.showTitle = true,
    this.onTap,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isHovered = false;

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DetailsScreen(
          id: widget.item.id,
          provider: widget.item.provider,
          initialTitle: widget.item.title,
          initialPoster: widget.item.poster,
          initialIsSeries: widget.item.isSeries,
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
    final hasExplicitHeight = widget.height != null;

    final posterImageContent = widget.item.poster != null && widget.item.poster!.isNotEmpty
        ? Image.network(
            widget.item.poster!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: AppColors.surfaceElevated,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                          : null,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              );
            },
          )
        : _buildPlaceholder();

    final posterCard = Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isHovered ? AppColors.primaryGlow : AppColors.cardBorder,
          width: _isHovered ? 1.5 : 1.0,
        ),
        boxShadow: _isHovered
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          posterImageContent,

          // Series / Movie Pill Badge
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: widget.item.isSeries
                    ? AppColors.accentPurple.withValues(alpha: 0.85)
                    : Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Text(
                widget.item.isSeries ? 'SERIES' : 'MOVIE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Rating Badge (if available)
          if (widget.item.rating != null && widget.item.rating!.isNotEmpty)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: AppColors.accentGold, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      widget.item.rating!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final sizedPoster = hasExplicitHeight
        ? SizedBox(
            width: widget.width.isFinite ? widget.width : double.infinity,
            height: widget.height,
            child: posterCard,
          )
        : (widget.width.isFinite
            ? SizedBox(
                width: widget.width,
                height: widget.width * 1.48,
                child: posterCard,
              )
            : AspectRatio(
                aspectRatio: 1 / 1.48,
                child: posterCard,
              ));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: _isHovered ? Matrix4.diagonal3Values(1.03, 1.03, 1.0) : Matrix4.identity(),
        width: widget.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Poster Container
            GestureDetector(
              onTap: _handleTap,
              child: sizedPoster,
            ),

            // Title & Meta
            if (widget.showTitle) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _handleTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isHovered ? AppColors.textPrimary : AppColors.textPrimary.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.item.year != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${widget.item.year}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.item.isSeries ? Icons.tv : Icons.movie_creation_outlined,
              color: Colors.white24,
              size: 32,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                widget.item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
