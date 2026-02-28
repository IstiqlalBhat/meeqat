import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import '../models/prayer_time.dart';
import '../services/prayer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/announcement_card.dart';
import '../widgets/jumuah_banner.dart';

class PrayerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMasjid;
  const PrayerScreen({super.key, this.onNavigateToMasjid});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> with SingleTickerProviderStateMixin {
  bool _jumuahExpanded = false;
  bool _announcementsExpanded = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.prayerTimes.isEmpty) {
          return Center(
            child: SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(color: AppTheme.gold.withValues(alpha: 0.6), strokeWidth: 2),
            ),
          );
        }

        if (provider.errorMessage != null && provider.prayerTimes.isEmpty) {
          return _buildErrorState(provider);
        }

        if (!provider.hasMasjid) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: AppTheme.gold,
          onRefresh: provider.loadTimes,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              children: [
                _buildHeader(provider),
                const SizedBox(height: 14),
                _buildCountdownHero(provider),
                const SizedBox(height: 16),
                _buildPrayerTimeline(provider),
                if (provider.isFriday && provider.jumuah != null) ...[
                  const SizedBox(height: 12),
                  _buildExpandableSection(
                    title: "Jumu'ah Times",
                    icon: Icons.auto_awesome,
                    accentColor: AppTheme.sageDark,
                    isExpanded: _jumuahExpanded,
                    onTap: () => setState(() => _jumuahExpanded = !_jumuahExpanded),
                    child: JumuahBanner(jumuah: provider.jumuah!),
                  ),
                ],
                if (provider.announcements.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildExpandableSection(
                    title: 'Announcements',
                    icon: Icons.campaign_rounded,
                    accentColor: AppTheme.duckDark,
                    badge: provider.announcements.length,
                    isExpanded: _announcementsExpanded,
                    onTap: () => setState(() => _announcementsExpanded = !_announcementsExpanded),
                    child: Column(
                      children: provider.announcements.map((a) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AnnouncementCard(announcement: a),
                      )).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════

  Widget _buildHeader(PrayerProvider provider) {
    return Column(
      children: [
        // Greeting — warm, understated
        Text(
          _greeting().toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: AppTheme.gold.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 6),
        // Gregorian
        Text(
          _formatDate(provider.currentDate),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.charcoal, letterSpacing: -0.3),
        ),
        const SizedBox(height: 2),
        // Hijri
        Text(
          _hijriDate(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.gold.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 10),
        // Decorative divider
        _ornamentalDivider(),
        const SizedBox(height: 8),
        // Masjid
        if (provider.hasMasjid)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.sage.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.sage.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mosque_rounded, size: 12, color: AppTheme.sageDark.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text(
                  provider.selectedMasjidName,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.sageDark.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ornamentalDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 0.5, color: AppTheme.goldLight.withValues(alpha: 0.5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 5, height: 5,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5), width: 0.8),
              ),
            ),
          ),
        ),
        Expanded(child: Container(height: 0.5, color: AppTheme.goldLight.withValues(alpha: 0.5))),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  COUNTDOWN HERO — Flip-clock style
  // ════════════════════════════════════════════════════════════

  Widget _buildCountdownHero(PrayerProvider provider) {
    if (provider.nextPrayer == null || provider.timeToNextPrayer == null) {
      return _buildAllDoneCard();
    }

    final prayer = provider.nextPrayer!;
    final remaining = provider.timeToNextPrayer!;
    final accent = prayer.prayer.accentDark;
    final accentLight = prayer.prayer.accentLight;
    final gap = provider.gapToNextPrayer;
    final progress = 1.0 - (remaining.inSeconds / gap).clamp(0.0, 1.0);

    final total = remaining.inSeconds.clamp(0, 99999);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            accentLight.withValues(alpha: 0.06),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          // Watermark icon
          Positioned(
            right: -8,
            top: -8,
            child: Icon(prayer.prayer.icon, size: 90, color: accent.withValues(alpha: 0.035)),
          ),
          Column(
            children: [
              // Top row: NEXT PRAYER label + Arabic name
              Row(
                children: [
                  Text(
                    'NEXT PRAYER',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: AppTheme.muted.withValues(alpha: 0.45),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    prayer.prayer.arabicName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: accent.withValues(alpha: 0.35)),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Prayer name — large
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  prayer.prayer.displayName,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.charcoal, letterSpacing: -0.5),
                ),
              ),

              const SizedBox(height: 16),

              // Flip-clock digits
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (h > 0) ...[
                    _digitBlock(h.toString().padLeft(2, '0'), 'HR', accent),
                    _colonSeparator(accent),
                  ],
                  _digitBlock(m.toString().padLeft(2, '0'), 'MIN', accent),
                  _colonSeparator(accent),
                  _digitBlock(s.toString().padLeft(2, '0'), 'SEC', accent),
                ],
              ),

              const SizedBox(height: 16),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: accent.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent.withValues(alpha: 0.7)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Athan / Iqamah
              Row(
                children: [
                  _heroTimeLabel('Athan', PrayerTime.formatTime(prayer.athanTime), AppTheme.charcoal),
                  if (prayer.iqamahTime != null) ...[
                    Container(
                      width: 1, height: 18,
                      color: AppTheme.creamDark,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    _heroTimeLabel('Iqamah', PrayerTime.formatTime(prayer.iqamahTime), AppTheme.sageDark),
                  ],
                  const Spacer(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _digitBlock(String digits, String label, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.06)),
          ),
          child: Center(
            child: Text(
              digits,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.charcoal,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppTheme.muted.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _colonSeparator(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, left: 8, right: 8),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _heroTimeLabel(String label, String time, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppTheme.muted.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildAllDoneCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.sage.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.sageDark.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.check_rounded, color: AppTheme.sageDark, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('All prayers completed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
              const SizedBox(height: 2),
              Text('See you tomorrow, In Sha Allah', style: TextStyle(fontSize: 12, color: AppTheme.muted.withValues(alpha: 0.6))),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PRAYER TIMELINE
  // ════════════════════════════════════════════════════════════

  Widget _buildPrayerTimeline(PrayerProvider provider) {
    final prayers = provider.fivePrayers;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Prayer rows
          ...List.generate(prayers.length, (i) {
            final pt = prayers[i];
            final isNext = provider.nextPrayer?.prayer == pt.prayer;
            final isCurrent = provider.currentPrayer == pt.prayer;
            final isPast = !isNext && !isCurrent && _isPast(pt);
            final isLast = i == prayers.length - 1;

            return _buildTimelineRow(
              pt,
              isNext: isNext,
              isCurrent: isCurrent,
              isPast: isPast,
              showDivider: !isLast,
              index: i,
              total: prayers.length,
            );
          }),

          // Sun strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppTheme.cream.withValues(alpha: 0.5),
              border: Border(top: BorderSide(color: AppTheme.creamDark.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                _sunChip(Icons.wb_sunny_rounded, 'Sunrise', provider.sunrise?.athanTime, AppTheme.gold),
                const Spacer(),
                _sunChip(Icons.wb_twilight_rounded, 'Sunset', provider.sunset?.athanTime, AppTheme.goldDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(
    PrayerTime pt, {
    required bool isNext,
    required bool isCurrent,
    required bool isPast,
    required bool showDivider,
    required int index,
    required int total,
  }) {
    final accent = pt.prayer.accentDark;
    final accentLight = pt.prayer.accentLight;
    final dimFactor = isPast ? 0.4 : 1.0;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowValue = isNext ? (_glowController.value * 0.4 + 0.6) : 1.0;

        return Container(
          decoration: BoxDecoration(
            color: isNext
                ? accent.withValues(alpha: 0.04)
                : isCurrent
                    ? AppTheme.sageDark.withValues(alpha: 0.03)
                    : null,
            border: isNext
                ? Border(left: BorderSide(color: accent.withValues(alpha: glowValue * 0.9), width: 3.5))
                : isCurrent
                    ? Border(left: BorderSide(color: AppTheme.sageDark.withValues(alpha: 0.5), width: 3.5))
                    : const Border(left: BorderSide(color: Colors.transparent, width: 3.5)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 18, 13),
                child: Row(
                  children: [
                    // Timeline dot
                    _timelineDot(accent, accentLight, isNext: isNext, isCurrent: isCurrent, isPast: isPast),
                    const SizedBox(width: 12),

                    // Prayer name column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pt.prayer.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isNext || isCurrent ? FontWeight.w700 : FontWeight.w600,
                                  color: AppTheme.charcoal.withValues(alpha: dimFactor),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pt.prayer.arabicName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.muted.withValues(alpha: isPast ? 0.2 : 0.35),
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                _statusChip('NOW', AppTheme.sageDark),
                              ],
                              if (isNext) ...[
                                const SizedBox(width: 8),
                                _statusChip('NEXT', accent),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Times
                    SizedBox(
                      width: 65,
                      child: Text(
                        PrayerTime.formatTime(pt.athanTime),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.charcoal.withValues(alpha: dimFactor),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Container(
                      width: 1, height: 22,
                      color: AppTheme.creamDark.withValues(alpha: 0.4),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    SizedBox(
                      width: 65,
                      child: Text(
                        PrayerTime.formatTime(pt.iqamahTime),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: pt.iqamahTime != null
                              ? AppTheme.sageDark.withValues(alpha: dimFactor)
                              : AppTheme.muted.withValues(alpha: 0.15),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showDivider)
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Divider(height: 1, thickness: 0.5, color: AppTheme.creamDark.withValues(alpha: 0.35)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _timelineDot(Color accent, Color accentLight, {required bool isNext, required bool isCurrent, required bool isPast}) {
    if (isNext) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [accentLight, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
      );
    }
    if (isCurrent) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.sageDark.withValues(alpha: 0.12),
          border: Border.all(color: AppTheme.sageDark.withValues(alpha: 0.4), width: 1.5),
        ),
        child: const Icon(Icons.volume_up_rounded, size: 13, color: AppTheme.sageDark),
      );
    }
    if (isPast) {
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.creamDark.withValues(alpha: 0.4),
        ),
        child: Icon(Icons.check_rounded, size: 14, color: AppTheme.muted.withValues(alpha: 0.35)),
      );
    }
    // Future
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentLight.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 1),
      ),
      child: Icon(Icons.schedule_rounded, size: 13, color: accent.withValues(alpha: 0.4)),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: color),
      ),
    );
  }

  Widget _sunChip(IconData icon, String label, String? time, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.muted.withValues(alpha: 0.5))),
        const SizedBox(width: 5),
        Text(
          PrayerTime.formatTime(time),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.charcoal.withValues(alpha: 0.55)),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  EXPANDABLE SECTIONS
  // ════════════════════════════════════════════════════════════

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required Color accentColor,
    int? badge,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(18))
                  : BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.08),
                  ),
                  child: Icon(icon, size: 14, color: accentColor.withValues(alpha: 0.7)),
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppTheme.muted.withValues(alpha: 0.35)),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: child,
          ),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  EMPTY / ERROR STATES
  // ════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.goldLight.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.mosque_rounded, size: 36, color: AppTheme.gold.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 28),
            const Text(
              'Assalamu Alaikum',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.charcoal, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your local masjid to see\nprayer times and iqamah schedules',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.muted.withValues(alpha: 0.7), height: 1.6),
            ),
            const SizedBox(height: 32),
            if (widget.onNavigateToMasjid != null)
              GestureDetector(
                onTap: widget.onNavigateToMasjid,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mosque_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Find a Masjid', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(PrayerProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: AppTheme.muted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(provider.errorMessage!, style: TextStyle(fontSize: 14, color: AppTheme.muted.withValues(alpha: 0.7))),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: provider.loadTimes,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  bool _isPast(PrayerTime pt) {
    final date = pt.athanDate;
    return date != null && date.isBefore(DateTime.now());
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _hijriDate() {
    final hijri = HijriCalendar.now();
    return '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH';
  }

  String _formatDate(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}
