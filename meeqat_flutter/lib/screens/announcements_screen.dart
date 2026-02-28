import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/prayer_provider.dart';
import '../models/masjid.dart';
import '../theme/app_theme.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, _) {
        if (!provider.hasMasjid) {
          return _buildEmpty(
            icon: Icons.mosque_rounded,
            title: 'Select a Masjid',
            subtitle: 'Choose your masjid to see announcements and updates.',
          );
        }

        if (provider.isLoading && provider.announcements.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.gold),
          );
        }

        if (provider.announcements.isEmpty) {
          return _buildEmpty(
            icon: Icons.campaign_rounded,
            title: 'No Announcements',
            subtitle: 'Your masjid hasn\'t posted any announcements yet.',
          );
        }

        return RefreshIndicator(
          color: AppTheme.gold,
          onRefresh: provider.loadTimes,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.campaign_rounded, size: 20, color: AppTheme.gold),
                          const SizedBox(width: 8),
                          const Text(
                            'Announcements',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.charcoal),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${provider.announcements.length}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.gold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.selectedMasjidName,
                        style: TextStyle(fontSize: 13, color: AppTheme.muted.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ),

              // Featured announcement (first with image)
              ..._buildFeatured(context, provider.announcements),

              // Rest of announcements
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final startIndex = _hasFeatured(provider.announcements) ? 1 : 0;
                      final ann = provider.announcements[startIndex + index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AnnouncementTile(announcement: ann),
                      );
                    },
                    childCount: _remainingCount(provider.announcements),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasFeatured(List<Announcement> list) =>
      list.isNotEmpty && list.first.imageUrl != null;

  int _remainingCount(List<Announcement> list) {
    if (list.isEmpty) return 0;
    return _hasFeatured(list) ? list.length - 1 : list.length;
  }

  List<Widget> _buildFeatured(BuildContext context, List<Announcement> announcements) {
    if (!_hasFeatured(announcements)) return [];
    final featured = announcements.first;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: GestureDetector(
            onTap: () => _openDetail(context, featured),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero image
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: featured.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.creamDark,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.gold,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.creamDark,
                        child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.muted, size: 32),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LATEST',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppTheme.gold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              featured.formattedDate,
                              style: TextStyle(fontSize: 11, color: AppTheme.muted.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          featured.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.charcoal, height: 1.3),
                        ),
                        if (featured.body != null && featured.body!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            featured.body!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: AppTheme.muted.withValues(alpha: 0.8), height: 1.5),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Read more',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.duckDark),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.duckDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  void _openDetail(BuildContext context, Announcement announcement) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AnnouncementDetailPage(announcement: announcement),
      ),
    );
  }

  Widget _buildEmpty({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.gold.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 36, color: AppTheme.gold),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.muted.withValues(alpha: 0.7), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Announcement Tile (list item without hero image) ────────

class _AnnouncementTile extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementTile({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final hasImage = announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AnnouncementDetailPage(announcement: announcement),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.creamDark),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Thumbnail
            if (hasImage)
              SizedBox(
                width: 100,
                height: 100,
                child: CachedNetworkImage(
                  imageUrl: announcement.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppTheme.creamDark),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.creamDark,
                    child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.muted, size: 20),
                  ),
                ),
              ),
            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.charcoal, height: 1.3),
                    ),
                    if (announcement.body != null && announcement.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        announcement.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.muted.withValues(alpha: 0.7), height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      announcement.formattedDate,
                      style: TextStyle(fontSize: 11, color: AppTheme.muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.muted.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-screen Announcement Detail ─────────────────────────

class _AnnouncementDetailPage extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementDetailPage({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final hasImage = announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: CustomScrollView(
        slivers: [
          // Collapsing image header
          if (hasImage)
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: AppTheme.cream,
              leading: _backButton(context),
              flexibleSpace: FlexibleSpaceBar(
                background: GestureDetector(
                  onTap: () => _openFullImage(context, announcement.imageUrl!),
                  child: CachedNetworkImage(
                    imageUrl: announcement.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.creamDark),
                    errorWidget: (_, __, ___) => Container(color: AppTheme.creamDark),
                  ),
                ),
              ),
            )
          else
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.cream,
              leading: _backButton(context),
              title: const Text('Announcement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: hasImage
                  ? const BoxDecoration(
                      color: AppTheme.cream,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    )
                  : null,
              transform: hasImage ? Matrix4.translationValues(0, -24, 0) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    if (announcement.formattedDate.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.muted.withValues(alpha: 0.5)),
                            const SizedBox(width: 6),
                            Text(
                              announcement.formattedDate,
                              style: TextStyle(fontSize: 13, color: AppTheme.muted.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                    // Title
                    Text(
                      announcement.title,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.charcoal, height: 1.3),
                    ),

                    // Divider
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      height: 1,
                      color: AppTheme.creamDark,
                    ),

                    // Body
                    if (announcement.body != null && announcement.body!.isNotEmpty)
                      Text(
                        announcement.body!,
                        style: TextStyle(fontSize: 16, color: AppTheme.muted.withValues(alpha: 0.85), height: 1.7),
                      )
                    else
                      Text(
                        'No additional details.',
                        style: TextStyle(fontSize: 15, color: AppTheme.muted.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppTheme.charcoal),
      ),
    );
  }

  void _openFullImage(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _FullImageView(imageUrl: url),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ─── Full-screen image viewer with pinch-to-zoom ─────────────

class _FullImageView extends StatelessWidget {
  final String imageUrl;
  const _FullImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
