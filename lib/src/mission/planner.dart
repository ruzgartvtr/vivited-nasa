import 'dart:math' as math;

import '../data/climate.dart';
import '../data/terrain.dart';
import '../routing/cost_model.dart';
import '../routing/pathfinder.dart';
import '../routing/smoothing.dart';
import '../science/eva_model.dart';
import '../science/geodesy.dart';
import '../science/hazard.dart';
import '../science/mars_time.dart';
import '../science/radiation.dart';
import 'mission_plan.dart';

/// Turns a list of stops into an evaluated [MissionPlan]: routes each leg
/// with A*, integrates time / energy / oxygen along the track, evaluates the
/// environment over the EVA timeline and runs the go / no-go checks.
class MissionPlanner {
  MissionPlanner({
    required this.grid,
    required this.pathfinder,
    this.climatology,
  });

  final TerrainGrid grid;
  final GridPathfinder pathfinder;
  final Climatology? climatology;

  /// Horizon of the walk-back field (s).
  static const double walkBackHorizonS = 2.5 * 3600;

  /// The walk-back field is always time-optimal, whatever the route objective.
  RouteCostModel walkBackModel(EvaParameters p) => RouteCostModel(
        grid: grid,
        eva: p.eva,
        objective: RouteObjective.fastest,
        maxSlopeDeg: p.maxSlopeDeg,
      );

  Future<CostField> computeWalkBack(
    EvaStop base,
    EvaParameters p, {
    bool Function()? isCancelled,
  }) =>
      pathfinder.costToOrigin(
        grid.cellAt(base.position.latitude, base.position.longitude),
        walkBackModel(p),
        maxCost: walkBackHorizonS,
        isCancelled: isCancelled,
      );

  Future<MissionPlan?> plan(
    List<EvaStop> stops,
    EvaParameters p, {
    CostField? walkBack,
    SearchAlgorithm algorithm = SearchAlgorithm.aStar,
    bool Function()? isCancelled,
  }) async {
    if (stops.isEmpty) return null;
    final model = RouteCostModel(
      grid: grid,
      eva: p.eva,
      objective: p.objective,
      maxSlopeDeg: p.maxSlopeDeg,
    );
    final smoother = PathSmoother(grid, model);
    final base = stops.first;
    final sequence = [
      ...stops,
      if (p.returnToBase && stops.length > 1) base,
    ];

    final samples = <RouteSample>[];
    final legs = <LegSummary>[];
    final stations = <StationVisit>[];
    final hazardDist = List<double>.filled(HazardClass.values.length, 0);
    var dist = 0.0, time = 0.0, energy = 0.0;

    double wb(int cell) => walkBack == null ? double.nan : walkBack.at(cell);

    final startCell =
        grid.cellAt(base.position.latitude, base.position.longitude);
    if (startCell < 0) return null;
    samples.add(RouteSample(
      lat: grid.latOfCell(startCell),
      lon: grid.lonOfCell(startCell),
      elevM: grid.elevation[startCell],
      distM: 0,
      timeS: 0,
      energyJ: 0,
      slopeDeg: 0,
      terrainSlopeDeg: grid.slopeDeg[startCell],
      leg: 0,
      walking: true,
      walkBackS: wb(startCell),
    ));

    for (var i = 0; i + 1 < sequence.length; i++) {
      final from = sequence[i], to = sequence[i + 1];
      final a = grid.cellAt(from.position.latitude, from.position.longitude);
      final b = grid.cellAt(to.position.latitude, to.position.longitude);
      final straight = Geodesy.distanceM(
        from.position.latitude,
        from.position.longitude,
        to.position.latitude,
        to.position.longitude,
      );
      final result = (a < 0 || b < 0)
          ? null
          : await pathfinder.findPathAsync(
              a,
              b,
              model,
              algorithm: algorithm,
              isCancelled: isCancelled,
            );
      if (isCancelled?.call() ?? false) return null;
      if (result == null) {
        legs.add(LegSummary(
          fromName: from.name,
          toName: to.name,
          found: false,
          straightLineM: straight,
        ));
        break; // later legs are meaningless without this one
      }

      var legDist = 0.0, legTime = 0.0, legEnergy = 0.0;
      var ascent = 0.0, descent = 0.0, maxSlope = 0.0;
      var prevElev = samples.last.elevM;
      for (final pt in smoother.smooth(result.cells)) {
        final dz = pt.elevM - prevElev;
        prevElev = pt.elevM;
        final m = model.move(pt.stepM, dz)!;
        legDist += m.lengthM;
        legTime += m.timeS;
        legEnergy += m.energyJ;
        if (dz > 0) {
          ascent += dz;
        } else {
          descent -= dz;
        }
        final ts = pt.terrainSlopeDeg;
        if (ts > maxSlope) maxSlope = ts;
        hazardDist[HazardClass.fromSlope(ts).index] += m.lengthM;
        samples.add(RouteSample(
          lat: pt.lat,
          lon: pt.lon,
          elevM: pt.elevM,
          distM: dist + legDist,
          timeS: time + legTime,
          energyJ: energy + legEnergy,
          slopeDeg: m.slopeDeg,
          terrainSlopeDeg: ts,
          leg: i,
          walking: true,
          walkBackS: wb(pt.cell),
        ));
      }
      dist += legDist;
      time += legTime;
      energy += legEnergy;
      legs.add(LegSummary(
        fromName: from.name,
        toName: to.name,
        found: true,
        distanceM: legDist,
        timeS: legTime,
        energyJ: legEnergy,
        ascentM: ascent,
        descentM: descent,
        maxTerrainSlopeDeg: maxSlope,
        nodesExpanded: result.expanded,
        straightLineM: straight,
      ));

      // Science station at every intermediate stop.
      final isFinalReturn = p.returnToBase && i + 1 == sequence.length - 1;
      if (!isFinalReturn && to.dwellMinutes > 0) {
        final dwell = to.dwellMinutes * 60.0;
        stations.add(StationVisit(
          stopIndex: i + 1,
          name: to.name,
          arriveS: time,
          departS: time + dwell,
          position: to.position,
        ));
        time += dwell;
        energy += p.eva.stationWorkW * dwell;
        final last = samples.last;
        samples.add(RouteSample(
          lat: last.lat,
          lon: last.lon,
          elevM: last.elevM,
          distM: dist,
          timeS: time,
          energyJ: energy,
          slopeDeg: 0,
          terrainSlopeDeg: last.terrainSlopeDeg,
          leg: i,
          walking: false,
          walkBackS: last.walkBackS,
        ));
      }
    }

    final plan = MissionPlan(
      stops: stops,
      parameters: p,
      samples: samples,
      legs: legs,
      stations: stations,
      checks: const [],
      events: const [],
      hazardDistanceM: hazardDist,
      climatology: climatology,
      baseLat: base.position.latitude,
    );
    return MissionPlan(
      stops: stops,
      parameters: p,
      samples: samples,
      legs: legs,
      stations: stations,
      checks: _checks(plan, walkBack != null),
      events: _events(plan),
      hazardDistanceM: hazardDist,
      climatology: climatology,
      baseLat: base.position.latitude,
    );
  }

  // ---- Go / no-go -----------------------------------------------------------

  static String _hm(double seconds) {
    final m = (seconds / 60).round();
    return m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min' : '$m min';
  }

  List<PlanCheck> _checks(MissionPlan plan, bool hasWalkBack) {
    final p = plan.parameters;
    final out = <PlanCheck>[];

    // 1. Route exists.
    if (!plan.routeFound) {
      final bad = plan.legs.where((l) => !l.found).toList();
      out.add(PlanCheck(
        'Route',
        bad.isEmpty
            ? 'Add at least one stop.'
            : 'No walkable path from ${bad.first.fromName} to '
                '${bad.first.toName} within the ${p.maxSlopeDeg.round()}° slope limit.',
        CheckStatus.fail,
      ));
      return out;
    }
    out.add(PlanCheck(
      'Route',
      '${plan.legs.length} leg${plan.legs.length == 1 ? '' : 's'} · '
          '${(plan.distanceM / 1000).toStringAsFixed(2)} km on the ground.',
      CheckStatus.pass,
    ));

    // 2. Duration.
    final hours = plan.durationS / 3600.0;
    final maxH = p.lifeSupport.maxEvaHours;
    out.add(PlanCheck(
      'Duration',
      '${_hm(plan.durationS)} of a ${maxH.toStringAsFixed(0)} h suit limit.',
      hours > maxH
          ? CheckStatus.fail
          : hours > 0.85 * maxH
              ? CheckStatus.warn
              : CheckStatus.pass,
    ));

    // 3. Oxygen.
    final usable = p.lifeSupport.usableO2Kg;
    final used = plan.o2Kg;
    out.add(PlanCheck(
      'Oxygen',
      '${(used * 1000).round()} g used of ${(usable * 1000).round()} g usable '
          '(${(p.lifeSupport.reserveFraction * 100).round()} % held in reserve).',
      used > usable
          ? CheckStatus.fail
          : used > 0.85 * usable
              ? CheckStatus.warn
              : CheckStatus.pass,
    ));

    // 4. Daylight.
    final sunrise = MarsTime.sunriseLtst(ls: p.ls, latDeg: plan.baseLat);
    final sunset = MarsTime.sunsetLtst(ls: p.ls, latDeg: plan.baseLat);
    final endLtst = p.startLtst + plan.durationS / MissionPlan.marsHourS;
    final margin = sunset - endLtst;
    CheckStatus dl;
    String dlText;
    if (p.startLtst < sunrise) {
      dl = CheckStatus.fail;
      dlText = 'Egress at ${MarsTime.formatClock(p.startLtst)} is before '
          'sunrise (${MarsTime.formatClock(sunrise)} LTST).';
    } else if (margin < 0) {
      dl = CheckStatus.fail;
      dlText = 'Ingress at ${MarsTime.formatClock(endLtst)} is after sunset '
          '(${MarsTime.formatClock(sunset)} LTST).';
    } else {
      dl = margin < p.sunsetMarginHours ? CheckStatus.warn : CheckStatus.pass;
      dlText = 'Ingress ${MarsTime.formatClock(endLtst)} LTST, '
          '${_hm(margin * MissionPlan.marsHourS)} before sunset '
          '(${MarsTime.formatClock(sunset)}).';
    }
    out.add(PlanCheck('Daylight', dlText, dl));

    // 5. Terrain.
    final severe = plan.hazardDistanceM[HazardClass.severe.index] +
        plan.hazardDistanceM[HazardClass.noGo.index];
    final difficult = plan.hazardDistanceM[HazardClass.difficult.index];
    out.add(PlanCheck(
      'Terrain',
      'Steepest ground ${plan.maxTerrainSlopeDeg.toStringAsFixed(1)}°. '
          '${difficult.round()} m difficult, ${severe.round()} m severe.',
      severe > 0
          ? CheckStatus.warn
          : difficult > 200
              ? CheckStatus.warn
              : CheckStatus.pass,
    ));

    // 6. Walk-back: could the crew member reach the airlock from the worst
    // point of the route on the oxygen left at that moment?
    if (hasWalkBack) {
      final levelRate =
          EvaModel.oxygenRateKgPerHour(p.eva.metabolicRateW(0)) / 3600.0;
      var worstMargin = double.infinity, worstBack = 0.0;
      var beyond = false;
      for (final s in plan.samples) {
        if (!s.walkBackS.isFinite) {
          beyond = true;
          continue;
        }
        final remaining =
            p.lifeSupport.usableO2Kg - EvaModel.oxygenKg(s.energyJ);
        final m = remaining - s.walkBackS * levelRate;
        if (m < worstMargin) {
          worstMargin = m;
          worstBack = s.walkBackS;
        }
      }
      if (beyond) {
        out.add(PlanCheck(
          'Walk-back',
          'Part of the route is more than '
              '${_hm(walkBackHorizonS)} on foot from the airlock.',
          CheckStatus.fail,
        ));
      } else {
        out.add(PlanCheck(
          'Walk-back',
          'Farthest point is ${_hm(plan.maxWalkBackS)} from the airlock. '
              'Tightest oxygen margin on a direct return: '
              '${(worstMargin * 1000).round()} g '
              '(at ${_hm(worstBack)} out).',
          worstMargin < 0
              ? CheckStatus.fail
              : worstMargin < 0.1 * p.lifeSupport.usableO2Kg
                  ? CheckStatus.warn
                  : CheckStatus.pass,
        ));
      }
    }

    // 7. Thermal environment (information; suit limits are not modelled).
    if (climatology != null) {
      double? lo, hi;
      for (var t = 0.0; t <= plan.durationS; t += 600) {
        final c = plan.climateAt(t)?.airTempC;
        if (c == null) continue;
        lo = lo == null ? c : math.min(lo, c);
        hi = hi == null ? c : math.max(hi, c);
      }
      if (lo != null) {
        out.add(PlanCheck(
          'Thermal',
          'Air ${lo.round()} to ${hi!.round()} °C during the EVA '
              '(MEDA, 1.45 m).',
          CheckStatus.info,
        ));
      }
    }

    // 8. Radiation (information).
    out.add(PlanCheck(
      'Radiation',
      '${plan.doseUsv.round()} ± ${plan.doseSigmaUsv.round()} µSv GCR dose '
          'equivalent (RAD, Gale). A full sol on the surface is '
          '${Radiation.perSolUsv.round()} µSv; no solar-storm allowance.',
      CheckStatus.info,
    ));
    return out;
  }

  // ---- Timeline events ------------------------------------------------------

  List<MissionEvent> _events(MissionPlan plan) {
    if (!plan.hasTrack) return const [];
    final p = plan.parameters;
    final ev = <MissionEvent>[
      MissionEvent(0, 'Egress · ${plan.stops.first.name}'),
    ];
    for (final s in plan.stations) {
      ev.add(MissionEvent(s.arriveS, 'Arrive ${s.name}'));
      ev.add(MissionEvent(s.departS, 'Depart ${s.name}'));
    }
    // Hazard class transitions into difficult-or-worse ground.
    var prev = HazardClass.nominal;
    for (final s in plan.samples) {
      final h = s.hazard;
      if (h.index >= HazardClass.difficult.index &&
          prev.index < HazardClass.difficult.index) {
        ev.add(MissionEvent(
          s.timeS,
          '${h.label} slope ahead · ${s.terrainSlopeDeg.toStringAsFixed(0)}°',
          h.index >= HazardClass.severe.index
              ? EventSeverity.warning
              : EventSeverity.caution,
        ));
      }
      prev = h;
    }
    // Oxygen milestones.
    final usable = p.lifeSupport.usableO2Kg;
    for (final frac in const [0.5, 0.75, 1.0]) {
      final target = usable * frac;
      for (var i = 1; i < plan.samples.length; i++) {
        final a = EvaModel.oxygenKg(plan.samples[i - 1].energyJ);
        final b = EvaModel.oxygenKg(plan.samples[i].energyJ);
        if (a < target && b >= target) {
          ev.add(MissionEvent(
            plan.samples[i].timeS,
            frac >= 1.0
                ? 'Usable oxygen exhausted — on reserve'
                : '${(frac * 100).round()} % of usable oxygen consumed',
            frac >= 1.0
                ? EventSeverity.warning
                : frac >= 0.75
                    ? EventSeverity.caution
                    : EventSeverity.info,
          ));
          break;
        }
      }
    }
    // Sunset.
    final sunset = MarsTime.sunsetLtst(ls: p.ls, latDeg: plan.baseLat);
    final tSunset = (sunset - p.startLtst) * MissionPlan.marsHourS;
    if (tSunset > 0 && tSunset < plan.durationS) {
      ev.add(MissionEvent(tSunset, 'Sunset', EventSeverity.warning));
    }
    final tLow = (sunset - 1 - p.startLtst) * MissionPlan.marsHourS;
    if (tLow > 0 && tLow < plan.durationS) {
      ev.add(MissionEvent(tLow, 'One hour to sunset', EventSeverity.caution));
    }
    if (plan.routeFound) {
      ev.add(MissionEvent(
        plan.durationS,
        p.returnToBase ? 'Ingress · ${plan.stops.first.name}' : 'End of EVA',
      ));
    }
    ev.sort((a, b) => a.timeS.compareTo(b.timeS));
    return ev;
  }
}
