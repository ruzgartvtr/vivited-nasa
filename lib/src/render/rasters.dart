import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../data/data_repository.dart';
import '../data/terrain.dart';
import '../routing/pathfinder.dart';
import '../science/hazard.dart';
import '../science/mars_time.dart';

/// Piecewise-linear colour ramp over [0, 1].
class ColorRamp {
  const ColorRamp(this.stops, this.colors);
  final List<double> stops;
  final List<int> colors; // 0xRRGGBB

  /// Opaque colour at [t] (0–1), for legends.
  ui.Color color(double t) {
    final px = Uint8List(4);
    write(px, 0, t, 255);
    return ui.Color.fromARGB(255, px[0], px[1], px[2]);
  }

  /// Writes the premultiplied RGBA for [t] with opacity [alpha] (0–255).
  void write(Uint8List out, int offset, double t, int alpha) {
    final x = t.isNaN ? 0.0 : t.clamp(0.0, 1.0);
    var i = 1;
    while (i < stops.length - 1 && x > stops[i]) {
      i++;
    }
    final f = (x - stops[i - 1]) / (stops[i] - stops[i - 1]);
    final a = colors[i - 1], b = colors[i];
    final r = ((a >> 16) & 255) + (((b >> 16) & 255) - ((a >> 16) & 255)) * f;
    final g = ((a >> 8) & 255) + (((b >> 8) & 255) - ((a >> 8) & 255)) * f;
    final bl = (a & 255) + ((b & 255) - (a & 255)) * f;
    out[offset] = (r * alpha) ~/ 255;
    out[offset + 1] = (g * alpha) ~/ 255;
    out[offset + 2] = (bl * alpha) ~/ 255;
    out[offset + 3] = alpha;
  }

  int rgbAt(double t) {
    final tmp = Uint8List(4);
    write(tmp, 0, t, 255);
    return (tmp[0] << 16) | (tmp[1] << 8) | tmp[2];
  }

  /// Hypsometric tint: slate lowlands through oxide mid-slopes to bone rims.
  static const elevation = ColorRamp(
    [0, 0.18, 0.4, 0.62, 0.82, 1],
    [0x26323C, 0x4A3B36, 0x8A4E33, 0xC98450, 0xE8C99A, 0xF6EFE2],
  );

  /// Night-IR brightness: cold dust to warm rock.
  static const thermal = ColorRamp(
    [0, 0.3, 0.55, 0.78, 1],
    [0x10142B, 0x4B2A6B, 0xB5435E, 0xF2994A, 0xFBEBB5],
  );

  /// Solar exposure relative to level ground: less (cool) to more (warm).
  static const solar = ColorRamp(
    [0, 0.5, 1],
    [0x3E7FB8, 0xEFE8DC, 0xF2A93B],
  );

  /// Walk-back time: near (cool) to far (signal).
  static const walkBack = ColorRamp(
    [0, 0.35, 0.7, 1],
    [0x9FD3B0, 0xE9C46A, 0xF08A3C, 0xE5482F],
  );
}

Future<ui.Image> _toImage(Uint8List rgba, int w, int h) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

/// Builds map overlays from the terrain grid. Everything here is computed
/// from the measured DTM in Dart; nothing is pre-rendered.
class TerrainRasters {
  TerrainRasters(this.data);

  final AppData data;
  TerrainGrid get g => data.terrain;

  static const double _deg = math.pi / 180;

  /// Shaded relief: hypsometric tint × hillshade, with 25 m contours and
  /// bolder 100 m index contours.
  Future<ui.Image> relief() async {
    final rows = g.rows, cols = g.cols;
    final out = Uint8List(rows * cols * 4);
    final z = g.elevation, ge = g.gradEast, gn = g.gradNorth;
    final lo = g.minElevation, span = g.maxElevation - g.minElevation;
    // Cartographic convention: light from the north-west at 45°.
    final sx = -math.sin(45 * _deg) * math.cos(45 * _deg);
    final sy = math.cos(45 * _deg) * math.cos(45 * _deg);
    final sz = math.sin(45 * _deg);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c, o = i * 4;
        // Square-root stretch: most of the walkable crater floor lies in
        // the lowest fifth of the relief and would otherwise share one tint.
        ColorRamp.elevation
            .write(out, o, math.sqrt((z[i] - lo) / span), 255);
        // Exaggerate gradients ×2 so the gentle crater floor still reads.
        final nx = -ge[i] * 2, ny = -gn[i] * 2;
        final inv = 1 / math.sqrt(nx * nx + ny * ny + 1);
        var shade = (nx * sx + ny * sy + sz) * inv;
        shade = 0.35 + 0.9 * shade.clamp(0.0, 1.0);
        // Anti-aliased contours: darkness falls off with ground distance to
        // the nearest contour level, measured in cells.
        final zi = z[i];
        final grad =
            math.max(math.sqrt(ge[i] * ge[i] + gn[i] * gn[i]), 0.004);
        final d25 = (zi - (zi / 25).round() * 25).abs() / grad / g.pixelSizeM;
        if (d25 < 1.0) {
          final d100 =
              (zi - (zi / 100).round() * 100).abs() / grad / g.pixelSizeM;
          final index = d100 < 1.0;
          final w = 1.0 - (index ? d100 : d25);
          shade *= 1 - w * (index ? 0.6 : 0.3);
        }
        out[o] = (out[o] * shade).round().clamp(0, 255);
        out[o + 1] = (out[o + 1] * shade).round().clamp(0, 255);
        out[o + 2] = (out[o + 2] * shade).round().clamp(0, 255);
      }
      if (r % 256 == 255) await Future<void>.delayed(Duration.zero);
    }
    return _toImage(out, cols, rows);
  }

  static const _hazardRgb = <int>[
    0x9FD3B0,
    0xE9C46A,
    0xF08A3C,
    0xE5482F,
    0x6B1525,
  ];
  static const _hazardAlpha = <int>[0, 150, 185, 210, 235];

  /// Slope hazard classes. Nominal ground is left transparent so the imagery
  /// stays readable.
  Future<ui.Image> hazard() async {
    final rows = g.rows, cols = g.cols;
    final out = Uint8List(rows * cols * 4);
    final s = g.slopeDeg;
    for (var i = 0; i < s.length; i++) {
      final k = HazardClass.fromSlope(s[i]).index;
      final a = _hazardAlpha[k];
      if (a == 0) continue;
      final rgb = _hazardRgb[k], o = i * 4;
      out[o] = ((rgb >> 16) & 255) * a ~/ 255;
      out[o + 1] = ((rgb >> 8) & 255) * a ~/ 255;
      out[o + 2] = (rgb & 255) * a ~/ 255;
      out[o + 3] = a;
      if (i % (cols * 256) == 0) await Future<void>.delayed(Duration.zero);
    }
    return _toImage(out, cols, rows);
  }

  /// THEMIS night-time infrared, colourised. Relative brightness only: the
  /// mosaic is contrast-normalised, so no temperature scale is implied.
  Future<ui.Image> thermal() {
    final t = data.themis;
    final out = Uint8List(t.width * t.height * 4);
    var lo = 255, hi = 0;
    for (final v in t.data) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final span = math.max(1, hi - lo);
    for (var i = 0; i < t.data.length; i++) {
      ColorRamp.thermal.write(out, i * 4, (t.data[i] - lo) / span, 225);
    }
    return _toImage(out, t.width, t.height);
  }

  /// Sun unit vector (east, north, up) for a season and local true time.
  static (double, double, double) sunVector(double ls, double lat, double ltst) {
    final el = MarsTime.sunElevation(ls: ls, latDeg: lat, ltst: ltst) * _deg;
    final az = MarsTime.sunAzimuth(ls: ls, latDeg: lat, ltst: ltst) * _deg;
    return (
      math.cos(el) * math.sin(az),
      math.cos(el) * math.cos(az),
      math.sin(el),
    );
  }

  /// Cosine-weighted hours of direct sun per sol on each cell's own slope
  /// (self-shading only; shadows cast by distant terrain are not included).
  /// Returned at 1/[stride] resolution along with the value for flat ground.
  ({Float32List hours, int rows, int cols, double flat}) solarExposure(
    double ls, {
    int stride = 4,
  }) {
    final rows = g.rows ~/ stride, cols = g.cols ~/ stride;
    final hours = Float32List(rows * cols);
    final lat = (g.north + g.south) / 2;
    final rise = MarsTime.sunriseLtst(ls: ls, latDeg: lat);
    final set = MarsTime.sunsetLtst(ls: ls, latDeg: lat);
    const steps = 28;
    final dt = (set - rise) / steps;
    var flat = 0.0;
    final ge = g.gradEast, gn = g.gradNorth;
    for (var k = 0; k < steps; k++) {
      final (sx, sy, sz) = sunVector(ls, lat, rise + (k + 0.5) * dt);
      if (sz <= 0) continue;
      flat += sz * dt;
      for (var r = 0; r < rows; r++) {
        final base = (r * stride) * g.cols;
        for (var c = 0; c < cols; c++) {
          final i = base + c * stride;
          final nx = -ge[i], ny = -gn[i];
          final cosI =
              (nx * sx + ny * sy + sz) / math.sqrt(nx * nx + ny * ny + 1);
          if (cosI > 0) hours[r * cols + c] += cosI * dt;
        }
      }
    }
    return (hours: hours, rows: rows, cols: cols, flat: flat);
  }

  /// Solar exposure relative to level ground: sun-facing slopes warm,
  /// shaded slopes cool, level ground left clear.
  Future<ui.Image> solar(double ls) {
    final e = solarExposure(ls, stride: 2);
    final out = Uint8List(e.rows * e.cols * 4);
    for (var i = 0; i < e.hours.length; i++) {
      final ratio = e.flat <= 0 ? 1.0 : e.hours[i] / e.flat;
      final dev = (ratio - 1).clamp(-solarRange, solarRange) / solarRange;
      final alpha = (math.min(1.0, dev.abs() * 1.6) * 215).round();
      if (alpha < 8) continue;
      ColorRamp.solar.write(out, i * 4, 0.5 + dev / 2, alpha);
    }
    return _toImage(out, e.cols, e.rows);
  }

  /// Half-width of the solar exposure scale: ±30 % of level ground.
  static const double solarRange = 0.3;

  /// Shadow mask at a given season and local true solar time: self-shadowed
  /// slopes plus shadows cast by terrain (ray-marched towards the sun).
  ({Uint8List mask, int rows, int cols, double sunElevation}) shadowMask(
    double ls,
    double ltst, {
    int stride = 4,
    double maxReachM = 9000,
  }) {
    final rows = g.rows ~/ stride, cols = g.cols ~/ stride;
    final mask = Uint8List(rows * cols);
    final lat = (g.north + g.south) / 2;
    final el = MarsTime.sunElevation(ls: ls, latDeg: lat, ltst: ltst);
    if (el <= 0) {
      mask.fillRange(0, mask.length, 1);
      return (mask: mask, rows: rows, cols: cols, sunElevation: el);
    }
    final (sx, sy, sz) = sunVector(ls, lat, ltst);
    final horiz = math.sqrt(sx * sx + sy * sy);
    final step = g.pixelSizeM * stride; // metres per march step
    final rise = step * sz / math.max(horiz, 1e-6); // ray climb per step
    // Grid-cell increments per step (rows grow southwards).
    final dcol = horiz < 1e-6 ? 0.0 : (sx / horiz) * step / g.cellDx(g.rows ~/ 2);
    final drow = horiz < 1e-6 ? 0.0 : -(sy / horiz) * step / g.cellDy;
    final maxSteps = (maxReachM / step).ceil();
    final z = g.elevation, ge = g.gradEast, gn = g.gradNorth;
    final zMax = g.maxElevation;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gr = r * stride, gc = c * stride;
        final i = gr * g.cols + gc;
        if (-ge[i] * sx - gn[i] * sy + sz <= 0) {
          mask[r * cols + c] = 1;
          continue;
        }
        var h = z[i] + 2.0; // eye of the ray just above the surface
        var fr = gr.toDouble(), fc = gc.toDouble();
        for (var k = 0; k < maxSteps; k++) {
          fr += drow;
          fc += dcol;
          h += rise;
          if (h > zMax) break;
          final rr = fr.round(), cc = fc.round();
          if (rr < 0 || cc < 0 || rr >= g.rows || cc >= g.cols) break;
          if (z[rr * g.cols + cc] > h) {
            mask[r * cols + c] = 1;
            break;
          }
        }
      }
    }
    return (mask: mask, rows: rows, cols: cols, sunElevation: el);
  }

  Future<ui.Image> illumination(double ls, double ltst) {
    final s = shadowMask(ls, ltst);
    final out = Uint8List(s.rows * s.cols * 4);
    for (var i = 0; i < s.mask.length; i++) {
      if (s.mask[i] == 0) continue;
      final o = i * 4;
      // Premultiplied deep indigo.
      out[o] = 6;
      out[o + 1] = 8;
      out[o + 2] = 20;
      out[o + 3] = 185;
    }
    return _toImage(out, s.cols, s.rows);
  }

  /// Walk-back isochrones: 5-minute bands of fastest return time to base,
  /// with a line at each band edge and a heavier line every 15 minutes.
  Future<ui.Image> walkBack(CostField field, {double bandS = 300}) async {
    final rows = g.rows, cols = g.cols;
    final out = Uint8List(rows * cols * 4);
    final cost = field.cost;
    final horizon = field.maxCost;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final t = cost[i];
        if (!t.isFinite) continue;
        final band = (t / bandS).floor();
        var edge = 0; // 1 = band edge, 2 = 15-minute edge
        for (final j in [if (c + 1 < cols) i + 1, if (r + 1 < rows) i + cols]) {
          final n = cost[j];
          if (!n.isFinite) continue;
          final nb = (n / bandS).floor();
          if (nb == band) continue;
          final hi = math.max(nb, band);
          edge = math.max(edge, hi % 3 == 0 ? 2 : 1);
        }
        ColorRamp.walkBack.write(
          out,
          i * 4,
          (band + 0.5) * bandS / horizon,
          edge == 2 ? 240 : (edge == 1 ? 130 : 46),
        );
      }
      if (r % 256 == 255) await Future<void>.delayed(Duration.zero);
    }
    return _toImage(out, cols, rows);
  }
}
