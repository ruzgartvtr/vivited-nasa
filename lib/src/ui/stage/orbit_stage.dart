import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../science/mars_constants.dart';
import '../../state/app_state.dart';
import '../../theme/vivited_theme.dart';

/// Mars from orbit: the Viking MDIM 2.1 colour mosaic wrapped on a sphere
/// (orthographic), with every NASA landing site and its MOLA elevation.
/// Drag to turn the planet.
class OrbitStage extends ConsumerStatefulWidget {
  const OrbitStage({super.key});

  @override
  ConsumerState<OrbitStage> createState() => _OrbitStageState();
}

class _OrbitStageState extends ConsumerState<OrbitStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  double _lon = jezeroLon - 8, _lat = 14;
  bool _touched = false;

  @override
  void dispose() {
    _arrive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataProvider);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > 900;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => setState(() {
            _touched = true;
            _lon -= d.delta.dx * 0.25;
            _lat = (_lat + d.delta.dy * 0.25).clamp(-80.0, 80.0);
          }),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: AnimatedBuilder(
              animation: _arrive,
              builder: (context, _) {
                // The planet turns to bring Jezero to the meridian on arrival.
                final t = Curves.easeOutCubic.transform(_arrive.value);
                final lon = _touched ? _lon : _lon - 110 * (1 - t);
                return CustomPaint(
                  painter: _GlobePainter(
                    image: data.globe,
                    relief: data.relief,
                    centerLon: lon,
                    centerLat: _lat,
                    reveal: _touched ? 1 : t,
                    // Leave room for the intro copy on wide screens.
                    // The planet sits against the right edge, slightly
                    // cropped, clear of the copy at lower left.
                    offsetX: wide
                        ? math.max(
                            0.0,
                            0.5 -
                                0.8 *
                                    0.42 *
                                    math.min(box.maxWidth, box.maxHeight) /
                                    box.maxWidth,
                          )
                        : 0,
                    offsetY: wide ? -0.06 : -0.14,
                    scale: wide ? 0.42 : 0.36,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.image,
    required this.relief,
    required this.centerLon,
    required this.centerLat,
    required this.reveal,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
  });

  final ui.Image image;
  final GlobalRelief relief;
  final double centerLon, centerLat, reveal, offsetX, offsetY, scale;

  static const _nLat = 48, _nLon = 96;
  static const _deg = math.pi / 180;

  /// Rotates a lat/lon to view space: x right, y up, z towards the viewer.
  (double, double, double) _view(double lat, double lon) {
    final p = lat * _deg, l = (lon - centerLon) * _deg;
    final x = math.cos(p) * math.sin(l);
    final y = math.sin(p);
    final z = math.cos(p) * math.cos(l);
    final c = math.cos(centerLat * _deg), s = math.sin(centerLat * _deg);
    return (x, y * c - z * s, y * s + z * c);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) * scale;
    final c = Offset(size.width * (0.5 + offsetX), size.height * (0.5 + offsetY));

    final cols = _nLon + 1, rows = _nLat + 1;
    final pos = Float32List(rows * cols * 2);
    final tex = Float32List(rows * cols * 2);
    final col = Int32List(rows * cols);
    final depth = Float32List(rows * cols);
    // Sun-ward direction in view space (upper left, slightly towards viewer).
    const sx = -0.55, sy = 0.45, sz = 0.70;
    for (var j = 0; j < rows; j++) {
      final lat = 90.0 - 180.0 * j / _nLat;
      for (var i = 0; i < cols; i++) {
        final lon = -180.0 + 360.0 * i / _nLon;
        final (x, y, z) = _view(lat, lon);
        final k = j * cols + i;
        pos[k * 2] = c.dx + x * r;
        pos[k * 2 + 1] = c.dy - y * r;
        tex[k * 2] = i / _nLon * image.width;
        tex[k * 2 + 1] = j / _nLat * image.height;
        depth[k] = z;
        final lit = (x * sx + y * sy + z * sz).clamp(0.0, 1.0);
        final v = (255 * (0.10 + 0.90 * math.pow(lit, 0.8))).round().clamp(0, 255);
        col[k] = 0xFF000000 | (v << 16) | (v << 8) | v;
      }
    }
    final idx = <int>[];
    for (var j = 0; j < _nLat; j++) {
      for (var i = 0; i < _nLon; i++) {
        final a = j * cols + i, b = a + 1, d = a + cols, e = d + 1;
        // Keep quads facing the viewer.
        if (depth[a] + depth[b] + depth[d] + depth[e] <= 0) continue;
        idx.addAll([a, b, d, b, e, d]);
      }
    }
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final verts = ui.Vertices.raw(
      ui.VertexMode.triangles,
      pos,
      textureCoordinates: tex,
      colors: col,
      indices: Uint16List.fromList(idx),
    );
    canvas.drawVertices(
      verts,
      BlendMode.modulate,
      Paint()
        ..shader = ui.ImageShader(
          image,
          TileMode.clamp,
          TileMode.clamp,
          Matrix4.identity().storage,
          filterQuality: FilterQuality.medium,
        ),
    );
    verts.dispose();
    canvas.restore();
    // Limb.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = VColors.bone.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Landing sites. Jezero is laid out first so that no other label may
    // collide with it; labels flip to the left of their mark near the edge.
    final placed = <Rect>[];
    final sites = [...LandingSite.nasa]
      ..sort((a, b) => (b.name == 'Perseverance' ? 1 : 0)
          .compareTo(a.name == 'Perseverance' ? 1 : 0));
    for (final s in sites) {
      final (x, y, z) = _view(s.lat, s.lon);
      if (z <= 0.08) continue;
      final o = Offset(c.dx + x * r, c.dy - y * r);
      final jezero = s.name == 'Perseverance';
      final alpha = (reveal * (jezero ? 1 : 0.9)).clamp(0.0, 1.0);
      final color = (jezero ? VColors.oxide : VColors.bone).withValues(alpha: alpha);
      if (jezero) {
        canvas.drawCircle(
          o,
          11,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        canvas.drawCircle(o, 3.2, Paint()..color = color);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: o, width: 5, height: 5),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      final elev = relief.elevationAt(s.lat, s.lon);
      final name = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: jezero ? 'JEZERO CRATER\n' : '${s.name.toUpperCase()}\n',
              style: VType.label(color: color, size: jezero ? 10 : 8.5),
            ),
            TextSpan(
              text: jezero
                  ? 'Perseverance · 2021 · ${elev.round()} m'
                  : '${s.year} · ${elev.round()} m',
              style: VType.data(9, color: color.withValues(alpha: alpha * 0.75)),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final gap = jezero ? 18.0 : 9.0;
      var at = o + Offset(gap, -name.height / 2);
      if (at.dx + name.width > size.width - 8) {
        at = o + Offset(-gap - name.width, -name.height / 2);
      }
      final box = (at & name.size).inflate(3);
      final offCanvas = o.dx > size.width - 8 || at.dx < 8;
      if (!jezero && (offCanvas || placed.any(box.overlaps))) continue;
      placed.add(box);
      name.paint(canvas, at);
    }
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      old.centerLon != centerLon ||
      old.centerLat != centerLat ||
      old.reveal != reveal ||
      old.scale != scale ||
      old.offsetX != offsetX;
}
