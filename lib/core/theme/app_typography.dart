import 'package:flutter/material.dart';

import 'app_colors.dart';

/// One family, a deliberate weight ladder, and negative tracking on the large
/// sizes. The contrast between a 34pt figure and a 12pt label is what gives
/// a data-heavy screen its structure — not boxes or colour.
abstract final class AppText {
  static const family = 'Nunito';

  /// The single largest number on a screen, e.g. eggs collected today.
  static const hero = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w700,
    fontSize: 44,
    height: 1.0,
    letterSpacing: -1.4,
    color: AppColors.ink,
  );

  /// Figures inside stat tiles and summary rows.
  static const metric = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w700,
    fontSize: 25,
    height: 1.1,
    letterSpacing: -0.7,
    color: AppColors.ink,
  );

  /// Screen titles.
  static const display = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.22,
    letterSpacing: -0.6,
    color: AppColors.ink,
  );

  static const title = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w700,
    fontSize: 19,
    height: 1.25,
    letterSpacing: -0.35,
    color: AppColors.ink,
  );

  static const section = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1.3,
    letterSpacing: -0.15,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w400,
    fontSize: 14.5,
    height: 1.5,
    color: AppColors.inkMuted,
  );

  static const bodyStrong = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w600,
    fontSize: 14.5,
    height: 1.4,
    color: AppColors.ink,
  );

  static const label = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 1.3,
    color: AppColors.inkMuted,
  );

  /// Small all-caps run-in above a group. Used for section headers so they
  /// read as structure rather than as content.
  static const overline = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w700,
    fontSize: 11.5,
    height: 1.2,
    letterSpacing: 0.8,
    color: AppColors.inkFaint,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    height: 1.35,
    color: AppColors.inkFaint,
  );

  static const button = TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 1.1,
    letterSpacing: -0.1,
  );
}
