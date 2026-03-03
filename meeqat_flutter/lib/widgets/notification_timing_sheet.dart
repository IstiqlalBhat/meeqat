import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a bottom sheet with dual CupertinoPicker dials for Adhan and Iqamah
/// notification timing. For Jumuah, shows a single dial.
///
/// [onChanged] fires on each dial adjustment with the key and minutes.
void showNotificationTimingSheet({
  required BuildContext context,
  required String displayName,
  required String arabicName,
  required Color accentColor,
  required int currentAdhanTiming,
  required int currentIqamahTiming,
  required void Function(String key, int minutes) onChanged,
  required String prayerName,
  bool isJumuah = false,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _NotificationTimingSheet(
      displayName: displayName,
      arabicName: arabicName,
      accentColor: accentColor,
      currentAdhanTiming: currentAdhanTiming,
      currentIqamahTiming: currentIqamahTiming,
      onChanged: onChanged,
      prayerName: prayerName,
      isJumuah: isJumuah,
    ),
  );
}

class _NotificationTimingSheet extends StatefulWidget {
  final String displayName;
  final String arabicName;
  final Color accentColor;
  final int currentAdhanTiming;
  final int currentIqamahTiming;
  final void Function(String key, int minutes) onChanged;
  final String prayerName;
  final bool isJumuah;

  const _NotificationTimingSheet({
    required this.displayName,
    required this.arabicName,
    required this.accentColor,
    required this.currentAdhanTiming,
    required this.currentIqamahTiming,
    required this.onChanged,
    required this.prayerName,
    required this.isJumuah,
  });

  @override
  State<_NotificationTimingSheet> createState() => _NotificationTimingSheetState();
}

class _NotificationTimingSheetState extends State<_NotificationTimingSheet> {
  late FixedExtentScrollController _adhanController;
  late FixedExtentScrollController _iqamahController;

  // Items: 0=Off, 1..60 = "1 min" .. "60 min"
  static const int _itemCount = 61;

  @override
  void initState() {
    super.initState();
    _adhanController = FixedExtentScrollController(initialItem: widget.currentAdhanTiming);
    _iqamahController = FixedExtentScrollController(initialItem: widget.currentIqamahTiming);
  }

  @override
  void dispose() {
    _adhanController.dispose();
    _iqamahController.dispose();
    super.dispose();
  }

  String _itemLabel(int index) {
    if (index == 0) return 'Off';
    return '$index min';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Prayer name header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.displayName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.arabicName,
                style: TextStyle(fontSize: 17, color: cs.hintText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set notification timing',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          if (widget.isJumuah) ...[
            // Single dial for Jumuah / Ramadan reminders
            _dialSection(
              label: 'Reminder before',
              controller: _iqamahController,
              onChanged: (index) {
                widget.onChanged(widget.prayerName, index);
              },
            ),
          ] else ...[
            // Dual dials for regular prayers
            _dialSection(
              label: 'Before Adhan',
              controller: _adhanController,
              onChanged: (index) {
                widget.onChanged('adhan_${widget.prayerName}', index);
              },
            ),
            const SizedBox(height: 16),
            _dialSection(
              label: 'Before Iqamah',
              controller: _iqamahController,
              onChanged: (index) {
                widget.onChanged('iqamah_${widget.prayerName}', index);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _dialSection({
    required String label,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.accentColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
          ),
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 34,
            diameterRatio: 1.2,
            squeeze: 1.0,
            selectionOverlay: Container(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: widget.accentColor.withValues(alpha: 0.25), width: 0.5),
                ),
                color: widget.accentColor.withValues(alpha: 0.06),
              ),
            ),
            onSelectedItemChanged: onChanged,
            children: List.generate(_itemCount, (index) {
              return Center(
                child: Text(
                  _itemLabel(index),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
