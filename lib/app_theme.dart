import 'package:flutter/material.dart';

import 'domain/enums.dart';

/// The visual system locked in spec §1: deep green ground, gold accent, Anton
/// display numerals. §1 marks this unchanged from prior design work, so it is
/// not a free choice here — it is implemented as specified.
///
/// This is deliberately a single committed dark theme, not a light/dark pair.
/// A training log built around round timers and footage review reads like a
/// gym wall clock more than a document, and the spec's own language — "deep
/// green *ground*" — describes one surface, not a pair. Recorded as an
/// assumption in README.md; revisit if a light mode is ever asked for.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF0B1F16);
  static const surface = Color(0xFF123021);
  static const surfaceRaised = Color(0xFF1A3C2C);
  static const surfaceSunken = Color(0xFF081912);

  static const onBackground = Color(0xFFE7F0E6);
  static const onSurfaceMuted = Color(0xFF9BB0A2);
  static const onSurfaceFaint = Color(0xFF6C8175);

  static const gold = Color(0xFFE2BC58);
  static const goldStrong = Color(0xFFF0CE72);
  static const goldWash = Color(0xFF2A2312);

  static const line = Color(0xFF21402C);
  static const lineSoft = Color(0xFF19301F);

  /// Semantic — separate from the gold accent so a warning never reads as
  /// "the app is drawing attention to something," only "something is wrong."
  static const critical = Color(0xFFE08B76);
  static const warning = Color(0xFFE2BC58);
  static const good = Color(0xFF6FCF97);

  /// The one accent reserved for "this round is live / recording is on."
  static const liveGreen = Color(0xFF45A472);

  /// Categorical palette for the Progress tab's discipline split — fixed
  /// order, matching `Discipline.values` exactly, so filtering never
  /// repaints the disciplines that remain. Five hues spread across the
  /// wheel (gold, green, orange, blue, violet) at matched lightness/chroma
  /// rather than shades of one hue, so they stay distinguishable for
  /// colorblind readers without relying on position alone.
  static const disciplineColors = [
    gold, // bjj
    liveGreen, // boxing
    Color(0xFFD97B4F), // muayThai
    Color(0xFF5B8DBE), // mma
    Color(0xFF9575B5), // wrestling
  ];
}

/// Anton is reserved for numerals people read at a glance mid-round: the
/// round clock, the mat-time stat, big counters. Body and UI text stay on the
/// platform default (Roboto on Android) — the spec calls out numerals
/// specifically, not a full typographic system, and mixing a condensed
/// display face into paragraphs and labels would hurt legibility it was
/// never meant to carry.
class AppTextStyles {
  const AppTextStyles._();

  static const _numeralFamily = 'Anton';

  static TextStyle numeral({
    required double fontSize,
    Color color = AppColors.onBackground,
    double? height,
  }) => TextStyle(
    fontFamily: _numeralFamily,
    fontSize: fontSize,
    color: color,
    height: height,
    letterSpacing: 0.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

Color colorForDiscipline(Discipline d) => AppColors.disciplineColors[d.index];

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: Color(0xFF241B00),
      secondary: AppColors.liveGreen,
      onSecondary: Color(0xFF04140C),
      surface: AppColors.surface,
      onSurface: AppColors.onBackground,
      error: AppColors.critical,
      onError: Color(0xFF2E1A14),
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.onBackground,
      displayColor: AppColors.onBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onBackground,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.lineSoft, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceSunken,
      indicatorColor: AppColors.goldWash,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.goldStrong : AppColors.onSurfaceMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.goldStrong : AppColors.onSurfaceMuted,
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF241B00),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onBackground,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.gold,
      inactiveTrackColor: AppColors.line,
      thumbColor: AppColors.goldStrong,
      overlayColor: AppColors.gold.withValues(alpha: 0.15),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceRaised,
      selectedColor: AppColors.goldWash,
      labelStyle: const TextStyle(color: AppColors.onBackground, fontSize: 13),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
      linearTrackColor: AppColors.line,
    ),
  );
}
