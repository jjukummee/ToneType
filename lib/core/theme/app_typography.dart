import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const String family = 'Pretendard';

  static const display = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.8,
  );

  static const title = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.65,
  );

  static const sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.35,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSoft,
    letterSpacing: -0.2,
  );

  static const bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -0.2,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.inkFaint,
    letterSpacing: -0.1,
  );

  static const originalSpeech = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.inkFaint,
  );

  static const displayTranslation = TextStyle(
    fontFamily: family,
    fontSize: 29,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -0.65,
  );
}
