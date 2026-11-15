import 'dart:math' as math;

import '../data/terrain.dart';
import '../science/eva_model.dart';

/// What the router minimises.
enum RouteObjective {
  fastest('Fastest', 'Minimise walking time.'),
  efficient('Least effort', 'Minimise metabolic energy, hence oxygen.'),
  safest('Safest', 'Minimise time, heavily penalising sloped ground.');

  const RouteObjective(this.label, this.description);
  final String label;
  final String description;
}

/// Physical traversal cost between adjacent grid cells.
class RouteCostModel {
  RouteCostModel({
    required this.grid,
    required this.eva,
    this.objective = RouteObjective.fastest,
    this.maxSlopeDeg = 20,
  }) {
    var best = double.infinity;
    for (var a = -maxSlopeDeg; a <= maxSlopeDeg; a += 0.25) {
      best = math.min(best, eva.energyPerMeter(a));
    }
    _minEnergyPerMeter = best;
  }

  final TerrainGrid grid;
  final EvaModel eva;
  final RouteObjective objective;

  /// Cells whose terrain slope exceeds this, and moves whose along-track
  /// slope exceeds it, are impassable.
  final double maxSlopeDeg;

  late final double _minEnergyPerMeter;

  static const double _deg = math.pi / 180.0;

  /// Weight of the slope penalty in [RouteObjective.safest]: cost is
  /// multiplied by 1 + (terrain slope / 6°)², so ground at the edge of the
  /// "caution" class costs twice its walking time.
  static const double safetySlopeScaleDeg = 6.0;

  bool isBlocked(int cell) => grid.slopeDeg[cell] > maxSlopeDeg;

  /// Walking time (s) and metabolic energy (J) for a straight move of
  /// horizontal length [horizontalM] climbing [dz] metres. Returns `null`
  /// when the along-track slope is beyond [maxSlopeDeg].
  ({double timeS, double energyJ, double lengthM, double slopeDeg})? move(
    double horizontalM,
    double dz,
  ) {
    final slope = math.atan2(dz, horizontalM) / _deg;
    if (slope.abs() > maxSlopeDeg) return null;
    final len = math.sqrt(horizontalM * horizontalM + dz * dz);
    final t = len / eva.speed(slope);
    return (
      timeS: t,
      energyJ: eva.metabolicRateW(slope) * t,
      lengthM: len,
      slopeDeg: slope,
    );
  }

  /// Objective cost of stepping from cell [from] to adjacent cell [to]
  /// separated by [horizontalM]; `double.infinity` if not traversable.
  double edgeCost(int from, int to, double horizontalM) => stepCost(
        horizontalM,
        grid.elevation[to] - grid.elevation[from],
        grid.slopeDeg[to],
      );

  /// Objective cost of a straight step of horizontal length [horizontalM]
  /// climbing [dz] metres onto ground of terrain slope [slopeTo] (deg);
  /// `double.infinity` if not traversable.
  double stepCost(double horizontalM, double dz, double slopeTo) {
    // Hot path of the search: written without allocations.
    if (slopeTo > maxSlopeDeg) return double.infinity;
    final slope = math.atan2(dz, horizontalM) / _deg;
    if (slope > maxSlopeDeg || slope < -maxSlopeDeg) return double.infinity;
    final t = math.sqrt(horizontalM * horizontalM + dz * dz) / eva.speed(slope);
    switch (objective) {
      case RouteObjective.fastest:
        return t;
      case RouteObjective.efficient:
        return eva.metabolicRateW(slope) * t;
      case RouteObjective.safest:
        final k = slopeTo / safetySlopeScaleDeg;
        return t * (1 + k * k);
    }
  }

  /// Lower bound on the objective cost of covering [horizontalM] metres of
  /// ground in a straight line — the admissible A* heuristic.
  double lowerBound(double horizontalM) {
    switch (objective) {
      case RouteObjective.fastest:
      case RouteObjective.safest:
        return horizontalM / eva.maxSpeed;
      case RouteObjective.efficient:
        return horizontalM * _minEnergyPerMeter;
    }
  }
}
