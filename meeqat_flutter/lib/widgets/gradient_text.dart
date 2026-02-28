import 'package:flutter/material.dart';

/// Text rendered with a gradient fill. Perfect for decorative headings,
/// hero titles, or accent labels.
///
/// ```dart
/// GradientText(
///   'Bismillah',
///   gradient: AppTheme.goldGradient,
///   style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
/// )
/// ```
class GradientText extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final TextStyle? style;
  final TextAlign? textAlign;

  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
