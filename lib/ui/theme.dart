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

/// Variable-font weight axis. Newsreader and IBM Plex Sans ship as variable
/// TTFs, so a bare [FontWeight] would not instantiate the axis.
List<FontVariation> wght(double w) => [FontVariation('wght', w)];

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

ThemeData appTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF35606F),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFEAF1F4),
    onPrimaryContainer: Color(0xFF133845),
    secondary: Color(0xFF5F5B54),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF3F1ED),
    onSecondaryContainer: Color(0xFF3E3A34),
    tertiary: Color(0xFF8A5A1F),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFF8EEDA),
    onTertiaryContainer: Color(0xFF4A2F08),
    error: Color(0xFF8E3B31),
    onError: Colors.white,
    errorContainer: Color(0xFFF7DDD8),
    onErrorContainer: Color(0xFF4A140E),
    surface: Color(0xFFFBFAF8),
    onSurface: Color(0xFF1B1A18),
    surfaceContainerLowest: Color(0xFFFCFBF9),
    surfaceContainerLow: Color(0xFFF8F6F3),
    surfaceContainer: Color(0xFFF5F3EF),
    surfaceContainerHigh: Color(0xFFF3F1ED),
    surfaceContainerHighest: Color(0xFFEFECE7),
    onSurfaceVariant: Color(0xFF5F5B54),
    outline: Color(0xFFC9C3B9),
    outlineVariant: Color(0xFFE7E3DC),
    shadow: Colors.black,
    scrim: Color(0x8C14120F),
    inverseSurface: Color(0xFF1B1A18),
    onInverseSurface: Color(0xFFFBFAF8),
    inversePrimary: Color(0xFF9FC3CE),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'IBM Plex Sans',
    scaffoldBackgroundColor: scheme.surface,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamily: 'IBM Plex Sans',
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFEFECE7),
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: const Color(0xFF3E3A34),
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
        foregroundColor: const Color(0xFF3E3A34),
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
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF5F5B54),
      textColor: Color(0xFF1B1A18),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: const Color(0xFFE1DDD5),
    ),
  );
}
