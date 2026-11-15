/// Terrain trafficability classes for a suited crew member on foot.
///
/// Classification is by terrain slope from the 20 m CTX stereo DTM. The class
/// boundaries are planning thresholds chosen to line up with the break-points
/// of the Marquez (2008) walking-speed curve (6°, 15°, 20°) that the router
/// uses, so that a map colour means the same thing as a routing penalty.
///
/// Resolution limit: a 20 m DTM cannot see boulders, sand ripples or scarps
/// smaller than ~60 m. A "nominal" cell is free of *resolved* slope hazards
/// only. See docs/SCIENCE.md § Uncertainty.
enum HazardClass {
  nominal('Nominal', '< 6°', 'Level walking. Speed limited by suit, not terrain.'),
  caution('Caution', '6–10°', 'Noticeable grade. Pace falls by half or more.'),
  difficult('Difficult', '10–15°', 'Sustained climb. High metabolic cost; plan rests.'),
  severe('Severe', '15–20°', 'Scrambling pace (≈ 0.05 m/s). Avoid unless essential.'),
  noGo('No-go', '≥ 20°', 'Beyond the walking model. Fall and suit-damage risk.');

  const HazardClass(this.label, this.range, this.guidance);
  final String label;
  final String range;
  final String guidance;

  /// Upper slope bounds (deg) separating consecutive classes.
  static const List<double> edgesDeg = [6, 10, 15, 20];

  static HazardClass fromSlope(double slopeDeg) {
    final s = slopeDeg.abs();
    if (s < 6) return nominal;
    if (s < 10) return caution;
    if (s < 15) return difficult;
    if (s < 20) return severe;
    return noGo;
  }
}
