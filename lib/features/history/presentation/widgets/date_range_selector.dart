import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class DateRangeSelector extends StatelessWidget {
  final String selectedRange;
  final Function(String) onRangeSelected;

  const DateRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final ranges = [
      {'label': '1M', 'value': '1m'},
      {'label': '3M', 'value': '3m'},
      {'label': '6M', 'value': '6m'},
      {'label': 'Semua', 'value': 'all'},
    ];

    return Row(
      children: ranges.map((r) {
        final isSelected = selectedRange == r['value'];
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: InkWell(
            onTap: () => onRangeSelected(r['value']!),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.paper : AppColors.ink)
                    : (isDark ? const Color(0xFF1E293B) : AppColors.paper),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark
                            ? const Color(0xFF334155)
                            : AppColors.line),
                ),
              ),
              child: Text(
                r['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? (isDark ? AppColors.ink : AppColors.paper)
                      : (isDark
                            ? const Color(0xFF94A3B8)
                            : AppColors.muted),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

