import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/masjid.dart';
import '../services/prayer_provider.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';

class MasjidScreen extends StatefulWidget {
  const MasjidScreen({super.key});

  @override
  State<MasjidScreen> createState() => _MasjidScreenState();
}

class _MasjidScreenState extends State<MasjidScreen> {
  List<Masjid> _masjids = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMasjids();
  }

  Future<void> _loadMasjids() async {
    setState(() { _isLoading = true; _error = null; });
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
    return RefreshIndicator(
      color: AppTheme.gold,
      onRefresh: _loadMasjids,
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 120),
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Masjid', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
                SizedBox(height: 4),
                Text('Choose your local masjid for accurate iqamah times', style: TextStyle(fontSize: 14, color: AppTheme.muted)),
              ],
            ),
          ),

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
                          color: AppTheme.sageDark.withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: AppTheme.sageDark, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Masjid', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppTheme.sageDark)),
                            const SizedBox(height: 2),
                            Text(provider.selectedMasjidName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
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
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.muted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(fontSize: 15, color: AppTheme.muted)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _loadMasjids,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
                  ),
                ],
              ),
            )
          else if (_masjids.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.mosque_rounded, size: 48, color: AppTheme.muted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text('No masjids available', style: TextStyle(fontSize: 15, color: AppTheme.muted)),
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
            color: Colors.white,
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
                  color: isSelected ? AppTheme.sageDark : AppTheme.gold,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(masjid.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                    if (masjid.locationString.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 12, color: AppTheme.muted.withValues(alpha: 0.5)),
                          const SizedBox(width: 3),
                          Text(masjid.locationString, style: TextStyle(fontSize: 12, color: AppTheme.muted.withValues(alpha: 0.7))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, size: 22, color: AppTheme.sageDark),
            ],
          ),
        ),
      ),
    );
  }
}
