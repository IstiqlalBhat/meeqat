import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
                            'Scan QR code on your TV display',
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
                          Icon(Icons.qr_code_scanner_rounded, size: 16, color: cs.duckDarkAccent),
                          const SizedBox(width: 6),
                          Text('Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.duckDarkAccent)),
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
        builder: (_) => _TvScannerScreen(
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
// TV QR Scanner Screen
// ─────────────────────────────────────────────────────────────

class _TvScannerScreen extends StatefulWidget {
  final String backendUrl;
  final int masjidId;
  final String masjidName;

  const _TvScannerScreen({
    required this.backendUrl,
    required this.masjidId,
    required this.masjidName,
  });

  @override
  State<_TvScannerScreen> createState() => _TvScannerScreenState();
}

class _TvScannerScreenState extends State<_TvScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  bool _isPaired = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Extract pair code and optional backend URL from QR value like:
  /// "https://server/api/tv/pair?code=123456"
  ({String code, String? backendUrl})? _extractPairInfo(String rawValue) {
    try {
      // Handle if QR just contains a 6-digit code directly
      if (RegExp(r'^\d{6}$').hasMatch(rawValue.trim())) {
        return (code: rawValue.trim(), backendUrl: null);
      }

      final uri = Uri.parse(rawValue);
      final code = uri.queryParameters['code'];
      if (code != null && code.length == 6) {
        // Extract backend URL from the QR URL (scheme + host)
        final backendUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
        return (code: code, backendUrl: backendUrl);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing || _isPaired) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    debugPrint('QR scanned: ${barcode.rawValue}');

    final pairInfo = _extractPairInfo(barcode.rawValue!);
    if (pairInfo == null) {
      setState(() => _errorMessage = 'Invalid QR code. Please scan the code on the TV display.');
      return;
    }

    await _pairWithCode(pairInfo.code, pairInfo.backendUrl);
  }

  Future<void> _pairWithCode(String code, [String? backendUrlOverride]) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = backendUrlOverride ?? widget.backendUrl;
      final service = BackendService(baseUrl: baseUrl);
      await service.pairTvDevice(code, widget.masjidId);

      if (!mounted) return;
      setState(() {
        _isPaired = true;
        _isProcessing = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showManualCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Pair Code'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '6-digit code from TV',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim();
              if (RegExp(r'^\d{6}$').hasMatch(code)) {
                Navigator.pop(ctx);
                _pairWithCode(code);
              }
            },
            child: const Text('Pair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan TV Display', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
          ),

          // Overlay with cutout
          _buildScanOverlay(cs),

          // Bottom info panel
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9), Colors.black],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isPaired) ...[
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'TV Display Paired!',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connected to ${widget.masjidName}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                    ),
                  ] else if (_isProcessing) ...[
                    const SizedBox(
                      width: 40, height: 40,
                      child: CircularProgressIndicator(color: Color(0xFFC9A84C), strokeWidth: 3),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pairing...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ] else ...[
                    Text(
                      'Point your camera at the QR code\non the TV display',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _showManualCodeDialog,
                      icon: const Icon(Icons.keyboard, size: 18),
                      label: const Text('Enter code manually'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC9A84C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Syncing with: ${widget.masjidName}',
                      style: TextStyle(color: const Color(0xFFC9A84C).withValues(alpha: 0.8), fontSize: 13),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanSize = constraints.maxWidth * 0.65;
        final left = (constraints.maxWidth - scanSize) / 2;
        final top = (constraints.maxHeight - scanSize) / 2 - 40;

        return Stack(
          children: [
            // Dark overlay with transparent cutout
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: scanSize,
                      height: scanSize,
                      decoration: BoxDecoration(
                        color: Colors.red, // Any color works with srcOut
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Corner brackets
            Positioned(
              left: left - 2,
              top: top - 2,
              child: _cornerBracket(topLeft: true),
            ),
            Positioned(
              right: left - 2,
              top: top - 2,
              child: _cornerBracket(topRight: true),
            ),
            Positioned(
              left: left - 2,
              bottom: constraints.maxHeight - top - scanSize - 2,
              child: _cornerBracket(bottomLeft: true),
            ),
            Positioned(
              right: left - 2,
              bottom: constraints.maxHeight - top - scanSize - 2,
              child: _cornerBracket(bottomRight: true),
            ),
          ],
        );
      },
    );
  }

  Widget _cornerBracket({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
        painter: _CornerPainter(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9A84C)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;

    if (topLeft) {
      canvas.drawLine(const Offset(0, len), Offset.zero, paint);
      canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), paint);
      canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(size.width, size.height - len), Offset(size.width, size.height), paint);
      canvas.drawLine(Offset(size.width - len, size.height), Offset(size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
