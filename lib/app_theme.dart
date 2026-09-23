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
  static const goldDeep = Color(0xFFC79A3A);
  static const goldWash = Color(0xFF2A2312);

  /// The third member of the palette (golden / night green / night blue):
  /// a secondary accent for elements that would otherwise compete with
  /// gold for "this is the important one" — icon chips, secondary badges,
  /// a ring track — never a CTA, gold keeps that job alone.
  static const nightBlue = Color(0xFF4E7AB5);
  static const nightBlueStrong = Color(0xFF6E97CE);
  static const nightBlueWash = Color(0xFF17233A);

  static const line = Color(0xFF21402C);
  static const lineSoft = Color(0xFF19301F);

  /// The "shiny/blingy" gold — a diagonal sweep from a bright highlight
  /// through the base gold to a deeper shade, used on primary CTAs via
  /// [GradientButton] rather than the flat single-tone Material default.
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldStrong, gold, goldDeep],
  );

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

  /// Colors for a user-added custom discipline, which has no fixed index
  /// the way [disciplineColors] does — picked deterministically from the
  /// name (see [colorForDisciplineKey]) so the same custom discipline keeps
  /// the same color across app runs without a table to persist an
  /// assignment in. Chosen to sit visually apart from [disciplineColors]
  /// rather than duplicate one of its hues.
  static const customDisciplineColors = [
    Color(0xFF4FB0A6),
    Color(0xFFC97B94),
    Color(0xFFA98B5D),
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

/// The key-based counterpart to [colorForDiscipline] — resolves a stored
/// discipline key (see `disciplineLabelForKey` in widgets/labels.dart) to a
/// color whether it's a built-in or a user-added custom discipline.
Color colorForDisciplineKey(String key) {
  for (final d in Discipline.values) {
    if (d.name == key) return AppColors.disciplineColors[d.index];
  }
  final index = key.hashCode.abs() % AppColors.customDisciplineColors.length;
  return AppColors.customDisciplineColors[index];
}

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
