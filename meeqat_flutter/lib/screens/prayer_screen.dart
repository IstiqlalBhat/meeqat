import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import '../models/prayer_time.dart';
import '../services/prayer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/announcement_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/jumuah_banner.dart';
import '../widgets/ornament_divider.dart';
import '../widgets/shimmer_loading.dart';


class PrayerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMasjid;
  const PrayerScreen({super.key, this.onNavigateToMasjid});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> with SingleTickerProviderStateMixin {
  bool _jumuahExpanded = false;
  bool _announcementsExpanded = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, _) {
        final cs = Theme.of(context).colorScheme;
        if (provider.isLoading && provider.prayerTimes.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
            child: Column(
              children: [
                const SizedBox(height: 60),
                const ShimmerCountdownBar(),
                const SizedBox(height: 12),
                const ShimmerPrayerCard(),
              ],
            ),
          );
        }
        if (provider.errorMessage != null && provider.prayerTimes.isEmpty) {
          return _errorState(provider);
        }
        if (!provider.hasMasjid) {
          return _emptyState();
        }

        return GestureDetector(
          onHorizontalDragEnd: (details) {
            final vel = details.primaryVelocity ?? 0;
            if (vel.abs() < 300) return;
            if (vel < 0) {
              provider.goToNextDay();
            } else {
              provider.goToPreviousDay();
            }
          },
          child: LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              color: cs.goldAccent,
              onRefresh: provider.loadTimes,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Column(
                      children: [
                        _header(provider),
                        const SizedBox(height: 8),
                        const OrnamentDivider(),
                        const SizedBox(height: 10),
                        if (provider.isViewingToday) ...[
                          _countdownBar(provider),
                          const SizedBox(height: 12),
                        ],
                        _prayerCard(provider),
                        const SizedBox(height: 10),
                        if (provider.isFriday && provider.jumuah != null) ...[
                          _expandable(
                            title: "Jumu'ah",
                            icon: Icons.auto_awesome_rounded,
                            color: cs.sageDarkAccent,
                            expanded: _jumuahExpanded,
                            onTap: () => setState(() => _jumuahExpanded = !_jumuahExpanded),
                            child: JumuahBanner(jumuah: provider.jumuah!),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (provider.announcements.isNotEmpty)
                          _expandable(
                            title: 'Announcements',
                            icon: Icons.campaign_rounded,
                            color: cs.duckDarkAccent,
                            badge: provider.announcements.length,
                            expanded: _announcementsExpanded,
                            onTap: () => setState(() => _announcementsExpanded = !_announcementsExpanded),
                            child: Column(
                              children: provider.announcements.map((a) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: AnnouncementCard(announcement: a),
                              )).toList(),
                            ),
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _header(PrayerProvider p) {
    final cs = Theme.of(context).colorScheme;
    final hijri = HijriCalendar.fromDate(p.selectedDate);
    final hijriStr = '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH';

    return Column(
      children: [
        Text(
          _greeting().toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 3, color: cs.goldDarkAccent),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: p.goToPreviousDay,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(Icons.chevron_left_rounded, size: 22, color: cs.hintText),
              ),
            ),
            Text(
              _fmtDate(p.selectedDate),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.3),
            ),
            GestureDetector(
              onTap: p.goToNextDay,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(Icons.chevron_right_rounded, size: 22, color: cs.hintText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(hijriStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.goldDarkAccent)),
            if (p.hasMasjid) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('·', style: TextStyle(fontSize: 11, color: cs.hintText)),
              ),
              Icon(Icons.mosque_rounded, size: 11, color: cs.sageDarkAccent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  p.selectedMasjidName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.sageDarkAccent),
                ),
              ),
            ],
          ],
        ),
        if (!p.isViewingToday) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: p.goToToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cs.goldAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Today',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.goldDarkAccent),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  COUNTDOWN BAR
  // ═══════════════════════════════════════════════════════════

  Widget _countdownBar(PrayerProvider p) {
    if (p.nextPrayer == null || p.timeToNextPrayer == null) {
      return _allDoneStrip();
    }

    final cs = Theme.of(context).colorScheme;
    final prayer = p.nextPrayer!;
    final rem = p.timeToNextPrayer!;
    final brightness = Theme.of(context).brightness;
    final accent = prayer.prayer.accentFor(brightness);
    final accentLight = prayer.prayer.accentLightFor(brightness);
    final gap = p.gapToNextPrayer;
    final progress = 1.0 - (rem.inSeconds / gap).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [cs.surface, accentLight.withValues(alpha: 0.08)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [accentLight, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(prayer.prayer.icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEXT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: cs.hintText)),
                    Row(
                      children: [
                        Text(prayer.prayer.displayName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.3)),
                        const SizedBox(width: 5),
                        Text(prayer.prayer.arabicName, style: TextStyle(fontSize: 13, color: cs.hintText)),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _fmtCountdown(rem),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Athan ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.hintText)),
              Text(PrayerTime.formatTime(prayer.athanTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface, fontFeatures: const [FontFeature.tabularFigures()])),
              if (prayer.iqamahTime != null) ...[
                Text('  ·  ', style: TextStyle(color: cs.outline)),
                Text('Iqamah ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.hintText)),
                Text(PrayerTime.formatTime(prayer.iqamahTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.sageDarkAccent, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: SizedBox(
              height: 2.5,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(accent.withValues(alpha: 0.75)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _allDoneStrip() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sage.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.sageDarkAccent.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.check_circle_rounded, size: 20, color: cs.sageDarkAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All prayers completed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
                Text('See you tomorrow, In Sha Allah', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PRAYER CARD
  // ═══════════════════════════════════════════════════════════

  Widget _prayerCard(PrayerProvider p) {
    final cs = Theme.of(context).colorScheme;
    final prayers = p.fivePrayers;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Column header
          _columnHeader(),
          // Prayer rows
          ...List.generate(prayers.length, (i) {
            final pt = prayers[i];
            final bool isNext;
            final bool isCurrent;
            final bool isPast;
            if (p.isViewingToday) {
              isNext = p.nextPrayer?.prayer == pt.prayer;
              isCurrent = p.currentPrayer == pt.prayer;
              isPast = !isNext && !isCurrent && pt.athanDate != null && pt.athanDate!.isBefore(DateTime.now());
            } else {
              isNext = false;
              isCurrent = false;
              isPast = false;
            }
            return _prayerRow(pt, isNext: isNext, isCurrent: isCurrent, isPast: isPast, isLast: i == prayers.length - 1);
          }),
          // Sun strip
          _sunStrip(p),
        ],
      ),
    );
  }

  Widget _columnHeader() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(58, 8, 16, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          Text('ATHAN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: cs.hintText)),
          const SizedBox(width: 7),
          Container(width: 1, height: 10, color: cs.outline),
          SizedBox(
            width: 72,
            child: Text('IQAMAH', textAlign: TextAlign.end, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: cs.hintText)),
          ),
        ],
      ),
    );
  }

  Widget _prayerRow(PrayerTime pt, {required bool isNext, required bool isCurrent, required bool isPast, required bool isLast}) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final accent = pt.prayer.accentFor(brightness);
    final accentLight = pt.prayer.accentLightFor(brightness);
    final dim = isPast ? 0.45 : 1.0;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final glowAlpha = isNext ? (_pulseCtrl.value * 0.3 + 0.6) : 1.0;

        return Container(
          decoration: BoxDecoration(
            color: isNext
                ? accent.withValues(alpha: 0.05)
                : isCurrent
                    ? cs.sageDarkAccent.withValues(alpha: 0.04)
                    : null,
            border: Border(
              left: BorderSide(
                width: 3,
                color: isNext
                    ? accent.withValues(alpha: glowAlpha)
                    : isCurrent
                        ? cs.sageDarkAccent.withValues(alpha: 0.5)
                        : isPast
                            ? accentLight.withValues(alpha: 0.25)
                            : accentLight.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 16, 14),
                child: Row(
                  children: [
                    // Prayer-specific icon badge
                    _prayerIcon(pt.prayer, isNext: isNext, isCurrent: isCurrent, isPast: isPast),
                    const SizedBox(width: 10),

                    // Name + Arabic + chip
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              pt.prayer.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isNext || isCurrent ? FontWeight.w700 : FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: dim),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            pt.prayer.arabicName,
                            style: TextStyle(fontSize: 12, color: isPast ? cs.hintText.withValues(alpha: 0.5) : cs.hintText),
                          ),
                          if (isCurrent) ...[const SizedBox(width: 6), _chip('NOW', cs.sageDarkAccent)],
                          if (isNext) ...[const SizedBox(width: 6), _chip('NEXT', accent)],
                        ],
                      ),
                    ),

                    // Athan time
                    Text(
                      PrayerTime.formatTime(pt.athanTime),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: dim),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Container(width: 1, height: 20, color: cs.outline, margin: const EdgeInsets.symmetric(horizontal: 7)),
                    // Iqamah time
                    SizedBox(
                      width: 72,
                      child: Text(
                        PrayerTime.formatTime(pt.iqamahTime),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: pt.iqamahTime != null
                              ? cs.sageDarkAccent.withValues(alpha: dim)
                              : cs.hintText.withValues(alpha: 0.4),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Divider(height: 1, thickness: 0.4, color: cs.outline),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Beautiful prayer-specific icon badges
  Widget _prayerIcon(Prayer prayer, {required bool isNext, required bool isCurrent, required bool isPast}) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final accent = prayer.accentFor(brightness);
    final accentLight = prayer.accentLightFor(brightness);
    const size = 34.0;

    if (isNext) {
      // Vibrant gradient badge with glow
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: LinearGradient(colors: [accentLight, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(prayer.icon, size: 17, color: Colors.white),
      );
    }

    if (isCurrent) {
      // Sage-tinted badge with border
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: cs.sageDarkAccent.withValues(alpha: 0.1),
          border: Border.all(color: cs.sageDarkAccent.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Icon(prayer.icon, size: 17, color: cs.sageDarkAccent),
      );
    }

    if (isPast) {
      // Soft muted badge with subtle check overlay
      return Stack(
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: cs.outline.withValues(alpha: 0.5),
            ),
            child: Icon(prayer.icon, size: 16, color: accent.withValues(alpha: 0.35)),
          ),
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 13, height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface,
                border: Border.all(color: AppTheme.sage.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Icon(Icons.check_rounded, size: 8, color: cs.sageAccent),
            ),
          ),
        ],
      );
    }

    // Future prayer — light badge with accent icon
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: accentLight.withValues(alpha: 0.15),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Icon(prayer.icon, size: 16, color: accent.withValues(alpha: 0.6)),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: color)),
    );
  }

  Widget _sunStrip(PrayerProvider p) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5)),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_rounded, size: 13, color: cs.goldAccent),
          const SizedBox(width: 5),
          Text('Sunrise ', style: TextStyle(fontSize: 10, color: cs.hintText)),
          Text(PrayerTime.formatTime(p.sunrise?.athanTime), maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()])),
          const Spacer(),
          Icon(Icons.wb_twilight_rounded, size: 13, color: cs.goldDarkAccent),
          const SizedBox(width: 5),
          Text('Sunset ', style: TextStyle(fontSize: 10, color: cs.hintText)),
          Text(PrayerTime.formatTime(p.sunset?.athanTime), maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  EXPANDABLE SECTIONS
  // ═══════════════════════════════════════════════════════════

  Widget _expandable({
    required String title,
    required IconData icon,
    required Color color,
    int? badge,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: expanded
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
                  child: Icon(icon, size: 13, color: color),
                ),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('$badge', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: cs.hintText),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: child,
          ),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  EMPTY / ERROR
  // ═══════════════════════════════════════════════════════════

  Widget _emptyState() {
    return EmptyState(
      icon: Icons.mosque_rounded,
      title: 'Assalamu Alaikum',
      subtitle: 'Select your local masjid to see\nprayer times and iqamah schedules',
      actionLabel: widget.onNavigateToMasjid != null ? 'Find a Masjid' : null,
      actionIcon: widget.onNavigateToMasjid != null ? Icons.mosque_rounded : null,
      onAction: widget.onNavigateToMasjid,
    );
  }

  Widget _errorState(PrayerProvider p) {
    return ErrorState(
      message: p.errorMessage!,
      onRetry: p.loadTimes,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════

  String _greeting() {
    return 'Assalamu Alaikum';
  }

  String _fmtDate(DateTime d) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
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
