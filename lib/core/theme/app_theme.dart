import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Three radii only. Control sized (buttons, fields, chips), card sized, and
/// sheet sized. Mixing more than that is what makes a layout feel unplanned.
abstract final class AppRadius {
  static const small = Radius.circular(12);
  static const medium = Radius.circular(18);
  static const large = Radius.circular(26);

  static const brSmall = BorderRadius.all(small);
  static const brMedium = BorderRadius.all(medium);
  static const brLarge = BorderRadius.all(large);
}

/// A 4pt spacing scale. Every gap in the app is one of these values.
abstract final class AppGap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const xl = 32.0;

  /// Horizontal page margin, shared by every scrollable screen.
  static const page = 16.0;
}

/// Two levels of depth: resting cards and things that float above them.
/// Both are soft and neutral, tinted slightly green so shadows sit in the
/// same colour family as the rest of the interface.
/// Shadows are tinted brown rather than grey so they sit inside the warm
/// palette instead of greying the cream out from underneath.
abstract final class AppShadow {
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F3D2E14),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x143D2E14),
      blurRadius: 12,
      offset: Offset(0, 5),
    ),
  ];

  static const floating = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A3D2E14),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: Color(0x243D2E14),
      blurRadius: 26,
      offset: Offset(0, 14),
    ),
  ];

  /// Green glow under the primary button and the menu anchor.
  static const accent = <BoxShadow>[
    BoxShadow(
      color: Color(0x4D1B5C46),
      blurRadius: 16,
      offset: Offset(0, 7),
    ),
  ];

  static const gold = <BoxShadow>[
    BoxShadow(
      color: Color(0x4DB77A11),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];

  // Older screens still reference these names.
  static const soft = card;
  static const lifted = floating;
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.forest,
    onPrimary: AppColors.onAccent,
    primaryContainer: AppColors.accentSoft,
    onPrimaryContainer: AppColors.accentInk,
    secondary: AppColors.gold,
    onSecondary: AppColors.ink,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.surfaceAlt,
    outlineVariant: AppColors.line,
    error: AppColors.danger,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: AppText.family,
    splashFactory: InkRipple.splashFactory,
    // Override Material3's default focus/hover/pressed overlays so they use
    // the app's warm ink colour instead of the system blue.
    focusColor: AppColors.accentSoft.withValues(alpha: 0.25),
    hoverColor: AppColors.accentSoft.withValues(alpha: 0.12),
    highlightColor: AppColors.accentSoft.withValues(alpha: 0.18),
    splashColor: AppColors.accentSoft.withValues(alpha: 0.28),
    textTheme: const TextTheme(
      displaySmall: AppText.display,
      titleLarge: AppText.title,
      titleMedium: AppText.section,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      labelLarge: AppText.label,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.bodyStrong.copyWith(color: Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSmall),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.lineStrong,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brMedium),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.inkFaint,
      textColor: AppColors.ink,
    ),
  );
}
