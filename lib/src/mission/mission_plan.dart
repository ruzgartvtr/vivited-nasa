import 'package:latlong2/latlong.dart';

import '../data/climate.dart';
import '../routing/cost_model.dart';
import '../science/eva_model.dart';
import '../science/geodesy.dart';
import '../science/hazard.dart';
import '../science/mars_constants.dart';
import '../science/mars_time.dart';
import '../science/radiation.dart';

/// A point the crew walks to. The first stop of a plan is the base (airlock).
class EvaStop {
  const EvaStop({
    required this.position,
    required this.name,
    this.targetId,
    this.dwellMinutes = 20,
  });

  final LatLng position;
  final String name;
  final String? targetId;

  /// Time spent working at the stop (Earth minutes). Ignored for the base.
  final double dwellMinutes;

  EvaStop copyWith({String? name, double? dwellMinutes, LatLng? position}) =>
      EvaStop(
        position: position ?? this.position,
        name: name ?? this.name,
        targetId: targetId,
        dwellMinutes: dwellMinutes ?? this.dwellMinutes,
      );
}

/// Everything the planner needs besides the stops.
class EvaParameters {
  const EvaParameters({
    this.eva = const EvaModel(),
    this.lifeSupport = const LifeSupport(),
    this.objective = RouteObjective.fastest,
    this.maxSlopeDeg = 20,
    this.ls = 90,
    this.startLtst = 9.0,
    this.returnToBase = true,
    this.sunsetMarginHours = 1.0,
  });

  final EvaModel eva;
  final LifeSupport lifeSupport;
  final RouteObjective objective;
  final double maxSlopeDeg;

  /// Season: areocentric solar longitude (deg).
  final double ls;

  /// Egress time, local true solar time (Mars hours).
  final double startLtst;
  final bool returnToBase;

  /// Required margin between ingress and sunset (Mars hours).
  final double sunsetMarginHours;

  EvaParameters copyWith({
    EvaModel? eva,
    LifeSupport? lifeSupport,
    RouteObjective? objective,
    double? maxSlopeDeg,
    double? ls,
    double? startLtst,
    bool? returnToBase,
    double? sunsetMarginHours,
  }) =>
      EvaParameters(
        eva: eva ?? this.eva,
        lifeSupport: lifeSupport ?? this.lifeSupport,
        objective: objective ?? this.objective,
        maxSlopeDeg: maxSlopeDeg ?? this.maxSlopeDeg,
        ls: ls ?? this.ls,
        startLtst: startLtst ?? this.startLtst,
        returnToBase: returnToBase ?? this.returnToBase,
        sunsetMarginHours: sunsetMarginHours ?? this.sunsetMarginHours,
      );
}

/// One vertex of the planned track with cumulative totals on arrival.
class RouteSample {
  const RouteSample({
    required this.lat,
    required this.lon,
    required this.elevM,
    required this.distM,
    required this.timeS,
    required this.energyJ,
    required this.slopeDeg,
    required this.terrainSlopeDeg,
    required this.leg,
    required this.walking,
    required this.walkBackS,
  });

  final double lat;
  final double lon;
  final double elevM;

  /// Path length walked so far (m, along the surface).
  final double distM;

  /// Elapsed EVA time (s).
  final double timeS;

  /// Metabolic energy spent so far (J).
  final double energyJ;

  /// Along-track slope of the step that arrived here (deg, + uphill).
  final double slopeDeg;

  /// Terrain slope magnitude at this cell (deg).
  final double terrainSlopeDeg;
  final int leg;

  /// False for the stationary sample that closes a science stop.
  final bool walking;

  /// Fastest walking time from here back to base (s); NaN if unknown,
  /// infinity if beyond the computed walk-back horizon.
  final double walkBackS;

  LatLng get position => LatLng(lat, lon);
  HazardClass get hazard => HazardClass.fromSlope(terrainSlopeDeg);
}

class LegSummary {
  const LegSummary({
    required this.fromName,
    required this.toName,
    required this.found,
    this.distanceM = 0,
    this.timeS = 0,
    this.energyJ = 0,
    this.ascentM = 0,
    this.descentM = 0,
    this.maxTerrainSlopeDeg = 0,
    this.nodesExpanded = 0,
    this.straightLineM = 0,
  });

  final String fromName;
  final String toName;
  final bool found;
  final double distanceM;
  final double timeS;
  final double energyJ;
  final double ascentM;
  final double descentM;
  final double maxTerrainSlopeDeg;
  final int nodesExpanded;
  final double straightLineM;
}

class StationVisit {
  const StationVisit({
    required this.stopIndex,
    required this.name,
    required this.arriveS,
    required this.departS,
    required this.position,
  });
  final int stopIndex;
  final String name;
  final double arriveS;
  final double departS;
  final LatLng position;
}

enum CheckStatus { pass, warn, fail, info }

class PlanCheck {
  const PlanCheck(this.title, this.detail, this.status);
  final String title;
  final String detail;
  final CheckStatus status;
}

enum EventSeverity { info, caution, warning }

class MissionEvent {
  const MissionEvent(this.timeS, this.message, [this.severity = EventSeverity.info]);
  final double timeS;
  final String message;
  final EventSeverity severity;
}

/// Instantaneous state of the EVA at a time along the plan.
class EvaState {
  const EvaState({
    required this.timeS,
    required this.position,
    required this.elevM,
    required this.distM,
    required this.energyJ,
    required this.slopeDeg,
    required this.terrainSlopeDeg,
    required this.speedMs,
    required this.metabolicW,
    required this.walking,
    required this.headingDeg,
    required this.o2UsedKg,
    required this.o2RemainingKg,
    required this.walkBackS,
    required this.ltst,
    required this.sunElevationDeg,
    required this.sunAzimuthDeg,
    required this.doseUsv,
    required this.climate,
    required this.activity,
  });

  final double timeS;
  final LatLng position;
  final double elevM;
  final double distM;
  final double energyJ;
  final double slopeDeg;
  final double terrainSlopeDeg;
  final double speedMs;
  final double metabolicW;
  final bool walking;
  final double headingDeg;
  final double o2UsedKg;
  final double o2RemainingKg;
  final double walkBackS;
  final double ltst;
  final double sunElevationDeg;
  final double sunAzimuthDeg;
  final double doseUsv;
  final ClimateSample? climate;
  final String activity;

  HazardClass get hazard => HazardClass.fromSlope(terrainSlopeDeg);
}

/// A fully evaluated Marswalk.
class MissionPlan {
  MissionPlan({
    required this.stops,
    required this.parameters,
    required this.samples,
    required this.legs,
    required this.stations,
    required this.checks,
    required this.events,
    required this.hazardDistanceM,
    required this.climatology,
    required this.baseLat,
  });

  final List<EvaStop> stops;
  final EvaParameters parameters;
  final List<RouteSample> samples;
  final List<LegSummary> legs;
  final List<StationVisit> stations;
  final List<PlanCheck> checks;
  final List<MissionEvent> events;

  /// Distance walked on each [HazardClass] (m), indexed by enum order.
  final List<double> hazardDistanceM;
  final Climatology? climatology;
  final double baseLat;

  /// Seconds in one Mars solar hour.
  static const double marsHourS = solSeconds / 24.0;

  bool get routeFound => legs.isNotEmpty && legs.every((l) => l.found);
  bool get hasTrack => samples.length > 1;

  double get distanceM => samples.isEmpty ? 0 : samples.last.distM;
  double get durationS => samples.isEmpty ? 0 : samples.last.timeS;
  double get energyJ => samples.isEmpty ? 0 : samples.last.energyJ;
  double get o2Kg => EvaModel.oxygenKg(energyJ);
  double get walkS => legs.fold(0.0, (a, l) => a + l.timeS);
  double get dwellS => durationS - walkS;
  double get ascentM => legs.fold(0.0, (a, l) => a + l.ascentM);
  double get descentM => legs.fold(0.0, (a, l) => a + l.descentM);
  double get maxTerrainSlopeDeg =>
      legs.fold(0.0, (a, l) => l.maxTerrainSlopeDeg > a ? l.maxTerrainSlopeDeg : a);
  double get doseUsv => Radiation.doseEquivalentUsv(durationS);
  double get doseSigmaUsv => Radiation.doseEquivalentSigmaUsv(durationS);
  double get endLtst => ltstAt(durationS);

  double get minElevM =>
      samples.fold(double.infinity, (a, s) => s.elevM < a ? s.elevM : a);
  double get maxElevM =>
      samples.fold(-double.infinity, (a, s) => s.elevM > a ? s.elevM : a);

  double get maxWalkBackS {
    var m = 0.0;
    for (final s in samples) {
      if (s.walkBackS.isFinite && s.walkBackS > m) m = s.walkBackS;
    }
    return m;
  }

  CheckStatus get overall {
    if (checks.any((c) => c.status == CheckStatus.fail)) return CheckStatus.fail;
    if (checks.any((c) => c.status == CheckStatus.warn)) return CheckStatus.warn;
    return CheckStatus.pass;
  }

  List<LatLng> get track => [for (final s in samples) s.position];

  double ltstAt(double timeS) =>
      (parameters.startLtst + timeS / marsHourS) % 24.0;

  double sunElevationAt(double timeS) => MarsTime.sunElevation(
        ls: parameters.ls,
        latDeg: baseLat,
        ltst: ltstAt(timeS),
      );

  ClimateSample? climateAt(double timeS) => climatology?.sample(
        parameters.ls,
        MarsTime.lmstFromLtst(ltstAt(timeS), parameters.ls),
      );

  /// Interpolated EVA state at [timeS] (clamped to the plan).
  EvaState stateAt(double timeS) {
    final t = timeS.clamp(0.0, durationS);
    // Binary search for the segment containing t.
    var lo = 0, hi = samples.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (samples[mid].timeS <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = samples[lo], b = samples[hi];
    final span = b.timeS - a.timeS;
    final f = span <= 0 ? 0.0 : (t - a.timeS) / span;
    double mix(double x, double y) => x + (y - x) * f;
    final walking = b.walking && span > 0;
    final energy = mix(a.energyJ, b.energyJ);
    final o2 = EvaModel.oxygenKg(energy);
    final ltst = ltstAt(t);
    String activity;
    if (!walking) {
      final st = stations.where((s) => t >= s.arriveS && t <= s.departS);
      activity = st.isEmpty
          ? (t >= durationS ? 'EVA complete' : 'Holding')
          : 'Science station · ${st.first.name}';
    } else {
      final to = b.leg < legs.length ? legs[b.leg].toName : '';
      activity = 'Walking to $to';
    }
    double wb;
    if (a.walkBackS.isNaN || b.walkBackS.isNaN) {
      wb = double.nan;
    } else if (!a.walkBackS.isFinite || !b.walkBackS.isFinite) {
      wb = double.infinity;
    } else {
      wb = mix(a.walkBackS, b.walkBackS);
    }
    return EvaState(
      timeS: t,
      position: LatLng(mix(a.lat, b.lat), mix(a.lon, b.lon)),
      elevM: mix(a.elevM, b.elevM),
      distM: mix(a.distM, b.distM),
      energyJ: energy,
      slopeDeg: walking ? b.slopeDeg : 0,
      terrainSlopeDeg: mix(a.terrainSlopeDeg, b.terrainSlopeDeg),
      speedMs: walking ? (b.distM - a.distM) / span : 0,
      metabolicW: span > 0
          ? (b.energyJ - a.energyJ) / span
          : parameters.eva.stationWorkW,
      walking: walking,
      headingDeg: _heading(lo, hi),
      o2UsedKg: o2,
      o2RemainingKg: parameters.lifeSupport.primaryO2Kg - o2,
      walkBackS: wb,
      ltst: ltst,
      sunElevationDeg: sunElevationAt(t),
      sunAzimuthDeg: MarsTime.sunAzimuth(
        ls: parameters.ls,
        latDeg: baseLat,
        ltst: ltst,
      ),
      doseUsv: Radiation.doseEquivalentUsv(t),
      climate: climateAt(t),
      activity: activity,
    );
  }

  double _heading(int lo, int hi) {
    // Use the nearest moving segment so the marker keeps its heading at stops.
    var i = lo, j = hi;
    while (j < samples.length - 1 &&
        samples[i].lat == samples[j].lat &&
        samples[i].lon == samples[j].lon) {
      j++;
    }
    while (i > 0 &&
        samples[i].lat == samples[j].lat &&
        samples[i].lon == samples[j].lon) {
      i--;
    }
    final a = samples[i], b = samples[j];
    return Geodesy.bearingDeg(a.lat, a.lon, b.lat, b.lon);
  }
}
