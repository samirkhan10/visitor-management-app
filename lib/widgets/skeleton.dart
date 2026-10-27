import 'package:flutter/material.dart';

/// Lightweight shimmer used for skeleton loading states.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF22253A) : const Color(0xFFE9EBF2);
    final highlightColor = isDark ? const Color(0xFF30344D) : const Color(0xFFF7F8FC);

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final slide = _controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [baseColor, highlightColor, baseColor],
            stops: const [0.25, 0.5, 0.75],
            begin: Alignment(-1 + slide * 2, -0.3),
            end: Alignment(1 + slide * 2, 0.3),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

class VisitorListSkeleton extends StatelessWidget {
  const VisitorListSkeleton({super.key, this.itemCount = 6, this.padding});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: padding ?? const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const _VisitorTileSkeleton(),
      ),
    );
  }
}

class _VisitorTileSkeleton extends StatelessWidget {
  const _VisitorTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 46, height: 46, radius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 14),
                SizedBox(height: 10),
                SkeletonBox(width: 100, height: 10),
                SizedBox(height: 8),
                SkeletonBox(width: 170, height: 10),
              ],
            ),
          ),
          SkeletonBox(width: 64, height: 22, radius: 20),
        ],
      ),
    );
  }
}

class StatCardsSkeleton extends StatelessWidget {
  const StatCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Row(
        children: [
          Expanded(child: SkeletonBox(height: 132, radius: 20)),
          SizedBox(width: 12),
          Expanded(child: SkeletonBox(height: 132, radius: 20)),
          SizedBox(width: 12),
          Expanded(child: SkeletonBox(height: 132, radius: 20)),
        ],
      ),
    );
  }
}
