/// Transparent educational life-support arithmetic for jury demonstrations.
///
/// Units are abstract teaching units, not EMU kilograms. The sample scenario
/// from the Space Apps educational brief is the default:
///
///   starting oxygen 100, duration 120 min, rate 0.3 / min, reserve 20
///   → consumed 36, remaining 64, reserve satisfied.
///
/// Labelled [EDUCATIONAL SIMULATION — NOT FOR REAL ASTRONAUT OPERATIONS]
/// everywhere it appears in the UI. The physical EMU/Santee model in
/// [EvaModel] / [LifeSupport] remains the planner's operational estimate.
class EduLifeSupport {
  const EduLifeSupport({
    this.startingOxygen = 100,
    this.oxygenRatePerMin = 0.3,
    this.oxygenReserve = 20,
    this.startingBattery = 100,
    this.energyRatePerMin = 0.25,
    this.batteryReserve = 15,
    this.travelMinutes = 90,
    this.scienceMinutes = 30,
  });

  /// Starting oxygen budget (educational units).
  final double startingOxygen;

  /// Oxygen consumed per mission minute.
  final double oxygenRatePerMin;

  /// Required oxygen remaining on return.
  final double oxygenReserve;

  /// Starting battery / energy budget (educational units).
  final double startingBattery;

  /// Energy consumed per mission minute (travel + science).
  final double energyRatePerMin;

  /// Required battery remaining on return.
  final double batteryReserve;

  /// Walking / transit duration (Earth minutes).
  final double travelMinutes;

  /// Scientific activity duration at stations (Earth minutes).
  final double scienceMinutes;

  /// Total mission duration used by the formulas.
  double get missionMinutes => travelMinutes + scienceMinutes;

  double get oxygenConsumed => missionMinutes * oxygenRatePerMin;
  double get oxygenRemaining => startingOxygen - oxygenConsumed;
  bool get oxygenOk =>
      oxygenConsumed + oxygenReserve <= startingOxygen + 1e-9;

  double get energyConsumed => missionMinutes * energyRatePerMin;
  double get energyRemaining => startingBattery - energyConsumed;
  bool get energyOk =>
      energyConsumed + batteryReserve <= startingBattery + 1e-9;

  bool get safe => oxygenOk && energyOk;

  /// Exact warning copy required by the educational brief.
  static const returnWarning = 'Return to Habitat / Reduce Mission Time';

  static const disclaimer =
      'EDUCATIONAL SIMULATION — NOT FOR REAL ASTRONAUT OPERATIONS';

  /// The worked example from the project brief (oxygen only).
  static const sampleScenario = EduLifeSupport(
    startingOxygen: 100,
    oxygenRatePerMin: 0.3,
    oxygenReserve: 20,
    travelMinutes: 90,
    scienceMinutes: 30,
  );

  EduLifeSupport copyWith({
    double? startingOxygen,
    double? oxygenRatePerMin,
    double? oxygenReserve,
    double? startingBattery,
    double? energyRatePerMin,
    double? batteryReserve,
    double? travelMinutes,
    double? scienceMinutes,
  }) =>
      EduLifeSupport(
        startingOxygen: startingOxygen ?? this.startingOxygen,
        oxygenRatePerMin: oxygenRatePerMin ?? this.oxygenRatePerMin,
        oxygenReserve: oxygenReserve ?? this.oxygenReserve,
        startingBattery: startingBattery ?? this.startingBattery,
        energyRatePerMin: energyRatePerMin ?? this.energyRatePerMin,
        batteryReserve: batteryReserve ?? this.batteryReserve,
        travelMinutes: travelMinutes ?? this.travelMinutes,
        scienceMinutes: scienceMinutes ?? this.scienceMinutes,
      );

  /// Align travel/science minutes with an evaluated [MissionPlan]-style
  /// duration. Science minutes stay as dwell; travel is the remainder.
  EduLifeSupport syncedToPlan({
    required double walkSeconds,
    required double dwellSeconds,
  }) =>
      copyWith(
        travelMinutes: (walkSeconds / 60).clamp(1, 600),
        scienceMinutes: (dwellSeconds / 60).clamp(0, 600),
      );
}
