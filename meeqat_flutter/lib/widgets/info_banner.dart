import 'package:flutter/material.dart';

/// A tinted info/status banner with icon, text, and optional trailing action.
/// Consolidates the GPS indicator and "find nearby" banners from masjid_screen.
///
/// ```dart
/// InfoBanner(
///   icon: Icons.my_location_rounded,
///   text: 'Sorted by distance from you',
///   color: AppTheme.duck,
///   action: TextButton(onPressed: () {}, child: Text('Show all')),
/// )
/// ```
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;
  final VoidCallback? onTap;
  final double borderRadius;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.action,
    this.onTap,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          ?action,
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// A dismissable info banner with a close button.
class DismissableInfoBanner extends StatefulWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Duration animDuration;

  const DismissableInfoBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.animDuration = const Duration(milliseconds: 300),
  });

  @override
  State<DismissableInfoBanner> createState() => _DismissableInfoBannerState();
}

class _DismissableInfoBannerState extends State<DismissableInfoBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: InfoBanner(
        icon: widget.icon,
        text: widget.text,
        color: widget.color,
        action: GestureDetector(
          onTap: () => setState(() => _dismissed = true),
          child: Icon(Icons.close_rounded, size: 16, color: widget.color.withValues(alpha: 0.6)),
        ),
      ),
      secondChild: const SizedBox(width: double.infinity),
      crossFadeState: _dismissed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: widget.animDuration,
      sizeCurve: Curves.easeOut,
    );
  }
}
