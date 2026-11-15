import 'dart:math' as math;
import 'dart:typed_data';

import '../science/mars_constants.dart';

/// A georeferenced elevation raster in the USGS equirectangular projection
/// (lat_ts = 0, lon0 = 0, sphere of radius R): x = R·λ, y = R·φ.
///
/// Rows run north → south, columns west → east. Because the projection's
/// standard parallel is the equator, a pixel spans [pixelSizeM] north–south
/// but only `pixelSizeM · cos(lat)` east–west on the ground; every metric
/// computation here uses the true ground spacing.
class TerrainGrid {
  TerrainGrid({
    required this.rows,
    required this.cols,
    required this.elevation,
    required this.upperLeftX,
    required this.upperLeftY,
    required this.pixelSizeM,
    this.radiusM = marsRadiusM,
  }) : assert(elevation.length == rows * cols) {
    _cellDx = Float64List(rows);
    for (var r = 0; r < rows; r++) {
      _cellDx[r] = pixelSizeM * math.cos(rowToLat(r + 0.0) * _deg);
    }
    var lo = double.infinity, hi = -double.infinity;
    for (final z in elevation) {
      if (z < lo) lo = z;
      if (z > hi) hi = z;
    }
    minElevation = lo;
    maxElevation = hi;
  }

  /// Decodes the app's compact DEM asset (uint16 LE, see
  /// tool/process_terrain.py) using its JSON metadata.
  factory TerrainGrid.fromAsset(ByteData bytes, Map<String, dynamic> meta) {
    final rows = meta['rows'] as int, cols = meta['cols'] as int;
    if (bytes.lengthInBytes != rows * cols * 2) {
      throw FormatException(
        'DEM size mismatch: expected ${rows * cols * 2} bytes, '
        'got ${bytes.lengthInBytes}',
      );
    }
    final offset = (meta['elevOffsetM'] as num).toDouble();
    final scale = (meta['elevScaleM'] as num).toDouble();
    final elev = Float32List(rows * cols);
    for (var i = 0; i < elev.length; i++) {
      elev[i] = offset + scale * bytes.getUint16(i * 2, Endian.little);
    }
    return TerrainGrid(
      rows: rows,
      cols: cols,
      elevation: elev,
      upperLeftX: (meta['upperLeftX'] as num).toDouble(),
      upperLeftY: (meta['upperLeftY'] as num).toDouble(),
      pixelSizeM: (meta['pixelSizeM'] as num).toDouble(),
      radiusM: (meta['radiusM'] as num).toDouble(),
    );
  }

  /// Builds an analytic surface for tests: `z = f(xEastM, yNorthM)` with the
  /// origin at the south-west corner. Placed on the equator so the grid is
  /// metrically square.
  factory TerrainGrid.synthetic({
    required int rows,
    required int cols,
    double pixelSizeM = 20,
    required double Function(double xEastM, double yNorthM) height,
  }) {
    final elev = Float32List(rows * cols);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        elev[r * cols + c] =
            height(c * pixelSizeM, (rows - 1 - r) * pixelSizeM);
      }
    }
    return TerrainGrid(
      rows: rows,
      cols: cols,
      elevation: elev,
      upperLeftX: 0,
      upperLeftY: rows * pixelSizeM / 2,
      pixelSizeM: pixelSizeM,
    );
  }

  static const double _deg = math.pi / 180.0;

  final int rows;
  final int cols;

  /// Elevation above the MOLA areoid (m), row-major from the NW corner.
  final Float32List elevation;
  final double upperLeftX;
  final double upperLeftY;
  final double pixelSizeM;
  final double radiusM;

  late final Float64List _cellDx;
  late final double minElevation;
  late final double maxElevation;

  Float32List? _slope;
  Float32List? _gradEast;
  Float32List? _gradNorth;

  int get cellCount => rows * cols;

  double get west => upperLeftX / radiusM / _deg;
  double get north => upperLeftY / radiusM / _deg;
  double get east => (upperLeftX + cols * pixelSizeM) / radiusM / _deg;
  double get south => (upperLeftY - rows * pixelSizeM) / radiusM / _deg;

  /// North–south ground spacing between cell centres (m).
  double get cellDy => pixelSizeM;

  /// East–west ground spacing between cell centres in [row] (m).
  double cellDx(int row) => _cellDx[row];

  /// Smallest east–west spacing in the grid (m); a safe lower bound for
  /// admissible routing heuristics.
  double get minCellDx => math.min(_cellDx.first, _cellDx.last);

  // ---- Georeferencing: cell centres sit at integer (row, col). -------------

  double colToLon(double col) =>
      (upperLeftX + (col + 0.5) * pixelSizeM) / radiusM / _deg;
  double rowToLat(double row) =>
      (upperLeftY - (row + 0.5) * pixelSizeM) / radiusM / _deg;
  double lonToCol(double lon) =>
      (lon * _deg * radiusM - upperLeftX) / pixelSizeM - 0.5;
  double latToRow(double lat) =>
      (upperLeftY - lat * _deg * radiusM) / pixelSizeM - 0.5;

  bool containsLatLon(double lat, double lon) {
    final r = latToRow(lat), c = lonToCol(lon);
    return r >= 0 && c >= 0 && r <= rows - 1 && c <= cols - 1;
  }

  int index(int row, int col) => row * cols + col;
  int rowOf(int index) => index ~/ cols;
  int colOf(int index) => index % cols;

  /// Nearest cell index for a coordinate, or −1 outside the grid.
  int cellAt(double lat, double lon) {
    final r = latToRow(lat).round(), c = lonToCol(lon).round();
    if (r < 0 || c < 0 || r >= rows || c >= cols) return -1;
    return r * cols + c;
  }

  double latOfCell(int index) => rowToLat(rowOf(index) + 0.0);
  double lonOfCell(int index) => colToLon(colOf(index) + 0.0);

  // ---- Sampling -------------------------------------------------------------

  double _bilinear(Float32List a, double row, double col) {
    final r = row.clamp(0.0, rows - 1.0), c = col.clamp(0.0, cols - 1.0);
    final r0 = math.min(r.floor(), rows - 2), c0 = math.min(c.floor(), cols - 2);
    final fr = r - r0, fc = c - c0;
    final i = r0 * cols + c0;
    return (a[i] * (1 - fc) + a[i + 1] * fc) * (1 - fr) +
        (a[i + cols] * (1 - fc) + a[i + cols + 1] * fc) * fr;
  }

  /// Bilinearly interpolated elevation (m); NaN outside the grid.
  double elevationAt(double lat, double lon) {
    if (!containsLatLon(lat, lon)) return double.nan;
    return _bilinear(elevation, latToRow(lat), lonToCol(lon));
  }

  /// Bilinearly interpolated terrain slope (deg); NaN outside the grid.
  double slopeAt(double lat, double lon) {
    if (!containsLatLon(lat, lon)) return double.nan;
    return _bilinear(slopeDeg, latToRow(lat), lonToCol(lon));
  }

  // ---- Derived surfaces -----------------------------------------------------

  /// Terrain slope magnitude per cell in degrees (Horn 1981, 3×3 kernel).
  Float32List get slopeDeg {
    _computeGradients();
    return _slope!;
  }

  /// ∂z/∂east per cell (m/m).
  Float32List get gradEast {
    _computeGradients();
    return _gradEast!;
  }

  /// ∂z/∂north per cell (m/m).
  Float32List get gradNorth {
    _computeGradients();
    return _gradNorth!;
  }

  void _computeGradients() {
    if (_slope != null) return;
    final s = Float32List(cellCount);
    final ge = Float32List(cellCount);
    final gn = Float32List(cellCount);
    final z = elevation;
    for (var r = 0; r < rows; r++) {
      final rn = r == 0 ? 0 : r - 1; // row to the north
      final rs = r == rows - 1 ? r : r + 1; // row to the south
      final dx = _cellDx[r];
      final nRows = rs - rn; // 1 on edges, 2 inside
      for (var c = 0; c < cols; c++) {
        final cw = c == 0 ? 0 : c - 1;
        final ce = c == cols - 1 ? c : c + 1;
        final nCols = ce - cw;
        final zNw = z[rn * cols + cw], zN = z[rn * cols + c];
        final zNe = z[rn * cols + ce];
        final zW = z[r * cols + cw], zE = z[r * cols + ce];
        final zSw = z[rs * cols + cw], zS = z[rs * cols + c];
        final zSe = z[rs * cols + ce];
        final dzdx = ((zNe + 2 * zE + zSe) - (zNw + 2 * zW + zSw)) /
            (4 * nCols * dx);
        final dzdy = ((zNw + 2 * zN + zNe) - (zSw + 2 * zS + zSe)) /
            (4 * nRows * pixelSizeM);
        final i = r * cols + c;
        ge[i] = dzdx;
        gn[i] = dzdy;
        s[i] = math.atan(math.sqrt(dzdx * dzdx + dzdy * dzdy)) / _deg;
      }
    }
    _slope = s;
    _gradEast = ge;
    _gradNorth = gn;
  }

  /// Fraction of cells whose slope falls in each bin of [edgesDeg]
  /// (n edges → n + 1 bins).
  List<double> slopeHistogram(List<double> edgesDeg) {
    final counts = List<int>.filled(edgesDeg.length + 1, 0);
    for (final v in slopeDeg) {
      var b = 0;
      while (b < edgesDeg.length && v >= edgesDeg[b]) {
        b++;
      }
      counts[b]++;
    }
    return [for (final n in counts) n / cellCount];
  }
}
