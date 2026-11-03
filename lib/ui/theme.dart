import 'package:flutter/material.dart';

/// Design tokens. Widgets read colors only through [GhpColors] so the dark
/// launcher theme and the light theme stay in one place.
@immutable
class GhpColors extends ThemeExtension<GhpColors> {
  const GhpColors({
    required this.background,
    required this.surface,
    required this.raised,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.track,
    required this.diffAdd,
    required this.diffDelete,
    required this.bannerScrim,
  });

  final Color background;
  final Color surface;
  final Color raised;
  final Color border;
  final Color text;
  final Color muted;

  /// Brand blue from the logo's plus badge.
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;

  /// Empty part of gauges and goal bars.
  final Color track;
  final Color diffAdd;
  final Color diffDelete;

  /// Gradient over the banner art so text stays readable.
  final Color bannerScrim;

  static const dark = GhpColors(
    background: Color(0xFF0B0F17),
    surface: Color(0xFF121826),
    raised: Color(0xFF1A2232),
    border: Color(0xFF263044),
    text: Color(0xFFE8EDF5),
    muted: Color(0xFF8A96AB),
    accent: Color(0xFF1F7AE0),
    accentSoft: Color(0xFF173A66),
    success: Color(0xFF3FB950),
    warning: Color(0xFFE3A21A),
    danger: Color(0xFFF2554B),
    track: Color(0xFF222B3B),
    diffAdd: Color(0xFF12351F),
    diffDelete: Color(0xFF3D1618),
    bannerScrim: Color(0xE60B0F17),
  );

  static const light = GhpColors(
    background: Color(0xFFF3F6FB),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF7F9FC),
    border: Color(0xFFD5DCE6),
    text: Color(0xFF151B26),
    muted: Color(0xFF5B6678),
    accent: Color(0xFF1F7AE0),
    accentSoft: Color(0xFFDCEAFB),
    success: Color(0xFF1A7F37),
    warning: Color(0xFF9A6700),
    danger: Color(0xFFCF222E),
    track: Color(0xFFE3E8F0),
    diffAdd: Color(0xFFE6FFEC),
    diffDelete: Color(0xFFFFEBE9),
    bannerScrim: Color(0xE6F3F6FB),
  );

  @override
  GhpColors copyWith() => this;

  @override
  GhpColors lerp(ThemeExtension<GhpColors>? other, double t) {
    if (other is! GhpColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return GhpColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      border: l(border, other.border),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      track: l(track, other.track),
      diffAdd: l(diffAdd, other.diffAdd),
      diffDelete: l(diffDelete, other.diffDelete),
      bannerScrim: l(bannerScrim, other.bannerScrim),
    );
  }
}

/// Spacing scale (px).
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
}

/// Short, purposeful motion. Everything is skipped when animations are reduced.
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 260);
  static const reward = Duration(milliseconds: 380);
  static const curve = Curves.easeOutCubic;
}

extension GhpThemeContext on BuildContext {
  GhpColors get colors => Theme.of(this).extension<GhpColors>()!;

  /// True when the OS or the app setting asks for less motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? GhpColors.dark : GhpColors.light;
  const font = 'Pretendard';
  const fallback = ['Malgun Gothic', 'Segoe UI'];
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: font,
    fontFamilyFallback: fallback,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      primary: c.accent,
      surface: c.surface,
      error: c.danger,
    ),
    scaffoldBackgroundColor: c.background,
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.raised, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(Radii.sm)),
      textStyle: TextStyle(color: c.text, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: c.raised,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm + 2),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: c.accent, width: 1.5)),
      hintStyle: TextStyle(color: c.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: c.border)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.border),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
    ),
  );
}
