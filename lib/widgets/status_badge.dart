import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

/// A reusable badge widget to display status tags (e.g. Success, Pending)
/// formatted with the design tokens.
class StatusBadge extends StatelessWidget {
  final String status;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.status,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cleanStatus = status.trim().toLowerCase();
    
    Color backgroundColor;
    Color textColor;
    
    // Map status colors according to design tokens.
    if (cleanStatus == 'success' ||
        cleanStatus == 'verified' ||
        cleanStatus == 'terverifikasi' ||
        cleanStatus == 'tinggi' ||
        cleanStatus == 'termurah' ||
        cleanStatus == 'best value' ||
        cleanStatus == '100% full match' ||
        cleanStatus == 'stabil' ||
        cleanStatus == 'harga stabil' ||
        cleanStatus == 'harga turun') {
      backgroundColor = AppColors.accentSoft;
      textColor = AppColors.accent;
    } else if (cleanStatus == 'harga naik') {
      backgroundColor = AppColors.errorSoft;
      textColor = AppColors.error;
    } else if (cleanStatus == 'pending' ||
        cleanStatus == 'waiting' ||
        cleanStatus == 'warning' ||
        cleanStatus == 'rendah' ||
        cleanStatus == 'tidak ditemukan toko') {
      backgroundColor = AppColors.warningSoft;
      textColor = AppColors.warning;
    } else {
      // Default fallback (e.g. general info badge, belum cukup data)
      backgroundColor = AppColors.card;
      textColor = AppColors.muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12.0,
              color: textColor,
            ),
            const SizedBox(width: 4.0),
          ],
          Flexible(
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
