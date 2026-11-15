import 'package:material_ui/material_ui.dart';

import '../science/hazard.dart';

/// Vivited visual language: a printed survey atlas read under mission-control
/// lighting. Warm basalt blacks, bone paper text, one oxide signal colour,
/// hairline rules instead of cards, no gradients, no glow.
class VColors {
  const VColors._();

  static const ink = Color(0xFF0C0B0A); // page
  static const basalt = Color(0xFF141211); // panels
  static const raised = Color(0xFF1C1917); // hover / inset
  static const rule = Color(0xFF2B2622); // hairlines
  static const ruleStrong = Color(0xFF453E37);

  static const bone = Color(0xFFEFE8DC); // primary text
  static const dust = Color(0xFFA59B8E); // secondary text
  static const ash = Color(0xFF6E665C); // tertiary text

  static const oxide = Color(0xFFFF5A1F); // the signal colour
  static const oxideDim = Color(0xFF7A3015);
  static const ice = Color(0xFF8CC7E8); // science / water / cold
  static const lichen = Color(0xFF9FD3B0); // nominal / go
  static const sulfur = Color(0xFFE9C46A); // caution
  static const ember = Color(0xFFF08A3C); // difficult
  static const alarm = Color(0xFFE5482F); // severe / fail
  static const void_ = Color(0xFF6B1525); // no-go

  static Color hazard(HazardClass h) => switch (h) {
        HazardClass.nominal => lichen,
        HazardClass.caution => sulfur,
        HazardClass.difficult => ember,
        HazardClass.severe => alarm,
        HazardClass.noGo => void_,
      };
}

/// Type system: Instrument Serif for display numerals and titles, Schibsted
/// Grotesk for interface text, IBM Plex Mono for data and labels.
class VType {
  const VType._();

  static const serif = 'InstrumentSerif';
  static const sans = 'SchibstedGrotesk';
  static const mono = 'IBMPlexMono';

  static TextStyle display(double size, {Color color = VColors.bone, bool italic = false}) =>
      TextStyle(
        fontFamily: serif,
        fontSize: size,
        height: 1.0,
        letterSpacing: -size * 0.012,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  static TextStyle body(double size, {Color color = VColors.bone, double weight = 400, double height = 1.45}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        height: height,
        color: color,
        fontVariations: [FontVariation('wght', weight)],
      );

  static TextStyle data(double size, {Color color = VColors.bone, bool medium = false, double spacing = 0}) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        height: 1.3,
        color: color,
        letterSpacing: spacing,
        fontWeight: medium ? FontWeight.w500 : FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Small tracked uppercase label.
  static TextStyle label({Color color = VColors.dust, double size = 10}) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        height: 1.2,
        color: color,
        letterSpacing: size * 0.14,
        fontWeight: FontWeight.w500,
      );
}

ThemeData buildVivitedTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: VType.sans,
    scaffoldBackgroundColor: VColors.ink,
    colorScheme: const ColorScheme.dark(
      primary: VColors.oxide,
      onPrimary: VColors.ink,
      secondary: VColors.ice,
      surface: VColors.basalt,
      onSurface: VColors.bone,
      error: VColors.alarm,
      outline: VColors.rule,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: VColors.raised,
    dividerColor: VColors.rule,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: VType.sans,
      bodyColor: VColors.bone,
      displayColor: VColors.bone,
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 1.5,
      activeTrackColor: VColors.oxide,
      inactiveTrackColor: VColors.ruleStrong,
      thumbColor: VColors.bone,
      overlayColor: Color(0x22FF5A1F),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5, elevation: 0, pressedElevation: 0),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      trackShape: RectangularSliderTrackShape(),
      showValueIndicator: ShowValueIndicator.never,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: VColors.bone,
        borderRadius: BorderRadius.circular(2),
      ),
      textStyle: VType.data(11, color: VColors.ink),
      waitDuration: const Duration(milliseconds: 400),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(3),
      radius: Radius.zero,
      thumbColor: WidgetStateProperty.all(VColors.ruleStrong),
    ),
  );
}
