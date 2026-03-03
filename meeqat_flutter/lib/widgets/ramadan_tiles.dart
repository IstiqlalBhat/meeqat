import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer_time.dart';
import '../services/prayer_provider.dart';
import '../services/ramadan_service.dart';
import '../theme/app_theme.dart';

enum RamadanTileSize { small, medium, large }

class RamadanTiles extends StatefulWidget {
  final RamadanTileSize tileSize;
  const RamadanTiles({super.key, this.tileSize = RamadanTileSize.small});

  @override
  State<RamadanTiles> createState() => _RamadanTilesState();
}

class _RamadanTilesState extends State<RamadanTiles> {
  Timer? _timer;
  Duration? _timeToIftar;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final provider = context.read<PrayerProvider>();
    final maghrib = provider.prayerTimes
        .where((p) => p.prayer == Prayer.maghrib)
        .firstOrNull;
    final newDuration = RamadanService.timeToIftar(maghrib?.athanDate);
    if (_timeToIftar != newDuration) {
      setState(() => _timeToIftar = newDuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<PrayerProvider>();
    final day = RamadanService.ramadanDay();

    final maghrib = provider.prayerTimes
        .where((p) => p.prayer == Prayer.maghrib)
        .firstOrNull;
    // Show next sehri end: today's Fajr if it hasn't passed, otherwise tomorrow's
    final todayFajr = provider.prayerTimes
        .where((p) => p.prayer == Prayer.fajr)
        .firstOrNull;
    final now = DateTime.now();
    final todayFajrPassed = todayFajr?.athanDate != null && todayFajr!.athanDate!.isBefore(now);
    final fajr = todayFajrPassed ? (provider.tomorrowFajr ?? todayFajr) : todayFajr;

    // Update iftar countdown
    _timeToIftar = RamadanService.timeToIftar(maghrib?.athanDate);

    final sizes = _sizes;

    return Column(
      children: [
        // Header row
        Row(
          children: [
            Icon(Icons.nightlight_round, size: sizes.iconSize, color: cs.goldAccent),
            const SizedBox(width: 6),
            Text(
              'RAMADAN',
              style: TextStyle(
                fontSize: sizes.labelSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: cs.goldDarkAccent,
              ),
            ),
            if (day != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sizes.chipPaddingH,
                  vertical: sizes.chipPaddingV,
                ),
                decoration: BoxDecoration(
                  color: cs.goldAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Day $day',
                  style: TextStyle(
                    fontSize: sizes.chipFontSize,
                    fontWeight: FontWeight.w700,
                    color: cs.goldDarkAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: sizes.headerGap),
        // Tiles row
        Row(
          children: [
            Expanded(
              child: _iftarTile(cs, maghrib, sizes),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _sehriTile(cs, fajr, sizes, isTomorrow: todayFajrPassed),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iftarTile(ColorScheme cs, PrayerTime? maghrib, _TileSizes sizes) {
    final goldAccent = cs.goldAccent;

    final String timeText;
    final String subtitle;
    if (_timeToIftar != null) {
      timeText = _fmtCountdown(_timeToIftar!);
      subtitle = 'Iftar at ${PrayerTime.formatTime(maghrib?.athanTime)}';
    } else {
      timeText = PrayerTime.formatTime(maghrib?.athanTime);
      subtitle = 'Iftar has passed';
    }

    return Container(
      padding: EdgeInsets.all(sizes.tilePadding),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldAccent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: goldAccent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_rounded, size: sizes.tileIconSize, color: goldAccent),
              const SizedBox(width: 5),
              Text(
                'IFTAR',
                style: TextStyle(
                  fontSize: sizes.tileLabelSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: cs.hintText,
                ),
              ),
            ],
          ),
          SizedBox(height: sizes.tileInnerGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              timeText,
              maxLines: 1,
              style: TextStyle(
                fontSize: sizes.timeSize,
                fontWeight: FontWeight.w800,
                color: goldAccent,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: sizes.subtitleSize,
              color: cs.hintText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sehriTile(ColorScheme cs, PrayerTime? fajr, _TileSizes sizes, {bool isTomorrow = false}) {
    final sageAccent = cs.sageDarkAccent;
    final fajrTime = PrayerTime.formatTime(fajr?.athanTime);

    return Container(
      padding: EdgeInsets.all(sizes.tilePadding),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sageAccent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: sageAccent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode_rounded, size: sizes.tileIconSize, color: sageAccent),
              const SizedBox(width: 5),
              Text(
                'SEHRI ENDS',
                style: TextStyle(
                  fontSize: sizes.tileLabelSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: cs.hintText,
                ),
              ),
            ],
          ),
          SizedBox(height: sizes.tileInnerGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fajrTime,
              maxLines: 1,
              style: TextStyle(
                fontSize: sizes.timeSize,
                fontWeight: FontWeight.w800,
                color: sageAccent,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isTomorrow ? 'Tomorrow · Fajr Athan' : 'Fajr Athan',
            style: TextStyle(
              fontSize: sizes.subtitleSize,
              color: cs.hintText,
            ),
          ),
        ],
      ),
    );
  }

  _TileSizes get _sizes {
    switch (widget.tileSize) {
      case RamadanTileSize.small:
        return const _TileSizes(
          iconSize: 14,
          labelSize: 10,
          chipPaddingH: 7,
          chipPaddingV: 2,
          chipFontSize: 9,
          headerGap: 8,
          tilePadding: 12,
          tileIconSize: 13,
          tileLabelSize: 8,
          tileInnerGap: 6,
          timeSize: 20,
          subtitleSize: 9,
        );
      case RamadanTileSize.medium:
        return const _TileSizes(
          iconSize: 16,
          labelSize: 11,
          chipPaddingH: 8,
          chipPaddingV: 3,
          chipFontSize: 10,
          headerGap: 10,
          tilePadding: 14,
          tileIconSize: 15,
          tileLabelSize: 9,
          tileInnerGap: 8,
          timeSize: 24,
          subtitleSize: 10,
        );
      case RamadanTileSize.large:
        return const _TileSizes(
          iconSize: 18,
          labelSize: 12,
          chipPaddingH: 10,
          chipPaddingV: 4,
          chipFontSize: 11,
          headerGap: 12,
          tilePadding: 16,
          tileIconSize: 17,
          tileLabelSize: 10,
          tileInnerGap: 10,
          timeSize: 28,
          subtitleSize: 11,
        );
    }
  }

  String _fmtCountdown(Duration d) {
    final t = d.inSeconds.clamp(0, 99999);
    final h = t ~/ 3600;
    final m = (t % 3600) ~/ 60;
    final s = t % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _TileSizes {
  final double iconSize;
  final double labelSize;
  final double chipPaddingH;
  final double chipPaddingV;
  final double chipFontSize;
  final double headerGap;
  final double tilePadding;
  final double tileIconSize;
  final double tileLabelSize;
  final double tileInnerGap;
  final double timeSize;
  final double subtitleSize;

  const _TileSizes({
    required this.iconSize,
    required this.labelSize,
    required this.chipPaddingH,
    required this.chipPaddingV,
    required this.chipFontSize,
    required this.headerGap,
    required this.tilePadding,
    required this.tileIconSize,
    required this.tileLabelSize,
    required this.tileInnerGap,
    required this.timeSize,
    required this.subtitleSize,
  });
}
