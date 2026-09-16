import 'package:flutter/material.dart';

/// Neubrutalist design tokens.
///
/// The style is defined by three things, and every widget reads them from
/// here rather than hard-coding: a thick border, a hard offset shadow with no
/// blur, and flat high-saturation fills. No gradients anywhere.
@immutable
class NeuTokens extends ThemeExtension<NeuTokens> {
  const NeuTokens({
    required this.line,
    required this.shadow,
    required this.borderWidth,
    required this.shadowOffset,
    required this.radius,
    required this.yellow,
    required this.red,
    required this.blue,
    required this.green,
    required this.violet,
    required this.onAccent,
  });

  /// Border colour. Black on light, near-white on dark — a black border is
  /// invisible against a dark background, which would erase the whole style.
  final Color line;

  /// Hard shadow colour. Always matches [line] so the offset reads as a
  /// second, displaced outline rather than a glow.
  final Color shadow;

  final double borderWidth;
  final double shadowOffset;
  final double radius;

  /// Flat accent fills. Yellow, red and blue come from the palette; green and
  /// violet extend it so the five tarot suits stay distinguishable.
  final Color yellow;
  final Color red;
  final Color blue;
  final Color green;
  final Color violet;

  /// Text and icons drawn on top of an accent fill. Always the ink colour, so
  /// contrast stays high against every accent.
  final Color onAccent;

  List<BoxShadow> shadowAt([double? offset]) => <BoxShadow>[
        BoxShadow(
          color: shadow,
          offset: Offset(offset ?? shadowOffset, offset ?? shadowOffset),
          blurRadius: 0,
        ),
      ];

  Border get border => Border.all(color: line, width: borderWidth);

  BorderRadius get borderRadius => BorderRadius.circular(radius);

  @override
  NeuTokens copyWith({
    Color? line,
    Color? shadow,
    double? borderWidth,
    double? shadowOffset,
    double? radius,
    Color? yellow,
    Color? red,
    Color? blue,
    Color? green,
    Color? violet,
    Color? onAccent,
  }) {
    return NeuTokens(
      line: line ?? this.line,
      shadow: shadow ?? this.shadow,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      radius: radius ?? this.radius,
      yellow: yellow ?? this.yellow,
      red: red ?? this.red,
      blue: blue ?? this.blue,
      green: green ?? this.green,
      violet: violet ?? this.violet,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  NeuTokens lerp(ThemeExtension<NeuTokens>? other, double t) {
    if (other is! NeuTokens) {
      return this;
    }
    return NeuTokens(
      line: Color.lerp(line, other.line, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      borderWidth: borderWidth,
      shadowOffset: shadowOffset,
      radius: radius,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      red: Color.lerp(red, other.red, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      green: Color.lerp(green, other.green, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension NeuTheme on BuildContext {
  NeuTokens get neu => Theme.of(this).extension<NeuTokens>()!;
}

const Color _ink = Color(0xFF000000);
const Color _paper = Color(0xFFFFFBF0);
const Color _paperRaised = Color(0xFFFFFFFF);
const Color _night = Color(0xFF15151A);
const Color _nightRaised = Color(0xFF232330);
const Color _chalk = Color(0xFFF2F0E6);

const Color _yellow = Color(0xFFFFEB3B);
const Color _red = Color(0xFFFF5252);
const Color _blue = Color(0xFF2196F3);
const Color _green = Color(0xFF3DDC84);
const Color _violet = Color(0xFFB47CFF);

ThemeData buildTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final Color ink = dark ? _chalk : _ink;
  final Color surface = dark ? _night : _paper;
  final Color raised = dark ? _nightRaised : _paperRaised;

  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: _yellow,
    onPrimary: _ink,
    secondary: _red,
    onSecondary: _ink,
    tertiary: _blue,
    onTertiary: _ink,
    error: _red,
    onError: _ink,
    surface: surface,
    onSurface: ink,
    surfaceContainerHighest: raised,
    onSurfaceVariant: ink,
    outline: ink,
    outlineVariant: ink,
  );

  final NeuTokens tokens = NeuTokens(
    line: ink,
    shadow: ink,
    borderWidth: 3,
    shadowOffset: 4,
    radius: 8,
    yellow: _yellow,
    red: _red,
    blue: _blue,
    green: _green,
    violet: _violet,
    onAccent: _ink,
  );

  final TextTheme text = Typography.material2021(
    platform: TargetPlatform.android,
  ).black.apply(bodyColor: ink, displayColor: ink);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    extensions: <ThemeExtension<dynamic>>[tokens],
    // Flat by contract: any Material elevation would introduce a blurred
    // shadow, which the style forbids.
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    ),
    dividerTheme: DividerThemeData(color: ink, thickness: 3, space: 3),
    iconTheme: IconThemeData(color: ink, size: 22, weight: 700),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w900),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: text.titleSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
      ),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.55),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.55),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _yellow,
      contentTextStyle: const TextStyle(
        color: _ink,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ink, width: 3),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),
  );
}
