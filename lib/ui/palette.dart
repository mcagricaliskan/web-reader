/// Named surfaces and inks, so a screen can be drawn once and rendered in
/// either appearance.
///
/// This is a deliberate, narrow amendment to D28 ("flat theme, no token
/// layer"). That decision was right while there was one appearance: a literal
/// `Color(0xFFF5F3EF)` said exactly what the design said. A second appearance
/// makes a literal a lie — the same value cannot be "the quiet surface" in
/// both. The names here are the *roles* the design already uses, nothing
/// more: no scale, no elevation system, no component tokens.
///
/// The light values are the prototype's, unchanged. The dark values are
/// derived from them — same hue relationships, inverted lightness — and are
/// marked as such because the design artifact ships no dark variant (D56).
library;

import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceInset,
    required this.surfaceHigh,
    required this.divider,
    required this.hairline,
    required this.border,
    required this.borderInset,
    required this.borderStrong,
    required this.ink,
    required this.inkStrong,
    required this.inkMuted,
    required this.inkFaint,
    required this.inkGhost,
    required this.inkDisabled,
    required this.primary,
    required this.primaryContainer,
    required this.primaryBorder,
    required this.onPrimaryContainer,
    required this.warn,
    required this.warnContainer,
    required this.warnBorder,
    required this.onWarnContainer,
    required this.danger,
    required this.dangerContainer,
    required this.dangerBorder,
    required this.onDangerContainer,
    required this.scrim,
    required this.toastSurface,
    required this.toastInk,
    required this.toastAccent,
  });

  final Brightness brightness;

  /// The page itself.
  final Color surface;

  /// A quiet block on the page (tiles, inset cards).
  final Color surfaceMuted;

  /// A field or pill sunk into the page (the address bar, search fields).
  final Color surfaceInset;

  /// A slightly raised neutral block (banners, chips).
  final Color surfaceHigh;

  /// Section separator.
  final Color divider;

  /// Row separator inside a list — lighter than [divider].
  final Color hairline;

  final Color border;
  final Color borderInset;
  final Color borderStrong;

  /// Body text.
  final Color ink;

  /// Titles and header glyphs.
  final Color inkStrong;

  /// Secondary text.
  final Color inkMuted;

  /// Tertiary text (metadata).
  final Color inkFaint;

  /// Quaternary text (timestamps).
  final Color inkGhost;

  /// A disabled control.
  final Color inkDisabled;

  final Color primary;
  final Color primaryContainer;
  final Color primaryBorder;
  final Color onPrimaryContainer;

  final Color warn;
  final Color warnContainer;
  final Color warnBorder;
  final Color onWarnContainer;

  final Color danger;
  final Color dangerContainer;
  final Color dangerBorder;
  final Color onDangerContainer;

  /// Behind a modal.
  final Color scrim;

  final Color toastSurface;
  final Color toastInk;
  final Color toastAccent;

  bool get isDark => brightness == Brightness.dark;

  /// The palette for the current theme. Falls back to [light] so a widget
  /// tested with a bare `MaterialApp` still renders.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  /// Straight from the Claude Design prototype.
  static const light = AppPalette(
    brightness: Brightness.light,
    surface: Color(0xFFFBFAF8),
    surfaceMuted: Color(0xFFF5F3EF),
    surfaceInset: Color(0xFFF1EEE9),
    surfaceHigh: Color(0xFFF3F1ED),
    divider: Color(0xFFEFECE7),
    hairline: Color(0xFFF3F1ED),
    border: Color(0xFFE7E3DC),
    borderInset: Color(0xFFE4E0D8),
    borderStrong: Color(0xFFC9C3B9),
    ink: Color(0xFF1B1A18),
    inkStrong: Color(0xFF3E3A34),
    inkMuted: Color(0xFF5F5B54),
    inkFaint: Color(0xFF8C877E),
    inkGhost: Color(0xFFA39D93),
    inkDisabled: Color(0xFFC4BFB5),
    primary: Color(0xFF35606F),
    primaryContainer: Color(0xFFEAF1F4),
    primaryBorder: Color(0xFFD2E2E8),
    onPrimaryContainer: Color(0xFF133845),
    warn: Color(0xFF8A5A1F),
    warnContainer: Color(0xFFF8EEDA),
    warnBorder: Color(0xFFE8D5B2),
    onWarnContainer: Color(0xFF4A2F08),
    danger: Color(0xFF8E3B31),
    dangerContainer: Color(0xFFF7DDD8),
    dangerBorder: Color(0xFFEBC4BC),
    onDangerContainer: Color(0xFF4A140E),
    scrim: Color(0x8014120F),
    toastSurface: Color(0xFF201F1C),
    toastInk: Color(0xFFF2EFE9),
    toastAccent: Color(0xFF9FC3CE),
  );

  /// Derived, not designed. The warm neutral of the light theme is kept —
  /// these are brown-greys, not blue-greys — and the accents are lifted
  /// enough to clear 4.5:1 on the dark surfaces.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    surface: Color(0xFF161513),
    surfaceMuted: Color(0xFF1E1D1A),
    surfaceInset: Color(0xFF232220),
    surfaceHigh: Color(0xFF262421),
    divider: Color(0xFF2C2A27),
    hairline: Color(0xFF262421),
    border: Color(0xFF322F2B),
    borderInset: Color(0xFF3A3733),
    borderStrong: Color(0xFF4C4842),
    ink: Color(0xFFF2EFE9),
    inkStrong: Color(0xFFDBD7CF),
    inkMuted: Color(0xFFA8A298),
    inkFaint: Color(0xFF8B857B),
    inkGhost: Color(0xFF757067),
    inkDisabled: Color(0xFF565149),
    primary: Color(0xFF7FB3C4),
    primaryContainer: Color(0xFF1D3640),
    primaryBorder: Color(0xFF2E5261),
    onPrimaryContainer: Color(0xFFCBE3EB),
    warn: Color(0xFFD9A45C),
    warnContainer: Color(0xFF3A2C14),
    warnBorder: Color(0xFF5A441F),
    onWarnContainer: Color(0xFFF3DFBC),
    danger: Color(0xFFD98A7C),
    dangerContainer: Color(0xFF3D1D18),
    dangerBorder: Color(0xFF5E2E27),
    onDangerContainer: Color(0xFFF5D3CC),
    scrim: Color(0xB3000000),
    toastSurface: Color(0xFF2C2A27),
    toastInk: Color(0xFFF2EFE9),
    toastAccent: Color(0xFF9FC3CE),
  );

  @override
  AppPalette copyWith({Brightness? brightness}) =>
      brightness == null || brightness == this.brightness
      ? this
      : (brightness == Brightness.dark ? dark : light);

  /// Snaps at the midpoint rather than interpolating.
  ///
  /// A cross-fade through the middle of these two palettes produces a muddy
  /// grey that belongs to neither, and the theme switch is a preference
  /// change — not an animation anyone is watching frame by frame.
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

/// The favicon fallback tiles, straight from the prototype's `FV` table.
const faviconPairsLight = <(Color, Color)>[
  (Color(0xFFDDE7EA), Color(0xFF254E5C)),
  (Color(0xFFE6E3DA), Color(0xFF4E4A3F)),
  (Color(0xFFEDE1DA), Color(0xFF5C4034)),
  (Color(0xFFDEE6E0), Color(0xFF37503F)),
  (Color(0xFFE9E1E8), Color(0xFF4E3B4C)),
  (Color(0xFFE4E7EC), Color(0xFF3B4351)),
];

/// The same six hues, inverted for the dark appearance.
const faviconPairsDark = <(Color, Color)>[
  (Color(0xFF23383F), Color(0xFFAFCFD9)),
  (Color(0xFF33302A), Color(0xFFCFC9BA)),
  (Color(0xFF3A2A22), Color(0xFFD9BCAC)),
  (Color(0xFF243329), Color(0xFFB2CDBB)),
  (Color(0xFF33272F), Color(0xFFCFB6C9)),
  (Color(0xFF262A31), Color(0xFFB6BECC)),
];

/// Stable per-host tile colours: the same site keeps the same tile wherever
/// it appears. Mirrors the prototype's `fav()` hash exactly so a screenshot
/// of the design and a screenshot of the app agree.
(Color, Color) faviconColorsFor(String host, {required bool dark}) {
  var h = 0;
  for (final unit in host.codeUnits) {
    h = (h * 31 + unit) & 0xFFFFFFFF;
  }
  final pairs = dark ? faviconPairsDark : faviconPairsLight;
  return pairs[h % pairs.length];
}
