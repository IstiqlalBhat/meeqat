import 'package:flutter/material.dart';
import '../models/masjid.dart';
import '../models/prayer_time.dart';
import '../theme/app_theme.dart';

class JumuahBanner extends StatelessWidget {
  final JumuahTimes jumuah;
  const JumuahBanner({super.key, required this.jumuah});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
              const Icon(Icons.star_rounded, size: 20, color: AppTheme.sageDark),
              const SizedBox(width: 8),
              const Text("Jumu'ah", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.sageDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Friday', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.sageDark)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (jumuah.khutbahTime != null)
                _timeCol(Icons.chat_bubble, 'Khutbah', jumuah.khutbahTime!, AppTheme.gold),
              if (jumuah.firstJamaat != null) ...[
                const Spacer(),
                _timeCol(Icons.groups, '1st Jamaat', jumuah.firstJamaat!, AppTheme.sageDark),
              ],
              if (jumuah.secondJamaat != null) ...[
                const Spacer(),
                _timeCol(Icons.groups, '2nd Jamaat', jumuah.secondJamaat!, AppTheme.duckDark),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeCol(IconData icon, String label, String time, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.muted)),
        const SizedBox(height: 2),
        Text(PrayerTime.formatTime(time), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
      ],
    );
  }
}
