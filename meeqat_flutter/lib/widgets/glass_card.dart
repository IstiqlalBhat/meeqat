import 'dart:ui';
import 'package:flutter/material.dart';

/// A frosted glassmorphism card with backdrop blur, subtle border,
/// and soft shadow. Matches the existing Meeqat bottom nav bar style.
///
/// Use this for elevated content that should feel like floating glass
/// — modal overlays, featured cards, or hero sections.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? borderColor;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.blur = 20,
    this.opacity = 0.75,
    this.borderColor,
    this.backgroundColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = backgroundColor ?? cs.surface.withValues(alpha: opacity);
    final border = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.6));

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border, width: 0.5),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A frosted glass container with a tinted accent color overlay.
/// Useful for hero/featured sections that need a colored glass feel.
class TintedGlassCard extends StatelessWidget {
  final Widget child;
  final Color tintColor;
  final double tintOpacity;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;

  const TintedGlassCard({
    super.key,
    required this.child,
    required this.tintColor,
    this.tintOpacity = 0.08,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.blur = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tintColor.withValues(alpha: tintOpacity),
                tintColor.withValues(alpha: tintOpacity * 0.3),
              ],
            ),
            border: Border.all(
              color: tintColor.withValues(alpha: isDark ? 0.15 : 0.2),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: tintColor.withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
