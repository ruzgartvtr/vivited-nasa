import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vivited/src/data/terrain.dart';
import 'package:vivited/src/routing/cost_model.dart';
import 'package:vivited/src/routing/min_heap.dart';
import 'package:vivited/src/routing/pathfinder.dart';
import 'package:vivited/src/routing/smoothing.dart';
import 'package:vivited/src/science/eva_model.dart';

/// Rolling synthetic terrain with a steep ridge crossing the middle and a
/// single pass through it.
TerrainGrid ridgeTerrain({bool withPass = true}) => TerrainGrid.synthetic(
      rows: 60,
      cols: 80,
      height: (x, y) {
        final rolling = 6 * math.sin(x / 140) * math.cos(y / 170);
        final dx = (x - 800).abs();
        final inPass = withPass && (y - 300).abs() < 70;
        final ridge = inPass ? 0.0 : 260 * math.exp(-dx * dx / (2 * 120 * 120));
        return rolling + ridge;
      },
    );

double pathCost(TerrainGrid g, RouteCostModel m, List<int> cells) {
  var c = 0.0;
  for (var i = 1; i < cells.length; i++) {
    final u = cells[i - 1], v = cells[i];
    final dr = g.rowOf(v) - g.rowOf(u), dc = g.colOf(v) - g.colOf(u);
    expect(dr.abs() <= 1 && dc.abs() <= 1, isTrue, reason: 'non-adjacent step');
    final h = math.sqrt(
      math.pow(g.cellDx(g.rowOf(u)) * dc, 2) + math.pow(g.cellDy * dr, 2),
    );
    c += m.edgeCost(u, v, h);
  }
  return c;
}

void main() {
  group('MinHeap', () {
    test('pops in priority order, including after growth', () {
      final rnd = math.Random(7);
      final heap = MinHeap(4);
      final values = [for (var i = 0; i < 5000; i++) rnd.nextDouble() * 1000];
      for (var i = 0; i < values.length; i++) {
        heap.push(values[i], i);
      }
      expect(heap.length, 5000);
      var last = -1.0;
      while (heap.isNotEmpty) {
        final p = heap.minPriority;
        final node = heap.pop();
        expect(values[node], p);
        expect(p, greaterThanOrEqualTo(last));
        last = p;
      }
    });
  });

  group('GridPathfinder', () {
    final grid = ridgeTerrain();
    final pf = GridPathfinder(grid);
    final start = grid.index(30, 5), goal = grid.index(30, 75);

    for (final objective in RouteObjective.values) {
      test('A* matches Dijkstra optimum · ${objective.name}', () {
        final model = RouteCostModel(
          grid: grid,
          eva: const EvaModel(),
          objective: objective,
        );
        final a = pf.findPath(start, goal, model)!;
        final d = pf.findPath(
          start,
          goal,
          model,
          algorithm: SearchAlgorithm.dijkstra,
        )!;
        expect(a.cost, closeTo(d.cost, d.cost * 1e-9));
        expect(a.expanded, lessThanOrEqualTo(d.expanded));
        expect(a.cells.first, start);
        expect(a.cells.last, goal);
        expect(pathCost(grid, model, a.cells), closeTo(a.cost, a.cost * 1e-9));
      });
    }

    test('route never touches ground steeper than the limit', () {
      final model = RouteCostModel(grid: grid, eva: const EvaModel(), maxSlopeDeg: 15);
      final r = pf.findPath(start, goal, model)!;
      for (final c in r.cells) {
        expect(grid.slopeDeg[c], lessThanOrEqualTo(15));
      }
      // The only way across is the pass (rows near y = 300 m).
      final crossing = r.cells.firstWhere((c) => grid.colOf(c) == 40);
      final y = (grid.rows - 1 - grid.rowOf(crossing)) * 20.0;
      expect((y - 300).abs(), lessThan(90));
    });

    test('returns null when the ridge has no pass', () {
      final wall = ridgeTerrain(withPass: false);
      final model = RouteCostModel(grid: wall, eva: const EvaModel(), maxSlopeDeg: 15);
      final r = GridPathfinder(wall)
          .findPath(wall.index(30, 5), wall.index(30, 75), model);
      expect(r, isNull);
    });

    test('flat ground: straight line at the level walking speed', () {
      final flat = TerrainGrid.synthetic(rows: 20, cols: 60, height: (x, y) => 0);
      const eva = EvaModel(paceFactor: 1);
      final model = RouteCostModel(grid: flat, eva: eva);
      final r = GridPathfinder(flat)
          .findPath(flat.index(10, 5), flat.index(10, 55), model)!;
      expect(r.cells.length, 51);
      expect(r.cost, closeTo(50 * 20 / 1.6, 0.5));
    });

    test('safest objective trades time for gentler ground', () {
      final fast = RouteCostModel(grid: grid, eva: const EvaModel());
      final safe = RouteCostModel(
        grid: grid,
        eva: const EvaModel(),
        objective: RouteObjective.safest,
      );
      double meanSlope(List<int> cells) =>
          cells.map((c) => grid.slopeDeg[c]).reduce((a, b) => a + b) /
          cells.length;
      final rf = pf.findPath(start, goal, fast)!;
      final rs = pf.findPath(start, goal, safe)!;
      expect(meanSlope(rs.cells), lessThanOrEqualTo(meanSlope(rf.cells) + 1e-9));
      expect(pathCost(grid, fast, rs.cells), greaterThanOrEqualTo(rf.cost - 1e-6));
    });

    test('async search equals sync search and can be cancelled', () async {
      final model = RouteCostModel(grid: grid, eva: const EvaModel());
      final sync = pf.findPath(start, goal, model)!;
      final async = await pf.findPathAsync(start, goal, model, sliceNodes: 50);
      expect(async!.cost, sync.cost);
      final cancelled = await pf.findPathAsync(
        start,
        goal,
        model,
        sliceNodes: 10,
        isCancelled: () => true,
      );
      expect(cancelled, isNull);
    });

    test('walk-back field equals point-to-point cost towards the base', () async {
      final model = RouteCostModel(grid: grid, eva: const EvaModel());
      final base = grid.index(30, 5);
      final field = await pf.costToOrigin(base, model, maxCost: 1e9);
      expect(field.at(base), 0);
      for (final cell in [grid.index(10, 20), grid.index(50, 12), goal]) {
        final direct = pf.findPath(cell, base, model)!;
        expect(field.at(cell), closeTo(direct.cost, direct.cost * 1e-5));
      }
      // Bounded sweep leaves far cells unreached.
      final near = await pf.costToOrigin(base, model, maxCost: 120);
      expect(near.at(goal), double.infinity);
      expect(near.reached, lessThan(field.reached));
    });
  });

  group('PathSmoother', () {
    TerrainGrid flat() =>
        TerrainGrid.synthetic(rows: 60, cols: 100, height: (x, y) => 5.0);

    test('flat ground: one straight segment of Euclidean length', () {
      final g = flat();
      final model = RouteCostModel(grid: g, eva: const EvaModel());
      final a = g.index(10, 10), b = g.index(30, 80);
      final path = GridPathfinder(g).findPath(a, b, model)!;
      final smoother = PathSmoother(g, model);
      expect(smoother.anchors(path.cells), [0, path.cells.length - 1]);

      final pts = smoother.smooth(path.cells);
      final length = pts.fold(0.0, (s, p) => s + p.stepM);
      final dx = g.cellDx(20) * 70, dy = g.cellDy * 20;
      expect(length, closeTo(math.sqrt(dx * dx + dy * dy), 0.5));
      // The grid path is the longer octile distance.
      final octile = g.cellDy * 20 * math.sqrt2 + g.cellDx(20) * 50;
      expect(length, lessThan(octile * 0.95));
      expect(pts.last.cell, b);
      expect(pts.last.lat, closeTo(g.latOfCell(b), 1e-12));
    });

    test('adjacent cells: a segment is exactly the grid edge', () {
      final g = ridgeTerrain();
      final model = RouteCostModel(grid: g, eva: const EvaModel());
      final a = g.index(20, 20), b = g.index(21, 21);
      final h = math.sqrt(math.pow(g.cellDx(20), 2) + math.pow(g.cellDy, 2));
      expect(PathSmoother(g, model).segmentCost(a, b),
          closeTo(model.edgeCost(a, b, h), 1e-6));
    });

    for (final objective in RouteObjective.values) {
      test('never costs more than the grid path, never crosses closed ground '
          '· ${objective.name}', () {
        final g = ridgeTerrain();
        final model =
            RouteCostModel(grid: g, eva: const EvaModel(), objective: objective);
        final path =
            GridPathfinder(g).findPath(g.index(50, 5), g.index(8, 75), model)!;
        final smoother = PathSmoother(g, model);
        final keep = smoother.anchors(path.cells);
        expect(keep.first, 0);
        expect(keep.last, path.cells.length - 1);
        expect(keep.length, lessThan(path.cells.length));

        var cost = 0.0;
        for (var k = 1; k < keep.length; k++) {
          cost += smoother.segmentCost(
            path.cells[keep[k - 1]],
            path.cells[keep[k]],
          );
        }
        expect(cost.isFinite, isTrue);
        expect(cost, lessThanOrEqualTo(path.cost * (1 + 1e-6)));

        for (final p in smoother.smooth(path.cells)) {
          expect(model.isBlocked(p.cell), isFalse);
          expect(p.terrainSlopeDeg, lessThanOrEqualTo(model.maxSlopeDeg));
        }
      });
    }

    test('a straight line through the ridge is refused', () {
      final g = ridgeTerrain();
      final model = RouteCostModel(grid: g, eva: const EvaModel());
      // Same row on either side of the ridge, away from the pass.
      expect(
        PathSmoother(g, model).segmentCost(g.index(5, 10), g.index(5, 70)),
        double.infinity,
      );
    });
  });
}
