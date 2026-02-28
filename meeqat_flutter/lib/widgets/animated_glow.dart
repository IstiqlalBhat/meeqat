import 'package:flutter/material.dart';

/// Wraps any widget with a pulsing glow animation.
/// Great for highlighting the "next prayer" badge, active states,
/// or drawing attention to important elements.
///
/// ```dart
/// AnimatedGlow(
///   color: prayer.accentDark,
///   child: PrayerIconBadge(...),
/// )
/// ```
class AnimatedGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double maxRadius;
  final Duration duration;
  final bool animate;

  const AnimatedGlow({
    super.key,
    required this.child,
    required this.color,
    this.maxRadius = 12,
    this.duration = const Duration(milliseconds: 2000),
    this.animate = true,
  });

  @override
  State<AnimatedGlow> createState() => _AnimatedGlowState();
}

class _AnimatedGlowState extends State<AnimatedGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final glowRadius = widget.maxRadius * _animation.value;
        final glowAlpha = 0.3 * (1.0 - _animation.value * 0.5);

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glowAlpha),
                blurRadius: glowRadius,
                spreadRadius: glowRadius * 0.3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A breathe-style scale animation wrapper.
/// Gently scales the child up and down in a loop.
class BreatheAnimation extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;
  final bool animate;

  const BreatheAnimation({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 1.06,
    this.duration = const Duration(milliseconds: 2200),
    this.animate = true,
  });

  @override
  State<BreatheAnimation> createState() => _BreatheAnimationState();
}

class _BreatheAnimationState extends State<BreatheAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnim = Tween<double>(begin: widget.minScale, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BreatheAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;

    return ScaleTransition(
      scale: _scaleAnim,
      child: widget.child,
    );
  }
}
