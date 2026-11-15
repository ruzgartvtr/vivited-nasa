import 'mars_constants.dart';

/// Surface radiation exposure from MSL/RAD.
///
/// Hassler et al. (2014), Science 343, 1244797: the Radiation Assessment
/// Detector on Curiosity measured a galactic-cosmic-ray dose equivalent of
/// 0.64 ± 0.12 mSv/day and an absorbed dose of 0.210 ± 0.040 mGy/day on the
/// surface at Gale crater (Aug 2012 – Jun 2013).
///
/// Caveats applied honestly rather than "corrected":
///  * Measured at Gale (−4.4 km). Jezero's floor is ~1.9 km higher, with a
///    thinner atmospheric column; RAD shows dose rising slightly as column
///    mass falls, so this is probably a small underestimate.
///  * GCR flux varies with the solar cycle (higher near solar minimum).
///  * Solar particle events are sporadic and are NOT included.
class Radiation {
  const Radiation._();

  static const double gcrDoseEquivalentMsvPerDay = 0.64;
  static const double gcrDoseEquivalentSigma = 0.12;
  static const double gcrAbsorbedDoseMgyPerDay = 0.210;
  static const double gcrAbsorbedDoseSigma = 0.040;

  /// Dose equivalent (µSv) for [seconds] on the surface.
  static double doseEquivalentUsv(double seconds) =>
      gcrDoseEquivalentMsvPerDay * 1000.0 * seconds / 86400.0;

  /// 1-σ uncertainty (µSv) of [doseEquivalentUsv].
  static double doseEquivalentSigmaUsv(double seconds) =>
      gcrDoseEquivalentSigma * 1000.0 * seconds / 86400.0;

  /// Dose equivalent accumulated over a full sol (µSv).
  static double get perSolUsv => doseEquivalentUsv(solSeconds);
}
