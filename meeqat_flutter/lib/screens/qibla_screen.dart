import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _heading;
  double? _qiblaDirection;
  String? _error;
  bool _locationLoaded = false;
  bool _compassAvailable = true;

  // Kaaba coordinates
  static const _kaabaLat = 21.4225;
  static const _kaabaLng = 39.8262;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initCompass();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission required for Qibla');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final qibla = _calculateQibla(pos.latitude, pos.longitude);
      setState(() {
        _qiblaDirection = qibla;
        _locationLoaded = true;
      });
    } catch (e) {
      setState(() => _error = 'Unable to determine location');
    }
  }

  void _initCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) {
      setState(() {
        _compassAvailable = false;
        _heading = 0;
      });
      return;
    }
    stream.listen((event) {
      if (mounted && event.heading != null) {
        setState(() => _heading = event.heading);
      }
    });
    // If no compass event arrives within 3 seconds, fall back to heading 0
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _heading == null) {
        setState(() {
          _compassAvailable = false;
          _heading = 0;
        });
      }
    });
  }

  double _calculateQibla(double lat, double lng) {
    final lat1 = lat * pi / 180;
    final lng1 = lng * pi / 180;
    final lat2 = _kaabaLat * pi / 180;
    final lng2 = _kaabaLng * pi / 180;
    final dLng = lng2 - lng1;
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qibla', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Face the direction of the Kaaba', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            ],
          ),
        ),

        if (_error != null)
          _buildError()
        else if (!_locationLoaded || _heading == null)
          _buildLoading()
        else
          _buildCompass(),
      ],
    );
  }

  Widget _buildLoading() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Compass skeleton
          Shimmer(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface,
              ),
              child: Center(
                child: ShimmerBone.circle(size: 52),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Shimmer(
            child: ShimmerBone(width: 140, height: 36, borderRadius: 20),
          ),
          const SizedBox(height: 16),
          Text('Finding your location...', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.location_off_rounded, size: 56, color: cs.hintText),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _initLocation,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: cs.goldAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass() {
    final cs = Theme.of(context).colorScheme;
    final heading = _heading ?? 0;
    final qibla = _qiblaDirection ?? 0;
    final needle = (qibla - heading) * pi / 180;
    final degDiff = ((qibla - heading) % 360 + 360) % 360;
    final isAligned = degDiff < 5 || degDiff > 355;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Compass
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
                if (isAligned) BoxShadow(color: AppTheme.sage.withValues(alpha: 0.3), blurRadius: 30),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring marks
                CustomPaint(
                  size: const Size(280, 280),
                  painter: _CompassPainter(
                    heading: heading,
                    tickColor: cs.onSurfaceVariant,
                    northColor: cs.goldDarkAccent,
                  ),
                ),

                // Qibla needle
                Transform.rotate(
                  angle: needle,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 3,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [isAligned ? AppTheme.sageDark : AppTheme.gold, isAligned ? AppTheme.sage : AppTheme.goldLight],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 2,
                        height: 60,
                        decoration: BoxDecoration(
                          color: cs.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Kaaba icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAligned ? AppTheme.sage.withValues(alpha: 0.15) : AppTheme.goldLight.withValues(alpha: 0.2),
                    border: Border.all(color: isAligned ? AppTheme.sage.withValues(alpha: 0.4) : AppTheme.gold.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    size: 24,
                    color: isAligned ? cs.sageDarkAccent : cs.goldAccent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Status
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isAligned ? AppTheme.sage.withValues(alpha: 0.15) : AppTheme.goldLight.withValues(alpha: 0.15),
            ),
            child: Text(
              isAligned ? 'Facing Qibla' : '${degDiff.round()}° to Qibla',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isAligned ? cs.sageDarkAccent : cs.goldDarkAccent,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _compassAvailable
                        ? 'Hold your device flat and rotate until the needle points up'
                        : 'Compass not available on this device. Qibla is ${_qiblaDirection?.round()}° from North.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double heading;
  final Color tickColor;
  final Color northColor;
  _CompassPainter({required this.heading, required this.tickColor, required this.northColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    // Tick marks
    for (int i = 0; i < 72; i++) {
      final angle = i * 5 * pi / 180 - heading * pi / 180;
      final isMajor = i % 18 == 0;
      final isMinor = i % 9 == 0;
      final length = isMajor ? 12.0 : (isMinor ? 8.0 : 4.0);
      final width = isMajor ? 2.0 : 1.0;

      final p1 = Offset(
        center.dx + (radius - length) * cos(angle - pi / 2),
        center.dy + (radius - length) * sin(angle - pi / 2),
      );
      final p2 = Offset(
        center.dx + radius * cos(angle - pi / 2),
        center.dy + radius * sin(angle - pi / 2),
      );

      canvas.drawLine(
        p1, p2,
        Paint()
          ..color = isMajor ? tickColor : tickColor.withValues(alpha: 0.3)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    // Cardinal direction labels
    final labels = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      final angle = i * 90 * pi / 180 - heading * pi / 180;
      final pos = Offset(
        center.dx + (radius - 26) * cos(angle - pi / 2),
        center.dy + (radius - 26) * sin(angle - pi / 2),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: labels[i] == 'N' ? northColor : tickColor.withValues(alpha: 0.6),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      old.heading != heading || old.tickColor != tickColor || old.northColor != northColor;
}
