import 'dart:math' as math;

import '../data/terrain.dart';
import 'cost_model.dart';

/// A point on a planned track, sampled from the terrain model.
class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lon,
    required this.elevM,
    required this.terrainSlopeDeg,
    required this.cell,
    required this.stepM,
  });

  final double lat;
  final double lon;
  final double elevM;

  /// Terrain slope magnitude here (deg), bilinear from the slope grid.
  final double terrainSlopeDeg;

  /// Nearest grid cell.
  final int cell;

  /// Horizontal ground distance from the previous point (m).
  final double stepM;
}

/// Any-angle post-processing of an 8-connected grid path.
///
/// A grid search can only move in eight directions, so its paths zig-zag and
/// are up to 8 % longer than the ground allows. This pass replaces runs of
/// cells by straight segments wherever the straight segment
///
/// * crosses no ground steeper than the slope limit,
/// * exceeds the along-track slope limit nowhere, and
/// * costs no more, on the active objective, than the run it replaces.
///
/// The third rule means smoothing can only improve on the search result.
class PathSmoother {
  PathSmoother(this.grid, this.model, {this.maxSpanCells = 160});

  final TerrainGrid grid;
  final RouteCostModel model;

  /// Longest run of path cells one straight segment may replace.
  final int maxSpanCells;

  /// Points along the straight line from cell [a] to cell [b], one per grid
  /// step of the longer axis; excludes [a], ends exactly on [b].
  List<TrackPoint> segment(int a, int b) {
    final ra = grid.rowOf(a), ca = grid.colOf(a);
    final dr = grid.rowOf(b) - ra, dc = grid.colOf(b) - ca;
    final n = math.max(dr.abs(), dc.abs());
    final out = <TrackPoint>[];
    for (var k = 1; k <= n; k++) {
      final r = ra + dr * k / n, c = ca + dc * k / n;
      final rowMid = (ra + dr * (k - 0.5) / n).round();
      final dx = grid.cellDx(rowMid) * dc / n, dy = grid.cellDy * dr / n;
      final lat = grid.rowToLat(r), lon = grid.colToLon(c);
      out.add(TrackPoint(
        lat: lat,
        lon: lon,
        elevM: grid.elevationAt(lat, lon),
        terrainSlopeDeg: grid.slopeAt(lat, lon),
        cell: grid.index(r.round(), c.round()),
        stepM: math.sqrt(dx * dx + dy * dy),
      ));
    }
    return out;
  }

  /// Objective cost of walking the straight line [a] → [b]; infinity if any
  /// part of it is not traversable.
  double segmentCost(int a, int b) {
    var prev = grid.elevation[a];
    var total = 0.0;
    for (final p in segment(a, b)) {
      // The nearest cell must itself be open, so a straight line cannot
      // squeeze between two closed cells.
      if (model.isBlocked(p.cell)) return double.infinity;
      final c = model.stepCost(p.stepM, p.elevM - prev, p.terrainSlopeDeg);
      if (c == double.infinity) return double.infinity;
      total += c;
      prev = p.elevM;
    }
    return total;
  }

  /// Indices into [cells] of the vertices to keep. Always includes the first
  /// and last cell.
  List<int> anchors(List<int> cells) {
    if (cells.length <= 2) return [for (var i = 0; i < cells.length; i++) i];
    // Cost of the grid path up to each cell.
    final prefix = List<double>.filled(cells.length, 0);
    for (var i = 1; i < cells.length; i++) {
      final u = cells[i - 1], v = cells[i];
      final dx = grid.cellDx(grid.rowOf(u)) * (grid.colOf(v) - grid.colOf(u));
      final dy = grid.cellDy * (grid.rowOf(v) - grid.rowOf(u));
      prefix[i] = prefix[i - 1] + model.edgeCost(u, v, math.sqrt(dx * dx + dy * dy));
    }
    final keep = <int>[0];
    var i = 0;
    while (i < cells.length - 1) {
      // Farthest vertex reachable in a straight line at no extra cost.
      var best = i + 1;
      final limit = math.min(cells.length - 1, i + maxSpanCells);
      var misses = 0;
      for (var j = i + 2; j <= limit; j++) {
        final straight = segmentCost(cells[i], cells[j]);
        if (straight <= (prefix[j] - prefix[i]) * (1 + 1e-9) + 1e-9) {
          best = j;
          misses = 0;
        } else if (++misses > 24) {
          break; // the line of sight is lost; stop probing
        }
      }
      keep.add(best);
      i = best;
    }
    return keep;
  }

  /// The smoothed track for a grid path: every point after the first cell.
  List<TrackPoint> smooth(List<int> cells) {
    final keep = anchors(cells);
    final out = <TrackPoint>[];
    for (var k = 1; k < keep.length; k++) {
      out.addAll(segment(cells[keep[k - 1]], cells[keep[k]]));
    }
    return out;
  }
}
