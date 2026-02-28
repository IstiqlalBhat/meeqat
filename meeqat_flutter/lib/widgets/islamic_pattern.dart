import 'dart:math';
import 'package:flutter/material.dart';

/// A subtle Islamic geometric pattern overlay using eight-pointed star
/// tessellation — one of the most recognizable motifs in Islamic art.
///
/// Layer this behind content for a beautiful spiritual texture:
/// ```dart
/// Stack(children: [
///   IslamicPattern(color: AppTheme.gold, opacity: 0.04),
///   yourContent,
/// ])
/// ```
class IslamicPattern extends StatelessWidget {
  final Color color;
  final double opacity;
  final double cellSize;
  final double strokeWidth;
  final PatternStyle style;

  const IslamicPattern({
    super.key,
    required this.color,
    this.opacity = 0.06,
    this.cellSize = 60,
    this.strokeWidth = 0.8,
    this.style = PatternStyle.eightPointStar,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _IslamicPatternPainter(
            color: color.withValues(alpha: opacity),
            cellSize: cellSize,
            strokeWidth: strokeWidth,
            style: style,
          ),
        ),
      ),
    );
  }
}

enum PatternStyle {
  eightPointStar,
  arabesque,
  geometric,
}

class _IslamicPatternPainter extends CustomPainter {
  final Color color;
  final double cellSize;
  final double strokeWidth;
  final PatternStyle style;

  _IslamicPatternPainter({
    required this.color,
    required this.cellSize,
    required this.strokeWidth,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case PatternStyle.eightPointStar:
        _paintEightPointStar(canvas, size);
        break;
      case PatternStyle.arabesque:
        _paintArabesque(canvas, size);
        break;
      case PatternStyle.geometric:
        _paintGeometric(canvas, size);
        break;
    }
  }

  /// Eight-pointed star (Rub el Hizb) tessellation.
  /// Two overlapping squares rotated 45 degrees form the star.
  void _paintEightPointStar(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cols = (size.width / cellSize).ceil() + 1;
    final rows = (size.height / cellSize).ceil() + 1;
    final r = cellSize * 0.38; // star radius

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * cellSize + (row.isOdd ? cellSize / 2 : 0);
        final cy = row * cellSize;

        // Draw two overlapping squares
        _drawRotatedSquare(canvas, paint, cx, cy, r, 0);
        _drawRotatedSquare(canvas, paint, cx, cy, r, pi / 4);
      }
    }
  }

  void _drawRotatedSquare(Canvas canvas, Paint paint, double cx, double cy, double r, double angle) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final a = angle + i * pi / 2;
      final x = cx + r * cos(a);
      final y = cy + r * sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Interlocking arabesque curves — flowing organic lines.
  void _paintArabesque(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final cols = (size.width / cellSize).ceil() + 1;
    final rows = (size.height / cellSize).ceil() + 1;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * cellSize;
        final cy = row * cellSize;

        // Petal curves around center
        for (int i = 0; i < 6; i++) {
          final angle = i * pi / 3;
          final path = Path();
          final r = cellSize * 0.35;

          final startX = cx + r * 0.3 * cos(angle - pi / 6);
          final startY = cy + r * 0.3 * sin(angle - pi / 6);
          final endX = cx + r * 0.3 * cos(angle + pi / 6);
          final endY = cy + r * 0.3 * sin(angle + pi / 6);
          final ctrlX = cx + r * cos(angle);
          final ctrlY = cy + r * sin(angle);

          path.moveTo(startX, startY);
          path.quadraticBezierTo(ctrlX, ctrlY, endX, endY);
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  /// Clean geometric grid — interlocking hexagons and triangles.
  void _paintGeometric(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cols = (size.width / cellSize).ceil() + 2;
    final rows = (size.height / (cellSize * 0.866)).ceil() + 2;
    final r = cellSize * 0.35;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final cx = col * cellSize + (row.isOdd ? cellSize / 2 : 0);
        final cy = row * cellSize * 0.866;

        // Hexagon
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = i * pi / 3 - pi / 6;
          final x = cx + r * cos(angle);
          final y = cy + r * sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter old) =>
      old.color != color || old.cellSize != cellSize || old.strokeWidth != strokeWidth || old.style != style;
}

/// A single decorative eight-pointed star icon, useful as a standalone
/// accent element (e.g. between headings, in empty states).
class IslamicStar extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const IslamicStar({
    super.key,
    this.size = 24,
    required this.color,
    this.strokeWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _StarPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.45;

    // Two overlapping rotated squares
    for (final rotation in [0.0, pi / 4]) {
      final path = Path();
      for (int i = 0; i < 4; i++) {
        final angle = rotation + i * pi / 2;
        final x = cx + r * cos(angle);
        final y = cy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
