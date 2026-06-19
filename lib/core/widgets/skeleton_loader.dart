import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shimmer-Skeleton für Ladezustände.
/// Ersetzt CircularProgressIndicator beim Laden von Cards.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 0.5).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.5).clamp(0.0, 1.0),
              ],
              colors: const [
                Color(0xFFEEF2F9),
                Color(0xFFDDE6F5),
                Color(0xFFEEF2F9),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fertige Skeleton-Card für Supplement-Empfehlungen.
class SkeletonSupplementCard extends StatelessWidget {
  const SkeletonSupplementCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge-Skeleton
              const SkeletonLoader(width: 72, height: 24, borderRadius: 12),
              const Spacer(),
              // Button-Skeleton
              const SkeletonLoader(width: 80, height: 32, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 12),
          // Titel
          const SkeletonLoader(width: 180, height: 18, borderRadius: 6),
          const SizedBox(height: 6),
          // Subtitle
          const SkeletonLoader(width: 120, height: 14, borderRadius: 6),
          const SizedBox(height: 12),
          // Beschreibung (3 Zeilen)
          const SkeletonLoader(height: 13, borderRadius: 6),
          const SizedBox(height: 6),
          const SkeletonLoader(height: 13, borderRadius: 6),
          const SizedBox(height: 6),
          const SkeletonLoader(width: 200, height: 13, borderRadius: 6),
          const SizedBox(height: 12),
          // Tags
          Row(
            children: const [
              SkeletonLoader(width: 60, height: 22, borderRadius: 11),
              SizedBox(width: 6),
              SkeletonLoader(width: 80, height: 22, borderRadius: 11),
            ],
          ),
        ],
      ),
    );
  }
}

/// Liste aus 3 Skeleton-Cards — direkt als Ladescreen verwendbar.
class SkeletonCardList extends StatelessWidget {
  final int count;
  const SkeletonCardList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonSupplementCard(),
    );
  }
}
