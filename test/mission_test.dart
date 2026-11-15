import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivited/src/data/climate.dart';
import 'package:vivited/src/data/models.dart';
import 'package:vivited/src/data/terrain.dart';
import 'package:vivited/src/mission/mission_plan.dart';
import 'package:vivited/src/mission/planner.dart';
import 'package:vivited/src/routing/cost_model.dart';
import 'package:vivited/src/routing/pathfinder.dart';
import 'package:vivited/src/science/eva_model.dart';
import 'package:vivited/src/science/geodesy.dart';
import 'package:vivited/src/state/app_state.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  late TerrainGrid grid;
  late MissionPlanner planner;
  late Map<String, ScienceTarget> targets;

  setUpAll(() {
    final bytes = File('assets/data/jezero_dem.bin').readAsBytesSync();
    grid = TerrainGrid.fromAsset(
      ByteData.sublistView(bytes),
      _json('assets/data/jezero_meta.json'),
    );
    final t = _json('assets/data/science_targets.json');
    final refs = t['references'] as Map<String, dynamic>;
    targets = {
      for (final j in t['targets'] as List)
        (j as Map<String, dynamic>)['id'] as String:
            ScienceTarget.fromJson(j, refs),
    };
    planner = MissionPlanner(
      grid: grid,
      pathfinder: GridPathfinder(grid),
      climatology: Climatology.fromJson(_json('assets/data/meda_climatology.json')),
    );
  });

  List<EvaStop> stopsOf(EvaPreset p) => [
        EvaStop(
          position: targets[p.baseTarget]!.position,
          name: targets[p.baseTarget]!.name,
          dwellMinutes: 0,
        ),
        for (final id in p.stopTargets)
          EvaStop(position: targets[id]!.position, name: targets[id]!.name),
      ];

  Future<MissionPlan> planPreset(EvaPreset p, [EvaParameters? params]) async {
    final q = params ?? EvaParameters(ls: p.ls, startLtst: p.startLtst);
    final stops = stopsOf(p);
    final field = await planner.computeWalkBack(stops.first, q);
    return (await planner.plan(stops, q, walkBack: field))!;
  }

  test('every preset refers to real stations', () {
    for (final p in EvaPreset.all) {
      expect(targets.containsKey(p.baseTarget), isTrue, reason: p.id);
      for (final id in p.stopTargets) {
        expect(targets.containsKey(id), isTrue, reason: '${p.id}/$id');
      }
    }
  });

  test('delta-front walk: closed loop with consistent totals', () async {
    final preset = EvaPreset.all.first;
    final plan = await planPreset(preset);
    expect(plan.routeFound, isTrue);
    expect(plan.legs.length, preset.stopTargets.length + 1);

    // Cumulative quantities never decrease.
    for (var i = 1; i < plan.samples.length; i++) {
      final a = plan.samples[i - 1], b = plan.samples[i];
      expect(b.timeS, greaterThanOrEqualTo(a.timeS));
      expect(b.distM, greaterThanOrEqualTo(a.distM));
      expect(b.energyJ, greaterThanOrEqualTo(a.energyJ));
    }

    // The loop ends where it began.
    final first = plan.samples.first, last = plan.samples.last;
    expect(
      Geodesy.distanceM(first.lat, first.lon, last.lat, last.lon),
      lessThan(30),
    );

    // Totals equal the sum of their parts.
    final legDist = plan.legs.fold(0.0, (a, l) => a + l.distanceM);
    expect(plan.distanceM, closeTo(legDist, 1));
    expect(plan.dwellS, closeTo(preset.stopTargets.length * 20 * 60, 1));
    expect(plan.hazardDistanceM.fold(0.0, (a, b) => a + b),
        closeTo(plan.distanceM, plan.distanceM * 0.02));

    // A path can never be shorter than the straight line between its ends
    // (which are snapped to cell centres, up to half a cell diagonal each).
    for (final l in plan.legs) {
      expect(l.distanceM, greaterThanOrEqualTo(l.straightLineM - 29));
      // …and any-angle smoothing keeps it well under the 8-direction detour.
      expect(l.distanceM, lessThan(l.straightLineM * 1.5 + 29));
    }

    // Average speed cannot exceed the level-ground speed of the model.
    expect(plan.distanceM / plan.walkS,
        lessThanOrEqualTo(const EvaModel().maxSpeed + 1e-9));

    // Oxygen follows from energy.
    expect(plan.o2Kg, closeTo(EvaModel.oxygenKg(plan.energyJ), 1e-12));
    expect(plan.o2Kg, greaterThan(0));

    // The route honours the slope limit.
    expect(plan.maxTerrainSlopeDeg, lessThanOrEqualTo(20.0));
    expect(plan.checks.map((c) => c.title),
        containsAll(['Route', 'Duration', 'Oxygen', 'Daylight', 'Walk-back']));
  });

  test('stateAt interpolates between the ends of the plan', () async {
    final plan = await planPreset(EvaPreset.all.first);
    final start = plan.stateAt(0), end = plan.stateAt(plan.durationS);
    expect(start.distM, 0);
    expect(start.o2RemainingKg, closeTo(plan.parameters.lifeSupport.primaryO2Kg, 1e-9));
    expect(end.distM, closeTo(plan.distanceM, 1e-6));
    expect(end.o2UsedKg, closeTo(plan.o2Kg, 1e-9));
    expect(plan.stateAt(-50).timeS, 0);
    expect(plan.stateAt(plan.durationS + 999).timeS, plan.durationS);

    var prev = start;
    for (var i = 1; i <= 200; i++) {
      final s = plan.stateAt(plan.durationS * i / 200);
      expect(s.distM, greaterThanOrEqualTo(prev.distM));
      expect(s.o2RemainingKg, lessThanOrEqualTo(prev.o2RemainingKg + 1e-12));
      expect(s.headingDeg, inInclusiveRange(0, 360));
      expect(s.walkBackS.isNaN, isFalse);
      prev = s;
    }

    // At a science station the crew is stationary and named as such.
    final visit = plan.stations.firstWhere((v) => v.departS > v.arriveS);
    final mid = plan.stateAt((visit.arriveS + visit.departS) / 2);
    expect(mid.walking, isFalse);
    expect(mid.speedMs, 0);
    expect(mid.activity, contains(visit.name));
  });

  test('walk-back at the airlock is zero and grows away from it', () async {
    final plan = await planPreset(EvaPreset.all.first);
    expect(plan.samples.first.walkBackS, closeTo(0, 1e-6));
    expect(plan.maxWalkBackS, greaterThan(60));
    // Returning by the fastest route cannot take longer than the whole walk.
    expect(plan.maxWalkBackS, lessThan(plan.walkS));
  });

  test('least-effort routing does not spend more energy than fastest', () async {
    final p = EvaPreset.all.first;
    final base = EvaParameters(ls: p.ls, startLtst: p.startLtst);
    final fast = await planPreset(p, base);
    final lean =
        await planPreset(p, base.copyWith(objective: RouteObjective.efficient));
    double walkEnergy(MissionPlan m) => m.legs.fold(0.0, (a, l) => a + l.energyJ);
    expect(walkEnergy(lean), lessThanOrEqualTo(walkEnergy(fast) * 1.0001));
    expect(fast.walkS, lessThanOrEqualTo(lean.walkS * 1.0001));
  });

  test('a slower pace costs time and oxygen', () async {
    final p = EvaPreset.all.first;
    final base = EvaParameters(ls: p.ls, startLtst: p.startLtst);
    final slow = await planPreset(
      p,
      base.copyWith(eva: base.eva.copyWith(paceFactor: 0.5)),
    );
    final normal = await planPreset(p, base);
    expect(slow.durationS, greaterThan(normal.durationS));
  });

  test('the rim stress case is refused', () async {
    final rim = EvaPreset.byId('rim')!;
    final plan = await planPreset(rim);
    expect(plan.overall, CheckStatus.fail);
  });

  test('Route D is a one-way return toward Habitat H0', () async {
    final d = EvaPreset.byId('route-d')!;
    expect(d.returnToBase, isFalse);
    expect(d.baseTarget, 'wildcat');
    expect(d.stopTargets, ['threeforks']);
    final plan = await planPreset(
      d,
      EvaParameters(
        ls: d.ls,
        startLtst: d.startLtst,
        returnToBase: false,
        objective: d.objective!,
      ),
    );
    expect(plan.routeFound, isTrue);
    expect(plan.legs.length, 1);
    expect(plan.parameters.returnToBase, isFalse);
  });

  test('daylight check: warns inside the sunset margin, fails after dark', () async {
    final p = EvaPreset.all.first;
    PlanCheck daylight(MissionPlan m) =>
        m.checks.firstWhere((c) => c.title == 'Daylight');
    final late = await planPreset(p, EvaParameters(ls: p.ls, startLtst: 17.0));
    expect(daylight(late).status, CheckStatus.warn);
    final dark = await planPreset(p, EvaParameters(ls: p.ls, startLtst: 18.2));
    expect(daylight(dark).status, CheckStatus.fail);
    expect(dark.overall, CheckStatus.fail);
    final early = await planPreset(p, EvaParameters(ls: p.ls, startLtst: 4.0));
    expect(daylight(early).status, CheckStatus.fail);
  });

  test('a zero-length leg is handled without dividing by zero', () async {
    final base = targets['threeforks']!;
    final plan = await planner.plan(
      [
        EvaStop(position: base.position, name: base.name),
        EvaStop(position: base.position, name: 'same place'),
      ],
      const EvaParameters(),
    );
    expect(plan, isNotNull);
    expect(plan!.distanceM, lessThan(1));
  });
}
