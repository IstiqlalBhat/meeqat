import 'package:flutter/material.dart';

/// A beautiful shimmer loading effect that sweeps a highlight across
/// placeholder shapes. Use instead of CircularProgressIndicator for
/// skeleton loading states.
///
/// Wrap individual shapes with [ShimmerBone] to define their geometry,
/// or use the pre-built [ShimmerPrayerCard] for prayer row skeletons.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF3A3530) : const Color(0xFFEDE6DC));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF4A443E) : const Color(0xFFF7F2EA));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = _controller.value * 2.0 - 0.5;
            return LinearGradient(
              begin: Alignment(-1.0 + dx * 2, -0.3),
              end: Alignment(0.0 + dx * 2, 0.3),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

/// A single shimmer placeholder bone — a rounded rectangle
/// that pulses with the shimmer animation from its parent [Shimmer].
class ShimmerBone extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const ShimmerBone({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  /// Circle bone
  const ShimmerBone.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF3A3530) : const Color(0xFFEDE6DC);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        shape: shape,
      ),
    );
  }
}

/// Pre-built shimmer skeleton that mimics a prayer times card
/// with 5 prayer rows, matching the real card layout.
class ShimmerPrayerCard extends StatelessWidget {
  const ShimmerPrayerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Column header skeleton
            Padding(
              padding: const EdgeInsets.fromLTRB(58, 10, 16, 8),
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  ShimmerBone(width: 40, height: 8, borderRadius: 4),
                  const SizedBox(width: 20),
                  ShimmerBone(width: 46, height: 8, borderRadius: 4),
                ],
              ),
            ),
            // 5 prayer row skeletons
            ...List.generate(5, (i) => _shimmerRow(i == 4)),
            // Sun strip skeleton
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const ShimmerBone.circle(size: 14),
                  const SizedBox(width: 6),
                  ShimmerBone(width: 80, height: 10, borderRadius: 5),
                  const Spacer(),
                  const ShimmerBone.circle(size: 14),
                  const SizedBox(width: 6),
                  ShimmerBone(width: 80, height: 10, borderRadius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerRow(bool isLast) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 16, 14),
          child: Row(
            children: [
              // Icon badge
              ShimmerBone(width: 34, height: 34, borderRadius: 11),
              const SizedBox(width: 10),
              // Name + arabic
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBone(width: 60, height: 12, borderRadius: 6),
                    const SizedBox(height: 4),
                    ShimmerBone(width: 36, height: 10, borderRadius: 5),
                  ],
                ),
              ),
              // Athan time
              ShimmerBone(width: 52, height: 14, borderRadius: 6),
              const SizedBox(width: 14),
              // Iqamah time
              ShimmerBone(width: 52, height: 14, borderRadius: 6),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Divider(height: 1, thickness: 0.4, color: Colors.grey.withValues(alpha: 0.15)),
          ),
      ],
    );
  }
}

/// Shimmer skeleton for a countdown bar.
class ShimmerCountdownBar extends StatelessWidget {
  const ShimmerCountdownBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: cs.surface,
        ),
        child: Column(
          children: [
            Row(
              children: [
                ShimmerBone(width: 36, height: 36, borderRadius: 12),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBone(width: 30, height: 8, borderRadius: 4),
                      const SizedBox(height: 4),
                      ShimmerBone(width: 70, height: 14, borderRadius: 6),
                    ],
                  ),
                ),
                ShimmerBone(width: 80, height: 24, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 10),
            ShimmerBone(height: 2.5, borderRadius: 2),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for a masjid selection card.
class ShimmerMasjidCard extends StatelessWidget {
  const ShimmerMasjidCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              ShimmerBone(width: 48, height: 48, borderRadius: 16),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBone(width: 140, height: 14, borderRadius: 6),
                    const SizedBox(height: 6),
                    ShimmerBone(width: 100, height: 10, borderRadius: 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
