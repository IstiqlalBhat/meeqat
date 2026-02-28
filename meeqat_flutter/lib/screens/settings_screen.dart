import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer_time.dart';
import '../services/prayer_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/notification_timing_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _handleNotificationsToggle(bool value, PrayerProvider provider) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable notifications in Settings'),
              backgroundColor: AppTheme.goldDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }
    }
    await provider.setNotificationsEnabled(value);
  }

  void _openTimingSheet(Prayer prayer, PrayerProvider provider) {
    showNotificationTimingSheet(
      context: context,
      displayName: prayer.displayName,
      arabicName: prayer.arabicName,
      accentColor: prayer.accentFor(Theme.of(context).brightness),
      currentAdhanTiming: provider.getNotificationTiming('adhan_${prayer.name}'),
      currentIqamahTiming: provider.getNotificationTiming('iqamah_${prayer.name}'),
      prayerName: prayer.name,
      onChanged: (key, minutes) {
        provider.setNotificationTiming(key, minutes);
      },
    );
  }

  void _openJumuahTimingSheet(PrayerProvider provider) {
    final cs = Theme.of(context).colorScheme;
    showNotificationTimingSheet(
      context: context,
      displayName: "Jumu'ah",
      arabicName: '\u062C\u0645\u0639\u0629',
      accentColor: cs.sageDarkAccent,
      currentAdhanTiming: 0,
      currentIqamahTiming: provider.getNotificationTiming('jumuah'),
      prayerName: 'jumuah',
      isJumuah: true,
      onChanged: (key, minutes) {
        provider.setNotificationTiming(key, minutes);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Consumer<PrayerProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text('Customize your Meeqat experience', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                ],
              ),
            ),

            // ── Masjid ──
            _sectionLabel('Masjid'),
            _card(
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.sage.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.mosque_rounded, size: 20, color: cs.sageDarkAccent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selected Masjid', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                        const SizedBox(height: 2),
                        Text(
                          provider.hasMasjid ? provider.selectedMasjidName : 'None selected',
                          style: TextStyle(fontSize: 12, color: provider.hasMasjid ? cs.sageDarkAccent : cs.hintText),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: cs.hintText),
                ],
              ),
            ),

            // ── Appearance ──
            _sectionLabel('Appearance'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: cs.goldAccent.withValues(alpha: 0.12),
                        ),
                        child: Icon(Icons.palette_rounded, size: 20, color: cs.goldAccent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                            const SizedBox(height: 1),
                            Text(
                              _themeLabel(themeProvider.mode),
                              style: TextStyle(fontSize: 11, color: cs.hintText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 54),
                    child: Wrap(
                      spacing: 8,
                      children: AppThemeMode.values.map((mode) {
                        final selected = themeProvider.mode == mode;
                        return GestureDetector(
                          onTap: () => themeProvider.setMode(mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? cs.goldAccent.withValues(alpha: 0.12) : Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? cs.goldAccent.withValues(alpha: 0.5) : cs.outline,
                              ),
                            ),
                            child: Text(
                              _themeChipLabel(mode),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? cs.goldDarkAccent : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Notifications ──
            _sectionLabel('Notifications'),
            _card(
              child: Column(
                children: [
                  // Master toggle
                  _toggleRow(
                    icon: Icons.notifications_active_rounded,
                    iconColor: cs.goldAccent,
                    iconBg: AppTheme.goldLight.withValues(alpha: 0.2),
                    label: 'Prayer Notifications',
                    subtitle: provider.notificationsEnabled ? 'Enabled' : 'Disabled',
                    value: provider.notificationsEnabled,
                    onChanged: (val) => _handleNotificationsToggle(val, provider),
                  ),

                  if (provider.notificationsEnabled) ...[
                    Divider(color: cs.outline, height: 20),

                    // Per-prayer timing rows
                    ...Prayer.mainPrayers.map((prayer) {
                      final isLast = prayer == Prayer.mainPrayers.last;
                      return Column(
                        children: [
                          _notificationPrayerRow(prayer, provider),
                          if (!isLast)
                            Divider(color: cs.outline.withValues(alpha: 0.5), height: 12, indent: 46),
                        ],
                      );
                    }),

                    // Jumuah row
                    Divider(color: cs.outline.withValues(alpha: 0.5), height: 12, indent: 46),
                    _notificationJumuahRow(provider),
                  ],
                ],
              ),
            ),

            // ── About ──
            _sectionLabel('About'),
            _card(
              child: Column(
                children: [
                  _aboutRow(Icons.info_outline_rounded, 'Version', '1.0.0'),
                  Divider(color: cs.outline, height: 24),
                  _aboutRow(Icons.favorite_rounded, 'Made with', 'Love', valueColor: const Color(0xFFD4626E)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  Text(
                    'Meeqat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.goldAccent.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Light for your daily prayers',
                    style: TextStyle(fontSize: 12, color: cs.hintText),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _themeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System Default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  String _themeChipLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  // ── Master toggle row ──

  Widget _toggleRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: iconBg),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 1),
              Text(subtitle, style: TextStyle(fontSize: 11, color: cs.hintText)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: cs.goldAccent.withValues(alpha: 0.4),
          activeThumbColor: cs.goldAccent,
        ),
      ],
    );
  }

  // ── Per-prayer notification row ──

  Widget _notificationPrayerRow(Prayer prayer, PrayerProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final adhanTiming = provider.getNotificationTiming('adhan_${prayer.name}');
    final iqamahTiming = provider.getNotificationTiming('iqamah_${prayer.name}');
    final isActive = adhanTiming > 0 || iqamahTiming > 0;
    final label = _dualTimingLabel(adhanTiming, iqamahTiming);

    return GestureDetector(
      onTap: () => _openTimingSheet(prayer, provider),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: prayer.accentLightFor(cs.brightness).withValues(alpha: isActive ? 0.2 : 0.1),
              ),
              child: Icon(prayer.icon, size: 16, color: prayer.accentFor(cs.brightness).withValues(alpha: isActive ? 0.8 : 0.3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    prayer.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? cs.onSurface : cs.hintText,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    prayer.arabicName,
                    style: TextStyle(fontSize: 12, color: isActive ? cs.hintText : cs.hintText.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? prayer.accentFor(cs.brightness) : cs.hintText.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: cs.hintText.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  // ── Jumuah notification row ──

  Widget _notificationJumuahRow(PrayerProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final timing = provider.getNotificationTiming('jumuah');
    final isActive = timing > 0;
    final label = timing == 0 ? 'Off' : '${timing}m';

    return GestureDetector(
      onTap: () => _openJumuahTimingSheet(provider),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: cs.sageDarkAccent.withValues(alpha: isActive ? 0.12 : 0.06),
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 16, color: cs.sageDarkAccent.withValues(alpha: isActive ? 0.8 : 0.3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    "Jumu'ah",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? cs.onSurface : cs.hintText,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '\u062C\u0645\u0639\u0629',
                    style: TextStyle(fontSize: 12, color: isActive ? cs.hintText : cs.hintText.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? cs.sageDarkAccent : cs.hintText.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: cs.hintText.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  String _dualTimingLabel(int adhan, int iqamah) {
    if (adhan == 0 && iqamah == 0) return 'Off';
    final parts = <String>[];
    if (adhan > 0) parts.add('Adhan ${adhan}m');
    if (iqamah > 0) parts.add('Iqamah ${iqamah}m');
    return parts.join(', ');
  }

  // ── Shared helpers ──

  Widget _sectionLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: cs.hintText),
      ),
    );
  }

  Widget _card({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: child,
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value, {Color? valueColor}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.hintText),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? cs.onSurface)),
      ],
    );
  }
}
