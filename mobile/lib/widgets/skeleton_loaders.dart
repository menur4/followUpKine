import 'package:flutter/material.dart';

/// Widget skeleton avec animation shimmer style iOS
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  /// Skeleton circulaire pour les avatars
  const Skeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton pour une carte de séance
class SessionCardSkeleton extends StatelessWidget {
  const SessionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Barre de statut
            const Skeleton(width: 4, height: 50, borderRadius: 2),
            const SizedBox(width: 12),
            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Skeleton(width: 180, height: 16),
                  const SizedBox(height: 6),
                  const Skeleton(width: 120, height: 14),
                ],
              ),
            ),
            // Badge statut
            const Skeleton(width: 60, height: 24, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

/// Skeleton pour une carte de praticien
class PractitionerCardSkeleton extends StatelessWidget {
  const PractitionerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Skeleton.circle(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Skeleton(width: 140, height: 18),
                      const SizedBox(height: 4),
                      const Skeleton(width: 80, height: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Badge
            const Skeleton(width: 120, height: 24, borderRadius: 12),
            const SizedBox(height: 12),
            // Progress bar
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Skeleton(width: 60, height: 12),
                Skeleton(width: 80, height: 12),
              ],
            ),
            const SizedBox(height: 4),
            const Skeleton(width: double.infinity, height: 6, borderRadius: 3),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Info rows
            ...List.generate(4, (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Skeleton(width: 60 + (index * 10).toDouble(), height: 12),
                  Skeleton(width: 80 - (index * 5).toDouble(), height: 12),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Skeleton pour les statistiques
class StatsCardSkeleton extends StatelessWidget {
  const StatsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 150, height: 20),
            const SizedBox(height: 16),
            // Stats grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Skeleton(width: 40, height: 32),
                      const SizedBox(height: 4),
                      const Skeleton(width: 60, height: 14),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Skeleton(width: 40, height: 32),
                      const SizedBox(height: 4),
                      const Skeleton(width: 60, height: 14),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Skeleton(width: 40, height: 32),
                      const SizedBox(height: 4),
                      const Skeleton(width: 60, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton pour le graphique
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 160, height: 20),
            const SizedBox(height: 16),
            // Fake bars
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(6, (index) {
                  final heights = [80.0, 120.0, 100.0, 160.0, 140.0, 90.0];
                  return const Skeleton(width: 32, height: 0).copyWithHeight(heights[index]);
                }),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Skeleton(width: 12, height: 12, borderRadius: 2),
                const SizedBox(width: 6),
                const Skeleton(width: 60, height: 12),
                const SizedBox(width: 16),
                const Skeleton(width: 12, height: 12, borderRadius: 2),
                const SizedBox(width: 6),
                const Skeleton(width: 60, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension _SkeletonExtension on Skeleton {
  Widget copyWithHeight(double newHeight) {
    return Skeleton(
      width: width,
      height: newHeight,
      borderRadius: borderRadius,
    );
  }
}

/// Widget de chargement du dashboard complet
class DashboardLoadingSkeleton extends StatelessWidget {
  const DashboardLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Carte praticien
          const SizedBox(
            height: 320,
            child: PractitionerCardSkeleton(),
          ),
          const SizedBox(height: 16),
          // Stats
          const StatsCardSkeleton(),
          const SizedBox(height: 16),
          // Chart
          const ChartSkeleton(),
          const SizedBox(height: 16),
          // Sessions list skeleton
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Skeleton(width: 140, height: 18),
                  const SizedBox(height: 12),
                  ...List.generate(3, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: SessionCardSkeleton(),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
