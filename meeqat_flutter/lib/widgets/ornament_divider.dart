import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'islamic_pattern.dart';

/// A decorative horizontal divider with an Islamic ornament at the center.
/// Matches the Meeqat brand — thin gold lines flanking a diamond or star.
///
/// ```dart
/// OrnamentDivider()                           // default diamond
/// OrnamentDivider(style: OrnamentStyle.star)   // eight-pointed star
/// OrnamentDivider(style: OrnamentStyle.dots)   // three dots
/// ```
class OrnamentDivider extends StatelessWidget {
  final OrnamentStyle style;
  final Color? color;
  final double thickness;
  final double height;

  const OrnamentDivider({
    super.key,
    this.style = OrnamentStyle.diamond,
    this.color,
    this.thickness = 0.5,
    this.height = 20,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.goldLight.withValues(alpha: 0.6);
    final accentColor = color ?? AppTheme.gold.withValues(alpha: 0.5);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(child: Container(height: thickness, color: c)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildOrnament(accentColor),
          ),
          Expanded(child: Container(height: thickness, color: c)),
        ],
      ),
    );
  }

  Widget _buildOrnament(Color c) {
    switch (style) {
      case OrnamentStyle.diamond:
        return Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: 4.5,
            height: 4.5,
            decoration: BoxDecoration(
              border: Border.all(color: c, width: 0.7),
            ),
          ),
        );
      case OrnamentStyle.doubleDiamond:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: pi / 4,
              child: Container(width: 3.5, height: 3.5, decoration: BoxDecoration(border: Border.all(color: c, width: 0.5))),
            ),
            const SizedBox(width: 6),
            Transform.rotate(
              angle: pi / 4,
              child: Container(width: 5, height: 5, decoration: BoxDecoration(border: Border.all(color: c, width: 0.7))),
            ),
            const SizedBox(width: 6),
            Transform.rotate(
              angle: pi / 4,
              child: Container(width: 3.5, height: 3.5, decoration: BoxDecoration(border: Border.all(color: c, width: 0.5))),
            ),
          ],
        );
      case OrnamentStyle.star:
        return IslamicStar(size: 14, color: c, strokeWidth: 0.7);
      case OrnamentStyle.dots:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.4))),
            const SizedBox(width: 5),
            Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
            const SizedBox(width: 5),
            Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.4))),
          ],
        );
      case OrnamentStyle.crescentStar:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 6, color: c),
            const SizedBox(width: 3),
            Icon(Icons.nightlight_round, size: 10, color: c),
            const SizedBox(width: 3),
            Icon(Icons.star_rounded, size: 6, color: c),
          ],
        );
    }
  }
}

enum OrnamentStyle {
  diamond,
  doubleDiamond,
  star,
  dots,
  crescentStar,
}
