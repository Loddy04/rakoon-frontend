import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

/// A reusable badge widget formatted with Shupatto design tokens
/// (3px radius, hairline 1px graphite border, periwinkle/paper color palette, uppercase tracked type).
class StatusBadge extends StatelessWidget {
  final String status;
  final IconData? icon;
  final Color? customBackgroundColor;
  final Color? customTextColor;

  const StatusBadge({
    super.key,
    required this.status,
    this.icon,
    this.customBackgroundColor,
    this.customTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final cleanStatus = status.trim().toLowerCase();

    Color backgroundColor;
    Color textColor;
    Border border = Border.all(color: AppColors.graphite, width: 1.0);

    if (customBackgroundColor != null) {
      backgroundColor = customBackgroundColor!;
      textColor = customTextColor ?? AppColors.graphite;
    } else if (cleanStatus == 'success' ||
        cleanStatus == 'verified' ||
        cleanStatus == 'terverifikasi' ||
        cleanStatus == 'tinggi' ||
        cleanStatus == 'termurah' ||
        cleanStatus == 'best value' ||
        cleanStatus == '100% full match' ||
        cleanStatus == 'stabil' ||
        cleanStatus == 'harga stabil' ||
        cleanStatus == 'harga turun' ||
        cleanStatus == 'hero' ||
        cleanStatus == 'promo' ||
        cleanStatus == 'diskon') {
      backgroundColor = AppColors.periwinkle;
      textColor = AppColors.paper;
      border = Border.all(color: AppColors.periwinkle, width: 1.0);
    } else if (cleanStatus == 'harga naik' ||
        cleanStatus == 'error' ||
        cleanStatus == 'gagal') {
      backgroundColor = AppColors.graphite;
      textColor = AppColors.paper;
    } else if (cleanStatus == 'pending' ||
        cleanStatus == 'waiting' ||
        cleanStatus == 'warning' ||
        cleanStatus == 'rendah' ||
        cleanStatus == 'tidak ditemukan toko') {
      backgroundColor = AppColors.accentSoft;
      textColor = AppColors.graphite;
    } else {
      // Default fallback
      backgroundColor = AppColors.paper;
      textColor = AppColors.graphite;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.tags),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11.0,
              color: textColor,
            ),
            const SizedBox(width: 4.0),
          ],
          Flexible(
            child: Text(
              status.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: textColor,
                fontSize: 9.0,
                letterSpacing: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
