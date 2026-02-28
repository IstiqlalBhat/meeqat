import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'islamic_pattern.dart';

/// A beautiful empty-state placeholder with icon, title, subtitle,
/// and optional call-to-action button.
///
/// Unifies the empty state pattern used across prayer_screen,
/// masjid_screen, and other screens.
///
/// ```dart
/// EmptyState(
///   icon: Icons.mosque_rounded,
///   title: 'Assalamu Alaikum',
///   subtitle: 'Select your local masjid to see prayer times',
///   actionLabel: 'Find a Masjid',
///   actionIcon: Icons.mosque_rounded,
///   onAction: () => navigateToMasjid(),
/// )
/// ```
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color? accentColor;
  final Color? accentLightColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.accentColor,
    this.accentLightColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.goldAccent;
    final accentLight = accentLightColor ?? AppTheme.goldLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with decorative ring
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer decorative ring
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentLight.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                // Inner filled circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentLight.withValues(alpha: 0.2),
                  ),
                  child: Icon(icon, size: 32, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // Ornament
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IslamicStar(size: 10, color: accent.withValues(alpha: 0.3), strokeWidth: 0.7),
                const SizedBox(width: 6),
                Container(width: 24, height: 0.5, color: accent.withValues(alpha: 0.2)),
                const SizedBox(width: 6),
                IslamicStar(size: 10, color: accent.withValues(alpha: 0.3), strokeWidth: 0.7),
              ],
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            // CTA Button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentLight, accent, accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (actionIcon != null) ...[
                        Icon(actionIcon, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact error state with icon, message, and retry button.
/// Unifies error handling across screens.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  final String retryLabel;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.outline.withValues(alpha: 0.5),
              ),
              child: Icon(icon, size: 28, color: cs.hintText),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(retryLabel),
              style: TextButton.styleFrom(foregroundColor: cs.goldAccent),
            ),
          ],
        ),
      ),
    );
  }
}
