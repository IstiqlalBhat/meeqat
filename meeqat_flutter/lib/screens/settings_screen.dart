import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prayer_time.dart';
import '../services/prayer_provider.dart';
import '../services/backend_service.dart';
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

            // ── TV Display ──
            _sectionLabel('TV Display'),
            _card(
              child: GestureDetector(
                onTap: () {
                  if (!provider.hasMasjid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please select a masjid first'),
                        backgroundColor: AppTheme.goldDark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }
                  _openTvScanner(provider);
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.duckLight.withValues(alpha: 0.2),
                      ),
                      child: Icon(Icons.tv_rounded, size: 20, color: cs.duckDarkAccent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sync to TV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                            'Enter the code shown on your TV',
                            style: TextStyle(fontSize: 12, color: cs.hintText),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.duckDarkAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 16, color: cs.duckDarkAccent),
                          const SizedBox(width: 6),
                          Text('Pair', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.duckDarkAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
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

  void _openTvScanner(PrayerProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TvPairScreen(
          backendUrl: provider.backendUrl,
          masjidId: provider.selectedMasjidId,
          masjidName: provider.selectedMasjidName,
        ),
      ),
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

// ─────────────────────────────────────────────────────────────
// TV Pair Code Entry Screen
// ─────────────────────────────────────────────────────────────

class _TvPairScreen extends StatefulWidget {
  final String backendUrl;
  final int masjidId;
  final String masjidName;

  const _TvPairScreen({
    required this.backendUrl,
    required this.masjidId,
    required this.masjidName,
  });

  @override
  State<_TvPairScreen> createState() => _TvPairScreenState();
}

enum _PairState { idle, loading, success, error }

class _TvPairScreenState extends State<_TvPairScreen> {
  static const _codeLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  _PairState _state = _PairState.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-focus the first digit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (_state == _PairState.loading || _state == _PairState.success) return;

    // Clear error on new input
    if (_state == _PairState.error) {
      setState(() {
        _state = _PairState.idle;
        _errorMessage = null;
      });
    }

    if (value.length > 1) {
      // Handle paste — distribute digits across fields
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < _codeLength; i++) {
        final d = (index + i) < digits.length ? digits[index + i] : (i <= index ? _controllers[i].text : '');
        _controllers[i].text = i < digits.length ? digits[i] : _controllers[i].text;
      }
      final lastIdx = (digits.length - 1).clamp(0, _codeLength - 1);
      _focusNodes[lastIdx].requestFocus();
      _controllers[lastIdx].selection = TextSelection.fromPosition(
        TextPosition(offset: _controllers[lastIdx].text.length),
      );
      if (_code.length == _codeLength) _submit();
      return;
    }

    if (value.isNotEmpty && index < _codeLength - 1) {
      // Advance to next field
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isNotEmpty && index == _codeLength - 1 && _code.length == _codeLength) {
      _submit();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey.keyLabel == 'Backspace' &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _submit() async {
    final code = _code;
    if (code.length != _codeLength) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _state = _PairState.loading;
      _errorMessage = null;
    });

    try {
      final service = BackendService(baseUrl: widget.backendUrl);
      await service.pairTvDevice(code, widget.masjidId);

      if (!mounted) return;
      setState(() => _state = _PairState.success);

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PairState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      // Re-focus last field so user can retry
      _focusNodes[_codeLength - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        title: const Text('Pair TV Display', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // TV icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.goldAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.tv_rounded, size: 36, color: cs.goldAccent),
              ),
              const SizedBox(height: 20),

              // Instruction
              Text(
                'Enter the 6-digit code\nshown on your TV',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),

              // Digit input boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_codeLength, (i) {
                  final isFilled = _controllers[i].text.isNotEmpty;
                  final isFocused = _focusNodes[i].hasFocus;

                  return Padding(
                    padding: EdgeInsets.only(left: i > 0 ? 10 : 0),
                    child: SizedBox(
                      width: 48,
                      height: 60,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) => _onKeyEvent(i, event),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _state == _PairState.success
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                                : _state == _PairState.error
                                    ? Colors.red.withValues(alpha: 0.06)
                                    : isFocused
                                        ? cs.goldAccent.withValues(alpha: 0.08)
                                        : cs.onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _state == _PairState.success
                                  ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                                  : _state == _PairState.error
                                      ? Colors.red.withValues(alpha: 0.4)
                                      : isFocused
                                          ? cs.goldAccent.withValues(alpha: 0.6)
                                          : cs.outline,
                              width: isFocused ? 2 : 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            onChanged: (v) => _onDigitChanged(i, v),
                            enabled: _state != _PairState.loading && _state != _PairState.success,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _state == _PairState.success
                                  ? const Color(0xFF4CAF50)
                                  : isFilled
                                      ? cs.onSurface
                                      : cs.hintText,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28),

              // State feedback
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStateFeedback(cs),
              ),

              const SizedBox(height: 20),

              // Masjid name
              Text(
                'Syncing with: ${widget.masjidName}',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.goldAccent.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateFeedback(ColorScheme cs) {
    switch (_state) {
      case _PairState.loading:
        return const SizedBox(
          key: ValueKey('loading'),
          width: 28,
          height: 28,
          child: CircularProgressIndicator(color: Color(0xFFC9A84C), strokeWidth: 2.5),
        );
      case _PairState.success:
        return Column(
          key: const ValueKey('success'),
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 44),
            const SizedBox(height: 8),
            Text(
              'TV Display Paired!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        );
      case _PairState.error:
        return Container(
          key: const ValueKey('error'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Text(
            _errorMessage ?? 'Pairing failed. Please try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        );
      case _PairState.idle:
        return const SizedBox.shrink(key: ValueKey('idle'));
    }
  }
}
