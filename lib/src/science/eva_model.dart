import 'dart:math' as math;

import 'mars_constants.dart';

/// Suited-walking performance model.
///
/// * Speed vs. slope: Marquez (2008), MIT PhD thesis "Human-automation
///   collaboration: decision support for lunar and planetary exploration",
///   fitted to Apollo traverse data — as used by the SEXTANT EVA planner
///   (Johnson et al. 2010) and its open-source successor `pextant`
///   (Norheim et al. 2018).
/// * Metabolic rate: Santee et al. (2001), "A proposed model for load carriage
///   on sloped terrain", Aviat. Space Environ. Med. 72, 562 — with the slope
///   term scaled by local gravity, again as in SEXTANT.
///
/// These are the best published planning models, but they were derived from
/// Apollo lunar EVAs and terrestrial load-carriage trials. No human has
/// walked on Mars: treat outputs as planning estimates (see docs/SCIENCE.md).
class EvaModel {
  const EvaModel({
    this.crewMassKg = 80,
    this.suitMassKg = 100,
    this.paceFactor = 0.75,
    this.gravity = marsGravity,
    this.stationWorkW = 250,
  }) : assert(paceFactor > 0 && paceFactor <= 1);

  /// Astronaut body mass (kg).
  final double crewMassKg;

  /// Suit + life-support + tools mass (kg). Planning assumption.
  final double suitMassKg;

  /// Planning derate applied to the Marquez speed curve (1 = Apollo-derived
  /// nominal). Default 0.75 is a Vivited planning margin, not a measurement.
  final double paceFactor;

  final double gravity;

  /// Metabolic rate while working at a science station (W). Assumption, in
  /// the range of Apollo surface EVA averages (≈ 230–300 W).
  final double stationWorkW;

  double get totalMassKg => crewMassKg + suitMassKg;

  /// Steepest slope (deg) the Marquez curve treats as walkable terrain.
  static const double modelSlopeLimitDeg = 20.0;

  /// Nominal Marquez (2008) walking speed in m/s for a slope in degrees
  /// (positive = uphill), before the pace derate.
  static double marquezSpeed(double slopeDeg) {
    final s = slopeDeg;
    if (s > 15) return 0.05;
    if (s > 6) return -0.039 * s + 0.634;
    if (s > 0) return -0.2 * s + 1.6;
    if (s > -10) return 0.06 * s + 1.6;
    if (s > -20) return 0.095 * s + 1.95;
    return 0.05;
  }

  /// Peak of [marquezSpeed] (level ground).
  static const double marquezMaxSpeed = 1.6;

  /// Planned walking speed (m/s) along a slope.
  double speed(double slopeDeg) => marquezSpeed(slopeDeg) * paceFactor;

  /// Fastest speed this model can produce on any slope (m/s). Used as the
  /// admissible A* heuristic bound.
  double get maxSpeed => marquezMaxSpeed * paceFactor;

  /// Metabolic rate (W) while walking along a slope (Santee et al. 2001).
  double metabolicRateW(double slopeDeg) {
    final m = totalMassKg;
    final v = speed(slopeDeg);
    final a = slopeDeg * math.pi / 180.0;
    final level = (3.28 * m + 71.1) * (0.661 * v * math.cos(a) + 0.115);
    double slope;
    if (slopeDeg == 0) {
      slope = 0;
    } else if (slopeDeg > 0) {
      slope = 3.5 * m * gravity * v * math.sin(a);
    } else {
      slope = 2.4 *
          m *
          gravity *
          v *
          math.sin(a) *
          math.pow(0.3, slopeDeg.abs() / 7.65);
    }
    return level + slope;
  }

  /// Energy cost of transport (J per metre of path) on a slope.
  double energyPerMeter(double slopeDeg) =>
      metabolicRateW(slopeDeg) / speed(slopeDeg);

  /// Lowest energy-per-metre over the walkable slope range; an admissible
  /// A* bound for energy-optimal routing.
  double get minEnergyPerMeter {
    var best = double.infinity;
    for (var s = -modelSlopeLimitDeg; s <= modelSlopeLimitDeg; s += 0.25) {
      final e = energyPerMeter(s);
      if (e < best) best = e;
    }
    return best;
  }

  /// Oxygen mass consumed (kg) for metabolic [energyJ].
  ///
  /// Uses the standard respiratory energy equivalent of oxygen,
  /// 20.1 kJ per litre O₂ (STP) and O₂ density 1.429 g/L.
  static double oxygenKg(double energyJ) => energyJ / 20100.0 * 1.429e-3;

  /// Oxygen use rate (kg/h) at a metabolic rate (W).
  static double oxygenRateKgPerHour(double watts) => oxygenKg(watts * 3600.0);

  /// Metabolic energy in dietary kilocalories.
  static double kcal(double energyJ) => energyJ / 4184.0;

  EvaModel copyWith({
    double? crewMassKg,
    double? suitMassKg,
    double? paceFactor,
    double? stationWorkW,
  }) =>
      EvaModel(
        crewMassKg: crewMassKg ?? this.crewMassKg,
        suitMassKg: suitMassKg ?? this.suitMassKg,
        paceFactor: paceFactor ?? this.paceFactor,
        gravity: gravity,
        stationWorkW: stationWorkW ?? this.stationWorkW,
      );
}

/// Portable life-support consumable budget. Defaults follow the Shuttle/ISS
/// EMU primary and secondary oxygen systems (NASA EMU Data Book): 0.55 kg
/// primary O₂ and a 1.19 kg secondary pack reserved for emergencies. A Mars
/// suit will differ; these are editable planning assumptions.
class LifeSupport {
  const LifeSupport({
    this.primaryO2Kg = 0.55,
    this.reserveFraction = 0.15,
    this.maxEvaHours = 8,
  });

  final double primaryO2Kg;

  /// Fraction of primary O₂ that must remain on return to the airlock.
  final double reserveFraction;

  /// Hard limit on EVA duration (Earth hours).
  final double maxEvaHours;

  double get usableO2Kg => primaryO2Kg * (1 - reserveFraction);

  LifeSupport copyWith({
    double? primaryO2Kg,
    double? reserveFraction,
    double? maxEvaHours,
  }) =>
      LifeSupport(
        primaryO2Kg: primaryO2Kg ?? this.primaryO2Kg,
        reserveFraction: reserveFraction ?? this.reserveFraction,
        maxEvaHours: maxEvaHours ?? this.maxEvaHours,
      );
}
