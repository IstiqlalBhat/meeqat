import 'package:flutter/material.dart';
import '../models/prayer_time.dart';
import '../theme/app_theme.dart';

class PrayerRowCard extends StatefulWidget {
  final PrayerTime prayerTime;
  final bool isActive;
  final bool isNext;

  const PrayerRowCard({
    super.key,
    required this.prayerTime,
    this.isActive = false,
    this.isNext = false,
  });

  @override
  State<PrayerRowCard> createState() => _PrayerRowCardState();
}

class _PrayerRowCardState extends State<PrayerRowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isNext) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PrayerRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNext && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isNext && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final accent = widget.prayerTime.prayer.accentFor(brightness);
    final accentLight = widget.prayerTime.prayer.accentLightFor(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: widget.isNext
            ? Border.all(color: accent.withValues(alpha: 0.25), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: widget.isNext ? accent.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
            blurRadius: widget.isNext ? 10 : 4,
            offset: Offset(0, widget.isNext ? 4 : 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon badge with pulse animation
          ScaleTransition(
            scale: widget.isNext ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: widget.isNext
                    ? LinearGradient(colors: [accentLight, accent], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : LinearGradient(colors: [accentLight.withValues(alpha: 0.2), accentLight.withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: widget.isNext
                    ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Icon(
                widget.prayerTime.prayer.icon,
                size: 20,
                color: widget.isNext ? Colors.white : accent,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Prayer name + Arabic name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.prayerTime.prayer.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.prayerTime.prayer.arabicName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.hintText,
                      ),
                    ),
                  ],
                ),
                if (widget.isActive)
                  Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.sageDarkAccent, letterSpacing: 0.5))
                else if (widget.isNext)
                  Text('Up Next', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.5))
                else if (widget.prayerTime.source == 'override')
                  Text('Masjid', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.hintText)),
              ],
            ),
          ),

          // Athan time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PrayerTime.formatTime(widget.prayerTime.athanTime),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
              ),
              Text('Athan', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.hintText)),
            ],
          ),

          // Divider + Iqamah
          if (widget.prayerTime.prayer.hasIqamah) ...[
            Container(width: 1, height: 28, color: cs.outline, margin: const EdgeInsets.symmetric(horizontal: 10)),
            SizedBox(
              width: 68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PrayerTime.formatTime(widget.prayerTime.iqamahTime),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.prayerTime.iqamahTime != null ? cs.sageDarkAccent : cs.hintText,
                    ),
                  ),
                  Text('Iqamah', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.hintText)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
