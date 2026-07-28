/// App theme, taken directly from the Claude Design prototype.
///
/// Deliberately flat: colours and sizes live as literal values here and in the
/// widgets that use them, the same way the prototype expresses them. There is
/// no token/ThemeExtension indirection layer.
///
/// Everything here is plain Material — no Cupertino widgets and no iOS-only
/// chrome — so the same UI renders on iOS and Android.
library;

import 'package:flutter/material.dart';

import 'palette.dart';

/// Variable-font weight axis. Newsreader and IBM Plex Sans ship as variable
/// TTFs, so a bare [FontWeight] would not instantiate the axis.
List<FontVariation> wght(double w) => [FontVariation('wght', w)];

/// The persisted appearance preference.
const kAppearanceSettingKey = 'app.appearance';

/// System / Light / Dark, as the design's three-up control offers them.
enum AppearanceMode { system, light, dark }

AppearanceMode appearanceFromName(String? name) => AppearanceMode.values
    .firstWhere((m) => m.name == name, orElse: () => AppearanceMode.system);

ThemeMode themeModeFor(AppearanceMode mode) => switch (mode) {
  AppearanceMode.system => ThemeMode.system,
  AppearanceMode.light => ThemeMode.light,
  AppearanceMode.dark => ThemeMode.dark,
};

/// Series monogram tile colours (background, foreground), cycled by index so a
/// series keeps the same tile colour wherever it appears.
const monogramPairs = <(Color, Color)>[
  (Color(0xFFDDE7EA), Color(0xFF254E5C)),
  (Color(0xFFE6E3DA), Color(0xFF4E4A3F)),
  (Color(0xFFEDE1DA), Color(0xFF5C4034)),
  (Color(0xFFDEE6E0), Color(0xFF37503F)),
  (Color(0xFFE9E1E8), Color(0xFF4E3B4C)),
];

(Color, Color) monogramFor(String id) =>
    monogramPairs[id.hashCode.abs() % monogramPairs.length];

/// Two-letter monogram for a title, matching the prototype's tiles.
String monogramText(String title) {
  final words = title
      .split(RegExp(r'[\s:\-–—_]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '??';
  if (words.length == 1) {
    final w = words.first;
    return (w.length == 1 ? w : w.substring(0, 2)).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

/// The dark appearance. Derived from [AppPalette.dark]; see the note there
/// about the design artifact shipping no dark variant (D56).
ThemeData appDarkTheme() => appTheme(palette: AppPalette.dark);

/// Built from [palette] so the [ColorScheme] and the extension can never
/// disagree — the two would drift within a week if they were written out
/// twice.
ThemeData appTheme({AppPalette palette = AppPalette.light}) {
  final dark = palette.isDark;
  final scheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: dark ? const Color(0xFF10222A) : Colors.white,
    primaryContainer: palette.primaryContainer,
    onPrimaryContainer: palette.onPrimaryContainer,
    secondary: palette.inkMuted,
    onSecondary: dark ? const Color(0xFF171614) : Colors.white,
    secondaryContainer: palette.surfaceHigh,
    onSecondaryContainer: palette.inkStrong,
    tertiary: palette.warn,
    onTertiary: dark ? const Color(0xFF241A08) : Colors.white,
    tertiaryContainer: palette.warnContainer,
    onTertiaryContainer: palette.onWarnContainer,
    error: palette.danger,
    onError: dark ? const Color(0xFF2A0E0A) : Colors.white,
    errorContainer: palette.dangerContainer,
    onErrorContainer: palette.onDangerContainer,
    surface: palette.surface,
    onSurface: palette.ink,
    surfaceContainerLowest: dark
        ? const Color(0xFF121110)
        : const Color(0xFFFCFBF9),
    surfaceContainerLow: dark
        ? const Color(0xFF1A1917)
        : const Color(0xFFF8F6F3),
    surfaceContainer: palette.surfaceMuted,
    surfaceContainerHigh: palette.surfaceHigh,
    surfaceContainerHighest: palette.divider,
    onSurfaceVariant: palette.inkMuted,
    outline: palette.borderStrong,
    outlineVariant: palette.border,
    shadow: Colors.black,
    scrim: palette.scrim,
    inverseSurface: dark ? const Color(0xFFF2EFE9) : const Color(0xFF1B1A18),
    onInverseSurface: dark ? const Color(0xFF1B1A18) : const Color(0xFFFBFAF8),
    inversePrimary: const Color(0xFF9FC3CE),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: scheme,
    fontFamily: 'IBM Plex Sans',
    scaffoldBackgroundColor: scheme.surface,
    extensions: [palette],
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamily: 'IBM Plex Sans',
    ),
    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: palette.inkStrong,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 15,
        fontVariations: wght(600),
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: TextStyle(
          fontFamily: 'IBM Plex Sans',
          fontSize: 14,
          fontVariations: wght(600),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.inkStrong,
        side: BorderSide(color: scheme.outline),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        textStyle: TextStyle(
          fontFamily: 'IBM Plex Sans',
          fontSize: 14,
          fontVariations: wght(500),
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: TextStyle(
          fontFamily: 'IBM Plex Sans',
          fontSize: 13,
          fontVariations: wght(500),
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 13,
        color: scheme.onInverseSurface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.inkMuted,
      textColor: palette.ink,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: palette.border,
    ),
  );
}
