import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Label widget that displays price freshness / stale indicator.
/// Shows `Harga per <tanggal>` when stale is true.
/// Renders nothing (SizedBox.shrink) when stale is false.
class PriceFreshnessLabel extends StatelessWidget {
  final bool isStale;
  final dynamic updatedAt;
  final TextStyle? style;
  final bool isBadge;

  const PriceFreshnessLabel({
    super.key,
    required this.isStale,
    this.updatedAt,
    this.style,
    this.isBadge = true,
  });

  /// Formats raw DateTime or String into Indonesian readable date string.
  static String formatDate(dynamic raw) {
    if (raw == null) return '';
    if (raw is DateTime) {
      return _formatFromDateTime(raw);
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return '';
    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return _formatFromDateTime(parsed.toLocal());
    }
    return str;
  }

  static String _formatFromDateTime(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final monthStr = (dt.month >= 1 && dt.month <= 12) ? months[dt.month] : '${dt.month}';
    return '${dt.day} $monthStr ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (!isStale) {
      return const SizedBox.shrink();
    }

    final dateText = formatDate(updatedAt);
    final text = dateText.isNotEmpty ? 'Harga per $dateText' : 'Harga lama';

    if (!isBadge) {
      return Text(
        text,
        style: style ??
            GoogleFonts.outfit(
              fontSize: 10.0,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFD97706),
            ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: const Color(0xFFFDE68A),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 11.0,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 3.0),
          Text(
            text,
            style: style ??
                GoogleFonts.outfit(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF92400E),
                ),
          ),
        ],
      ),
    );
  }
}
