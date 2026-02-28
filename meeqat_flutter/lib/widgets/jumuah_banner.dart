import 'package:flutter/material.dart';
import '../models/masjid.dart';
import '../models/prayer_time.dart';
import '../theme/app_theme.dart';

class JumuahBanner extends StatelessWidget {
  final JumuahTimes jumuah;
  const JumuahBanner({super.key, required this.jumuah});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [AppTheme.sageLight.withValues(alpha: 0.15), AppTheme.sage.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.sage.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 20, color: cs.sageDarkAccent),
              const SizedBox(width: 8),
              Text("Jumu'ah", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.sageDarkAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Friday', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.sageDarkAccent)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (jumuah.khutbahTime != null)
                _timeCol(context, Icons.chat_bubble, 'Khutbah', jumuah.khutbahTime!, cs.goldAccent),
              if (jumuah.firstJamaat != null) ...[
                const Spacer(),
                _timeCol(context, Icons.groups, '1st Jamaat', jumuah.firstJamaat!, cs.sageDarkAccent),
              ],
              if (jumuah.secondJamaat != null) ...[
                const Spacer(),
                _timeCol(context, Icons.groups, '2nd Jamaat', jumuah.secondJamaat!, cs.duckDarkAccent),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeCol(BuildContext context, IconData icon, String label, String time, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(PrayerTime.formatTime(time), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
      ],
    );
  }
}
