import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

void main() {
  test('token warna mengikuti home_screen (UI_RULES)', () {
    expect(AppColors.graphite, const Color(0xFF0D2818));
    expect(AppColors.ink, const Color(0xFF0D2818));
    expect(AppColors.background, const Color(0xFFFAF7F2));
    expect(AppColors.line, const Color(0xFFE8E4DC));
    expect(AppColors.fog, const Color(0xFF6B6B6B));
    expect(AppColors.muted, const Color(0xFF6B6B6B));
  });

  test('radius 12/16/24 dan pill 100', () {
    expect([AppRadius.buttons, AppRadius.tags, AppRadius.m], everyElement(12.0));
    expect([AppRadius.cards, AppRadius.l], everyElement(16.0));
    expect(AppRadius.xl, 24.0);
    expect(AppRadius.full, 100.0);
  });

  testWidgets('teks: tracking normal, ukuran judul seksi/hero/kartu', (tester) async {
    for (final style in [
      AppTextStyles.headingLg,
      AppTextStyles.headingSm,
      AppTextStyles.body,
      AppTextStyles.bodyLarge,
      AppTextStyles.buttonLabel,
      AppTextStyles.caption,
    ]) {
      expect(style.letterSpacing, isNull);
    }
    expect(AppTextStyles.headingSm.fontSize, inInclusiveRange(16, 18));
    expect(AppTextStyles.headingLg.fontSize, inInclusiveRange(20, 22));
    expect(AppTextStyles.bodyLarge.fontSize, 13);
  });

  testWidgets('tema memakai latar FAF7F2', (tester) async {
    expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFFAF7F2));
  });
}
