import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/prayer_provider.dart';
import 'screens/prayer_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/masjid_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MeeqatApp());
}

class MeeqatApp extends StatelessWidget {
  const MeeqatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PrayerProvider(),
      child: MaterialApp(
        title: 'Meeqat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const MeeqatShell(),
      ),
    );
  }
}

class MeeqatShell extends StatefulWidget {
  const MeeqatShell({super.key});

  @override
  State<MeeqatShell> createState() => _MeeqatShellState();
}

class _MeeqatShellState extends State<MeeqatShell> {
  int _currentIndex = 0;

  void _switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  Widget _screenForIndex(int index) {
    switch (index) {
      case 0:
        return PrayerScreen(onNavigateToMasjid: () => _switchToTab(3));
      case 1:
        return const QiblaScreen();
      case 2:
        return const AnnouncementsScreen();
      case 3:
        return const MasjidScreen();
      case 4:
        return const SettingsScreen();
      default:
        return PrayerScreen(onNavigateToMasjid: () => _switchToTab(3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _screenForIndex(_currentIndex),
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(0, Icons.access_time_filled, 'Prayers'),
                _navItem(1, Icons.explore, 'Qibla'),
                _navItem(2, Icons.campaign_rounded, 'News'),
                _navItem(3, Icons.mosque_rounded, 'Masjid'),
                _navItem(4, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    final color = isActive ? AppTheme.gold : AppTheme.muted.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: () => _switchToTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.gold.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
