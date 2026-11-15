import 'dart:math' as math;
import 'dart:typed_data';

import '../data/terrain.dart';
import 'cost_model.dart';
import 'min_heap.dart';

/// Search strategy for point-to-point routing.
enum SearchAlgorithm {
  /// A* with an admissible straight-line bound. Same optimum as Dijkstra,
  /// far fewer expansions.
  aStar,

  /// Uniform-cost search. Used as the reference implementation in tests and
  /// for cost fields.
  dijkstra,
}

class PathResult {
  const PathResult({
    required this.cells,
    required this.cost,
    required this.expanded,
  });

  /// Grid cell indices from start to goal inclusive.
  final List<int> cells;

  /// Total objective cost (seconds or joules, depending on the objective).
  final double cost;

  /// Number of nodes expanded — a measure of search effort.
  final int expanded;
}

/// Cost-to-base field produced by a bounded Dijkstra sweep.
class CostField {
  CostField({
    required this.grid,
    required this.origin,
    required this.cost,
    required this.maxCost,
    required this.reached,
  });

  final TerrainGrid grid;
  final int origin;

  /// Per-cell cost; `double.infinity` where unreached within [maxCost].
  final Float32List cost;
  final double maxCost;
  final int reached;

  double at(int cell) => cell < 0 ? double.infinity : cost[cell];

  double atLatLon(double lat, double lon) => at(grid.cellAt(lat, lon));
}

/// Native Dart A* / Dijkstra over an 8-connected elevation grid.
///
/// Edge costs are anisotropic (uphill ≠ downhill) and come from
/// [RouteCostModel]. Scratch buffers are reused between searches using a
/// generation stamp, so repeated planning does not re-allocate ~30 MB.
class GridPathfinder {
  GridPathfinder(this.grid)
      : _g = Float64List(grid.cellCount),
        _parent = Int32List(grid.cellCount),
        _stamp = Uint32List(grid.cellCount),
        _closed = Uint32List(grid.cellCount);

  final TerrainGrid grid;
  final Float64List _g;
  final Int32List _parent;
  final Uint32List _stamp;
  final Uint32List _closed;
  final MinHeap _open = MinHeap(1 << 14);
  int _generation = 0;
  Future<void> _lock = Future<void>.value();

  /// Serialises asynchronous searches: they share scratch buffers, so two
  /// interleaved searches would corrupt each other.
  Future<T> _exclusive<T>(Future<T> Function() body) {
    final previous = _lock;
    final next = previous.then((_) => body());
    _lock = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  static const List<int> _dr = [-1, -1, -1, 0, 0, 1, 1, 1];
  static const List<int> _dc = [-1, 0, 1, -1, 1, -1, 0, 1];

  double _stepLength(int row, int dr, int dc) {
    final dx = grid.cellDx(row) * dc;
    final dy = grid.cellDy * dr;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Straight-line ground distance between two cells (m), using the smallest
  /// east–west spacing so that it never over-estimates.
  double _groundDistance(int a, int b) {
    final dr = (grid.rowOf(a) - grid.rowOf(b)) * grid.cellDy;
    final dc = (grid.colOf(a) - grid.colOf(b)) * grid.minCellDx;
    return math.sqrt(dr * dr + dc * dc);
  }

  /// Optimal path from [start] to [goal], or `null` if none exists.
  PathResult? findPath(
    int start,
    int goal,
    RouteCostModel model, {
    SearchAlgorithm algorithm = SearchAlgorithm.aStar,
  }) {
    final search = _Search(this, start, goal, model, algorithm);
    while (!search.step(1 << 30)) {}
    return search.result;
  }

  /// Like [findPath] but yields to the event loop every [sliceNodes]
  /// expansions so the UI stays responsive on the web's single thread.
  Future<PathResult?> findPathAsync(
    int start,
    int goal,
    RouteCostModel model, {
    SearchAlgorithm algorithm = SearchAlgorithm.aStar,
    int sliceNodes = 60000,
    bool Function()? isCancelled,
  }) =>
      _exclusive(() async {
        if (isCancelled?.call() ?? false) return null;
        final search = _Search(this, start, goal, model, algorithm);
        while (!search.step(sliceNodes)) {
          await Future<void>.delayed(Duration.zero);
          if (isCancelled?.call() ?? false) return null;
        }
        return search.result;
      });

  /// Cost for every cell to *reach* [origin] (not from it): the walk-back
  /// field. Runs Dijkstra outward from [origin] over reversed edges and stops
  /// at [maxCost].
  Future<CostField> costToOrigin(
    int origin,
    RouteCostModel model, {
    required double maxCost,
    int sliceNodes = 80000,
    bool Function()? isCancelled,
  }) =>
      _exclusive(() => _costToOrigin(
            origin,
            model,
            maxCost: maxCost,
            sliceNodes: sliceNodes,
            isCancelled: isCancelled,
          ));

  Future<CostField> _costToOrigin(
    int origin,
    RouteCostModel model, {
    required double maxCost,
    required int sliceNodes,
    bool Function()? isCancelled,
  }) async {
    final cols = grid.cols, rows = grid.rows;
    final out = Float32List(grid.cellCount)
      ..fillRange(0, grid.cellCount, double.infinity);
    final gen = ++_generation;
    _open.clear();
    _g[origin] = 0;
    _stamp[origin] = gen;
    _open.push(0, origin);
    var reached = 0, sinceYield = 0;
    while (_open.isNotEmpty) {
      final d = _open.minPriority;
      final u = _open.pop();
      if (_closed[u] == gen) continue;
      _closed[u] = gen;
      if (d > maxCost) break;
      out[u] = d;
      reached++;
      final ur = u ~/ cols, uc = u % cols;
      for (var k = 0; k < 8; k++) {
        final r = ur + _dr[k], c = uc + _dc[k];
        if (r < 0 || c < 0 || r >= rows || c >= cols) continue;
        final v = r * cols + c;
        if (_closed[v] == gen) continue;
        // Reverse edge: the walker moves v → u.
        final w = model.edgeCost(v, u, _stepLength(ur, _dr[k], _dc[k]));
        if (w == double.infinity) continue;
        final nd = d + w;
        if (_stamp[v] != gen || nd < _g[v]) {
          _g[v] = nd;
          _stamp[v] = gen;
          _open.push(nd, v);
        }
      }
      if (++sinceYield >= sliceNodes) {
        sinceYield = 0;
        await Future<void>.delayed(Duration.zero);
        if (isCancelled?.call() ?? false) break;
      }
    }
    return CostField(
      grid: grid,
      origin: origin,
      cost: out,
      maxCost: maxCost,
      reached: reached,
    );
  }
}

/// One resumable point-to-point search.
class _Search {
  _Search(this.pf, this.start, this.goal, this.model, this.algorithm)
      : gen = ++pf._generation {
    pf._open.clear();
    if (start < 0 || goal < 0 || model.isBlocked(goal)) {
      done = true;
      return;
    }
    pf._g[start] = 0;
    pf._stamp[start] = gen;
    pf._parent[start] = -1;
    pf._open.push(_h(start), start);
  }

  final GridPathfinder pf;
  final int start;
  final int goal;
  final RouteCostModel model;
  final SearchAlgorithm algorithm;
  final int gen;
  bool done = false;
  int expanded = 0;
  PathResult? result;

  double _h(int cell) => algorithm == SearchAlgorithm.aStar
      ? model.lowerBound(pf._groundDistance(cell, goal))
      : 0.0;

  /// Expands up to [budget] nodes. Returns true when the search is finished.
  bool step(int budget) {
    if (done) return true;
    final grid = pf.grid;
    final cols = grid.cols, rows = grid.rows;
    final g = pf._g, stamp = pf._stamp, closed = pf._closed, open = pf._open;
    var n = 0;
    while (open.isNotEmpty) {
      final u = open.pop();
      if (closed[u] == gen) continue;
      closed[u] = gen;
      expanded++;
      if (u == goal) {
        final cells = <int>[];
        for (var c = goal; c != -1; c = pf._parent[c]) {
          cells.add(c);
        }
        result = PathResult(
          cells: cells.reversed.toList(growable: false),
          cost: g[goal],
          expanded: expanded,
        );
        done = true;
        return true;
      }
      final gu = g[u];
      final ur = u ~/ cols, uc = u % cols;
      for (var k = 0; k < 8; k++) {
        final r = ur + GridPathfinder._dr[k], c = uc + GridPathfinder._dc[k];
        if (r < 0 || c < 0 || r >= rows || c >= cols) continue;
        final v = r * cols + c;
        if (closed[v] == gen) continue;
        final w = model.edgeCost(
          u,
          v,
          pf._stepLength(ur, GridPathfinder._dr[k], GridPathfinder._dc[k]),
        );
        if (w == double.infinity) continue;
        final ng = gu + w;
        if (stamp[v] != gen || ng < g[v]) {
          g[v] = ng;
          stamp[v] = gen;
          pf._parent[v] = u;
          open.push(ng + _h(v), v);
        }
      }
      if (++n >= budget) return false;
    }
    done = true; // open set exhausted: no path
    return true;
  }
}
