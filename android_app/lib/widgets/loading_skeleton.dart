import 'package:flutter/material.dart';

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF161822),
                Color(0xFF232738),
                Color(0xFF161822),
              ],
              stops: [
                0.0,
                _controller.value,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonHero extends StatelessWidget {
  const SkeletonHero({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;
    final bannerHeight = isDesktop ? 480.0 : 380.0;

    return ShimmerBox(
      width: double.infinity,
      height: bannerHeight,
      borderRadius: 0,
    );
  }
}

class SkeletonRail extends StatelessWidget {
  const SkeletonRail({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;
    final cardWidth = isDesktop ? 150.0 : 125.0;
    final cardHeight = cardWidth * 1.48;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40.0 : 16.0,
            vertical: 12.0,
          ),
          child: const ShimmerBox(width: 140, height: 20, borderRadius: 4),
        ),
        SizedBox(
          height: cardHeight + 64,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40.0 : 16.0,
              vertical: 6.0,
            ),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: cardWidth,
                  height: cardHeight,
                  borderRadius: 10,
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: cardWidth * 0.8,
                  height: 12,
                  borderRadius: 3,
                ),
                const SizedBox(height: 4),
                ShimmerBox(
                  width: cardWidth * 0.4,
                  height: 10,
                  borderRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int itemCount;

  const SkeletonGrid({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
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
        horizontal: width > 768 ? 40.0 : 16.0,
        vertical: 16.0,
      ),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 10,
            ),
          ),
          SizedBox(height: 8),
          ShimmerBox(width: 90, height: 12, borderRadius: 3),
          SizedBox(height: 4),
          ShimmerBox(width: 45, height: 10, borderRadius: 3),
        ],
      ),
    );
  }
}
