import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/masjid.dart';
import '../services/prayer_provider.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import '../widgets/info_banner.dart';
import '../widgets/shimmer_loading.dart';

class MasjidScreen extends StatefulWidget {
  const MasjidScreen({super.key});

  @override
  State<MasjidScreen> createState() => _MasjidScreenState();
}

class _MasjidScreenState extends State<MasjidScreen> {
  List<Masjid> _masjids = [];
  bool _isLoading = true;
  String? _error;
  bool _usingGps = false;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadWithGps();
  }

  Future<void> _loadWithGps() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        // No GPS permission — fall back to showing all masjids
        await _loadAllMasjids();
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));

      _userPosition = position;
      _usingGps = true;

      if (!mounted) return;
      final provider = context.read<PrayerProvider>();
      final service = BackendService(baseUrl: provider.backendUrl);
      final list = await service.fetchNearbyMasjids(
        position.latitude,
        position.longitude,
        radius: 100,
      );

      if (list.isEmpty) {
        // No nearby masjids — show all as fallback
        await _loadAllMasjids();
        return;
      }

      setState(() { _masjids = list; _isLoading = false; });
    } catch (e) {
      // GPS failed — fall back to all masjids
      await _loadAllMasjids();
    }
  }

  Future<void> _loadAllMasjids() async {
    setState(() { _isLoading = true; _error = null; _usingGps = false; });
    try {
      final provider = context.read<PrayerProvider>();
      final service = BackendService(baseUrl: provider.backendUrl);
      final list = await service.fetchMasjids();
      setState(() { _masjids = list; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Could not load masjids'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: cs.goldAccent,
      onRefresh: _loadWithGps,
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 120),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Masjid', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(
                  _usingGps
                    ? 'Showing masjids near your location'
                    : 'Choose your local masjid for accurate iqamah times',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // GPS indicator
          if (_usingGps && _userPosition != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: InfoBanner(
                icon: Icons.my_location_rounded,
                text: 'Sorted by distance from you',
                color: AppTheme.duck,
                action: GestureDetector(
                  onTap: _loadAllMasjids,
                  child: Text('Show all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.duckDarkAccent)),
                ),
              ),
            ),

          if (!_usingGps && !_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: InfoBanner(
                icon: Icons.location_searching_rounded,
                text: 'Tap to find masjids near you',
                color: AppTheme.gold,
                onTap: _loadWithGps,
                action: Icon(Icons.arrow_forward_ios, size: 12, color: cs.goldAccent),
              ),
            ),

          const SizedBox(height: 8),

          // Current selection
          Consumer<PrayerProvider>(
            builder: (context, provider, _) {
              if (!provider.hasMasjid) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [AppTheme.sage.withValues(alpha: 0.15), AppTheme.sageLight.withValues(alpha: 0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppTheme.sage.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.sageDarkAccent.withValues(alpha: 0.15),
                        ),
                        child: Icon(Icons.check_circle_rounded, color: cs.sageDarkAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Masjid', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, color: cs.sageDarkAccent)),
                            const SizedBox(height: 2),
                            Text(provider.selectedMasjidName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Loading / Error / List
          if (_isLoading)
            ...List.generate(4, (_) => const ShimmerMasjidCard())
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: cs.hintText),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _loadWithGps,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(foregroundColor: cs.goldAccent),
                  ),
                ],
              ),
            )
          else if (_masjids.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.mosque_rounded, size: 48, color: cs.hintText),
                  const SizedBox(height: 12),
                  Text('No masjids available', style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
                ],
              ),
            )
          else
            ..._masjids.map((m) => _buildMasjidCard(m)),
        ],
      ),
    );
  }

  Widget _buildMasjidCard(Masjid masjid) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.read<PrayerProvider>();
    final isSelected = provider.selectedMasjidId == masjid.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          await provider.selectMasjid(masjid);
          if (mounted) setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? Border.all(color: AppTheme.sage.withValues(alpha: 0.4), width: 1.5) : null,
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppTheme.sage.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04),
                blurRadius: isSelected ? 12 : 6,
                offset: Offset(0, isSelected ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected
                      ? AppTheme.sage.withValues(alpha: 0.15)
                      : AppTheme.goldLight.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.mosque_rounded,
                  size: 22,
                  color: isSelected ? cs.sageDarkAccent : cs.goldAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(masjid.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    if (masjid.locationString.isNotEmpty || masjid.distanceString.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 12, color: cs.hintText),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              masjid.distanceString.isNotEmpty
                                ? '${masjid.distanceString} · ${masjid.locationString}'
                                : masjid.locationString,
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 22, color: cs.sageDarkAccent),
            ],
          ),
        ),
      ),
    );
  }
}
