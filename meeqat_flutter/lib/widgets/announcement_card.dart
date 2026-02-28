import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/masjid.dart';
import '../theme/app_theme.dart';

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  const AnnouncementCard({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImage = announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty;
    final hasBody = announcement.body != null && announcement.body!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.duckLight.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (hasImage)
            AspectRatio(
              aspectRatio: 2.2,
              child: CachedNetworkImage(
                imageUrl: announcement.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: cs.outline),
                errorWidget: (_, __, ___) => Container(
                  color: cs.outline,
                  child: Icon(Icons.image_not_supported_outlined, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!hasImage)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.notifications_active_rounded, size: 16, color: cs.duckDarkAccent),
                      ),
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
                if (hasBody) ...[
                  const SizedBox(height: 6),
                  Text(
                    announcement.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
