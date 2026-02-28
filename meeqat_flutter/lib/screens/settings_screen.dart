import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import '../services/prayer_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  final Map<Prayer, bool> _prayerToggles = {};
  int _minutesBefore = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _minutesBefore = prefs.getInt('notify_minutes_before') ?? 0;
      for (final p in Prayer.mainPrayers) {
        _prayerToggles[p] = prefs.getBool('notify_${p.name}') ?? true;
      }
      _loaded = true;
    });
  }

  Future<void> _setNotificationsEnabled(bool value) async {
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
    _reschedule();
  }

  Future<void> _setPrayerToggle(Prayer prayer, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notify_${prayer.name}', value);
    setState(() => _prayerToggles[prayer] = value);
    _reschedule();
  }

  Future<void> _setMinutesBefore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notify_minutes_before', value);
    setState(() => _minutesBefore = value);
    _reschedule();
  }

  void _reschedule() {
    final provider = context.read<PrayerProvider>();
    NotificationService.schedulePrayerNotifications(provider.prayerTimes);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Consumer<PrayerProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
                  SizedBox(height: 4),
                  Text('Customize your Meeqat experience', style: TextStyle(fontSize: 14, color: AppTheme.muted)),
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
                    child: const Icon(Icons.mosque_rounded, size: 20, color: AppTheme.sageDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Selected Masjid', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                        const SizedBox(height: 2),
                        Text(
                          provider.hasMasjid ? provider.selectedMasjidName : 'None selected',
                          style: TextStyle(fontSize: 12, color: provider.hasMasjid ? AppTheme.sageDark : AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.muted.withValues(alpha: 0.4)),
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
                    iconColor: AppTheme.gold,
                    iconBg: AppTheme.goldLight.withValues(alpha: 0.2),
                    label: 'Prayer Notifications',
                    subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                    value: _notificationsEnabled,
                    onChanged: _setNotificationsEnabled,
                  ),

                  if (_notificationsEnabled) ...[
                    Divider(color: AppTheme.creamDark.withValues(alpha: 0.5), height: 20),

                    // Timing selector
                    _timingSelector(),

                    Divider(color: AppTheme.creamDark.withValues(alpha: 0.5), height: 20),

                    // Per-prayer toggles
                    ...Prayer.mainPrayers.map((prayer) {
                      final isLast = prayer == Prayer.mainPrayers.last;
                      return Column(
                        children: [
                          _prayerToggleRow(prayer),
                          if (!isLast) Divider(color: AppTheme.creamDark.withValues(alpha: 0.3), height: 12, indent: 54),
                        ],
                      );
                    }),
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
                  Divider(color: AppTheme.creamDark, height: 24),
                  _aboutRow(Icons.code_rounded, 'Built with', 'Flutter'),
                  Divider(color: AppTheme.creamDark, height: 24),
                  _aboutRow(Icons.favorite_rounded, 'Made with', 'Love', valueColor: const Color(0xFFE88B8B)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  Text(
                    'Meeqat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.gold.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Light for your daily prayers',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Notification toggle row ──

  Widget _toggleRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
              const SizedBox(height: 1),
              Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.muted.withValues(alpha: 0.6))),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppTheme.gold.withValues(alpha: 0.35),
          activeThumbColor: AppTheme.gold,
        ),
      ],
    );
  }

  // ── Timing selector ──

  Widget _timingSelector() {
    final options = [0, 5, 10, 15, 30];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.duckLight.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.timer_outlined, size: 20, color: AppTheme.duckDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notify', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                  const SizedBox(height: 1),
                  Text(
                    _minutesBefore == 0 ? 'At athan time' : '$_minutesBefore min before athan',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: options.map((min) {
            final selected = _minutesBefore == min;
            final label = min == 0 ? 'At athan' : '${min}m before';
            return GestureDetector(
              onTap: () => _setMinutesBefore(min),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.gold.withValues(alpha: 0.12) : AppTheme.cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppTheme.gold.withValues(alpha: 0.4) : AppTheme.creamDark.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppTheme.goldDark : AppTheme.muted,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Per-prayer toggle ──

  Widget _prayerToggleRow(Prayer prayer) {
    final enabled = _prayerToggles[prayer] ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: prayer.accentLight.withValues(alpha: enabled ? 0.18 : 0.08),
            ),
            child: Icon(prayer.icon, size: 16, color: prayer.accentDark.withValues(alpha: enabled ? 0.7 : 0.25)),
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
                    color: enabled ? AppTheme.charcoal : AppTheme.muted.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  prayer.arabicName,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted.withValues(alpha: enabled ? 0.3 : 0.15)),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: (val) => _setPrayerToggle(prayer, val),
            activeTrackColor: prayer.accentDark.withValues(alpha: 0.35),
            activeThumbColor: prayer.accentDark,
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ──

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppTheme.muted.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: child,
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.muted.withValues(alpha: 0.5)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.muted)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.charcoal)),
      ],
    );
  }
}
