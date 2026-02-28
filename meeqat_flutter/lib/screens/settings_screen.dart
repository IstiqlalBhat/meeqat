import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/prayer_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PrayerProvider>();
    _urlController = TextEditingController(text: provider.backendUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

            // Masjid section
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

            // Server section
            _sectionLabel('Server'),
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
                          color: AppTheme.duckLight.withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.dns_rounded, size: 20, color: AppTheme.duckDark),
                      ),
                      const SizedBox(width: 14),
                      const Text('Backend URL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(fontSize: 14, color: AppTheme.charcoal),
                    decoration: InputDecoration(
                      hintText: 'http://localhost:3000',
                      hintStyle: TextStyle(color: AppTheme.muted.withValues(alpha: 0.4)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: AppTheme.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.duckDark, width: 1.5),
                      ),
                    ),
                    onSubmitted: (val) async {
                      provider.backendUrl = val.trim();
                      await provider.saveSettings();
                      await provider.loadTimes();
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        provider.backendUrl = _urlController.text.trim();
                        await provider.saveSettings();
                        await provider.loadTimes();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Server URL saved'),
                              backgroundColor: AppTheme.sageDark,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(foregroundColor: AppTheme.duckDark),
                      child: const Text('Save & Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // About section
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

            // App name
            Center(
              child: Column(
                children: [
                  Text(
                    'Meeqat',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gold.withValues(alpha: 0.6),
                    ),
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
