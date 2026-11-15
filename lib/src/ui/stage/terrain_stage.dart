import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:material_ui/material_ui.dart';

import '../../data/data_repository.dart';
import '../../data/terrain.dart';
import '../../mission/mission_plan.dart';
import '../../science/geodesy.dart';
import '../../state/app_state.dart';
import '../../theme/vivited_theme.dart';
import '../widgets/primitives.dart';

/// A window of the DTM turned into a renderable height-field.
///
/// Rendering is pure Flutter: `Canvas.drawVertices` with the CTX orthomosaic
/// bound as an `ImageShader`, vertex colours carrying the Lambert shading.
/// There is no depth buffer, so triangles are emitted back-to-front — exact
/// for a height-field viewed from above when rows/columns are walked away
/// from the camera.
class TerrainMesh {
  TerrainMesh({
    required this.grid,
    required this.center,
    required this.spanM,
    this.n = 150,
  }) {
    final half = spanM / 2;
    final dLat = half / Geodesy.metersPerDegLat;
    final dLon = half / Geodesy.metersPerDegLon(center.latitude);
    // Clamp the window inside the DTM.
    var lat0 = center.latitude, lon0 = center.longitude;
    lat0 = lat0.clamp(grid.south + dLat, grid.north - dLat);
    lon0 = lon0.clamp(grid.west + dLon, grid.east - dLon);
    north = lat0 + dLat;
    south = lat0 - dLat;
    west = lon0 - dLon;
    east = lon0 + dLon;
    originLat = lat0;
    originLon = lon0;

    world = Float32List(n * n * 3);
    uv = Float32List(n * n * 2);
    var zMin = double.infinity, zMax = -double.infinity;
    for (var j = 0; j < n; j++) {
      final lat = north - (north - south) * j / (n - 1);
      for (var i = 0; i < n; i++) {
        final lon = west + (east - west) * i / (n - 1);
        final z = grid.elevationAt(
          lat.clamp(grid.rowToLat(grid.rows - 1.0), grid.rowToLat(0)),
          lon.clamp(grid.colToLon(0), grid.colToLon(grid.cols - 1.0)),
        );
        final k = j * n + i;
        world[k * 3] = -half + spanM * i / (n - 1);
        world[k * 3 + 1] = half - spanM * j / (n - 1);
        world[k * 3 + 2] = z;
        uv[k * 2] = (lon - grid.west) / (grid.east - grid.west);
        uv[k * 2 + 1] = (grid.north - lat) / (grid.north - grid.south);
        if (z < zMin) zMin = z;
        if (z > zMax) zMax = z;
      }
    }
    minZ = zMin;
    maxZ = zMax;
    midZ = (zMin + zMax) / 2;

    // Lambert shading, light from the north-west, on the true (unexaggerated)
    // surface so shading reads the same at every exaggeration.
    colors = Int32List(n * n);
    final cell = spanM / (n - 1);
    final lx = -0.5, ly = 0.5, lz = 0.7071;
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        double zAt(int ii, int jj) =>
            world[(jj.clamp(0, n - 1) * n + ii.clamp(0, n - 1)) * 3 + 2];
        final dzdx = (zAt(i + 1, j) - zAt(i - 1, j)) / (2 * cell) * 2.2;
        final dzdy = (zAt(i, j - 1) - zAt(i, j + 1)) / (2 * cell) * 2.2;
        final inv = 1 / math.sqrt(dzdx * dzdx + dzdy * dzdy + 1);
        final d = ((-dzdx * lx - dzdy * ly + lz) * inv).clamp(0.0, 1.0);
        final v = (255 * (0.42 + 0.58 * d / 0.7071).clamp(0.0, 1.0)).round();
        colors[j * n + i] = 0xFF000000 | (v << 16) | (v << 8) | v;
      }
    }
  }

  final TerrainGrid grid;
  final LatLng center;
  final double spanM;
  final int n;

  late final double north, south, west, east, originLat, originLon;
  late final Float32List world; // x east, y north, z elevation (m)
  late final Float32List uv; // 0–1 over the full DTM footprint
  late final Int32List colors;
  late final double minZ, maxZ, midZ;

  final Map<int, Uint16List> _orders = {};

  /// Local metres (east, north) of a coordinate relative to the mesh centre.
  (double, double) local(double lat, double lon) => (
        (lon - originLon) * Geodesy.metersPerDegLon(originLat),
        (lat - originLat) * Geodesy.metersPerDegLat,
      );

  bool contains(double lat, double lon) =>
      lat <= north && lat >= south && lon >= west && lon <= east;

  /// Triangle order, far to near, for a camera yaw (radians).
  Uint16List indicesFor(double yaw) {
    final s = math.sin(yaw), c = math.cos(yaw);
    // Depth grows with x·sin + y·cos. Row index grows as y falls.
    final rowsOuter = c.abs() >= s.abs();
    final rowAsc = c > 0; // far rows first: north (row 0) when cos > 0
    final colDesc = s > 0; // far columns first: east when sin > 0
    final key = (rowsOuter ? 4 : 0) | (rowAsc ? 2 : 0) | (colDesc ? 1 : 0);
    return _orders.putIfAbsent(key, () {
      final m = n - 1;
      final out = Uint16List(m * m * 6);
      var o = 0;
      void quad(int j, int i) {
        final a = j * n + i, b = a + 1, d = a + n, e = d + 1;
        out[o++] = a;
        out[o++] = b;
        out[o++] = d;
        out[o++] = b;
        out[o++] = e;
        out[o++] = d;
      }

      if (rowsOuter) {
        for (var jj = 0; jj < m; jj++) {
          final j = rowAsc ? jj : m - 1 - jj;
          for (var ii = 0; ii < m; ii++) {
            quad(j, colDesc ? m - 1 - ii : ii);
          }
        }
      } else {
        for (var ii = 0; ii < m; ii++) {
          final i = colDesc ? m - 1 - ii : ii;
          for (var jj = 0; jj < m; jj++) {
            quad(rowAsc ? jj : m - 1 - jj, i);
          }
        }
      }
      return out;
    });
  }
}

class _Camera {
  double yaw = -0.6; // radians, 0 = looking north
  double pitch = 0.62; // radians above the horizon
  double zoom = 1.0;
  double exaggeration = 2.0;
}

/// Interactive 3D terrain. Drag to orbit, scroll or pinch to zoom.
class TerrainStage extends ConsumerStatefulWidget {
  const TerrainStage({super.key});

  @override
  ConsumerState<TerrainStage> createState() => _TerrainStageState();
}

class _TerrainStageState extends ConsumerState<TerrainStage> {
  final _cam = _Camera();
  TerrainMesh? _mesh;
  String? _meshKey;
  double _scaleStartZoom = 1;

  TerrainMesh _meshFor(AppData data, MissionPlan? plan, LatLng? focus) {
    LatLng center;
    double span;
    if (plan != null && plan.hasTrack) {
      final b = plan.track;
      var n = -90.0, s = 90.0, e = -180.0, w = 180.0;
      for (final p in b) {
        n = math.max(n, p.latitude);
        s = math.min(s, p.latitude);
        e = math.max(e, p.longitude);
        w = math.min(w, p.longitude);
      }
      center = LatLng((n + s) / 2, (e + w) / 2);
      final h = (n - s) * Geodesy.metersPerDegLat;
      final wd = (e - w) * Geodesy.metersPerDegLon(center.latitude);
      span = (math.max(h, wd) * 1.7).clamp(2400.0, 14000.0);
    } else {
      center = focus ?? const LatLng(18.47, 77.40);
      span = 8000;
    }
    final key = '${center.latitude.toStringAsFixed(4)},'
        '${center.longitude.toStringAsFixed(4)},${span.round()}';
    if (key != _meshKey) {
      _meshKey = key;
      _mesh = TerrainMesh(grid: data.terrain, center: center, spanM: span);
    }
    return _mesh!;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataProvider);
    final uiState = ref.watch(uiProvider);
    final plan = ref.watch(plannerProvider.select((p) => p.plan));
    final stops = ref.watch(plannerProvider.select((p) => p.stops));
    final rehearsing = uiState.workspace == Workspace.simulate;
    final eva = rehearsing ? ref.watch(evaStateProvider) : null;
    final selected = data.target(uiState.selectedTargetId);
    final mesh = _meshFor(data, plan, selected?.position);

    final base = uiState.basemap == Basemap.relief
        ? ref.watch(reliefImageProvider).value ?? data.ortho
        : data.ortho;
    final hazard = uiState.overlays.contains(MapOverlay.hazard)
        ? ref.watch(hazardImageProvider).value
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              setState(() {
                _cam.zoom = (_cam.zoom * math.exp(-e.scrollDelta.dy * 0.0012))
                    .clamp(0.6, 4.0);
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _scaleStartZoom = _cam.zoom,
            onScaleUpdate: (d) => setState(() {
              if (d.pointerCount > 1) {
                _cam.zoom = (_scaleStartZoom * d.scale).clamp(0.6, 4.0);
              } else {
                _cam.yaw -= d.focalPointDelta.dx * 0.006;
                _cam.pitch = (_cam.pitch + d.focalPointDelta.dy * 0.004)
                    .clamp(0.16, 1.45);
              }
            }),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: CustomPaint(
                painter: _TerrainPainter(
                  mesh: mesh,
                  cam: _cam,
                  yaw: _cam.yaw,
                  pitch: _cam.pitch,
                  zoom: _cam.zoom,
                  exaggeration: _cam.exaggeration,
                  base: base,
                  hazard: hazard,
                  plan: plan,
                  stops: stops,
                  data: data,
                  showTargets: uiState.showTargets,
                  showTraverse: uiState.showTraverse,
                  selectedTarget: uiState.selectedTargetId,
                  eva: eva,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 44,
          child: Container(
            width: 190,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            decoration: BoxDecoration(
              color: VColors.basalt.withValues(alpha: 0.92),
              border: Border.all(color: VColors.rule),
            ),
            child: ParamSlider(
              label: 'Vertical scale',
              value: _cam.exaggeration,
              min: 1,
              max: 5,
              divisions: 8,
              display: '${_cam.exaggeration.toStringAsFixed(1)}×',
              onChanged: (v) => setState(() => _cam.exaggeration = v),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 44,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(mesh.spanM / 1000).toStringAsFixed(1)} × '
                  '${(mesh.spanM / 1000).toStringAsFixed(1)} km  ·  '
                  'relief ${(mesh.maxZ - mesh.minZ).round()} m',
                  style: VType.data(10.5),
                ),
                const SizedBox(height: 3),
                Text(
                  'CTX DTM 20 m resampled to ${(mesh.spanM / (mesh.n - 1)).round()} m  ·  '
                  'drag to orbit, scroll to zoom',
                  style: VType.data(10, color: VColors.dust),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TerrainPainter extends CustomPainter {
  _TerrainPainter({
    required this.mesh,
    required this.cam,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.exaggeration,
    required this.base,
    required this.hazard,
    required this.plan,
    required this.stops,
    required this.data,
    required this.showTargets,
    required this.showTraverse,
    required this.selectedTarget,
    required this.eva,
  });

  final TerrainMesh mesh;
  final _Camera cam;
  final double yaw, pitch, zoom, exaggeration;
  final ui.Image base;
  final ui.Image? hazard;
  final MissionPlan? plan;
  final List<EvaStop> stops;
  final AppData data;
  final bool showTargets;
  final bool showTraverse;
  final String? selectedTarget;
  final EvaState? eva;

  late double _sy, _cy, _sp, _cp, _dist, _focal, _cx, _cyScreen;

  void _setup(Size size) {
    _sy = math.sin(yaw);
    _cy = math.cos(yaw);
    _sp = math.sin(pitch);
    _cp = math.cos(pitch);
    _dist = mesh.spanM * 1.9;
    _focal = math.min(size.width, size.height) * 1.55 * zoom;
    _cx = size.width / 2;
    _cyScreen = size.height * 0.52;
  }

  /// Projects local metres to the screen. Returns depth in `.$3`.
  (double, double, double) _project(double x, double y, double z) {
    final zr = (z - mesh.midZ) * exaggeration;
    final xr = x * _cy - y * _sy;
    final yr = x * _sy + y * _cy;
    final up = yr * _sp + zr * _cp;
    final depth = _dist + yr * _cp - zr * _sp;
    final k = _focal / depth;
    return (_cx + xr * k, _cyScreen - up * k, depth);
  }

  Offset? _projectLatLon(double lat, double lon, [double lift = 3]) {
    if (!mesh.contains(lat, lon)) return null;
    final (x, y) = mesh.local(lat, lon);
    final z = mesh.grid.elevationAt(lat, lon);
    if (z.isNaN) return null;
    final (sx, sy, _) = _project(x, y, z + lift);
    return Offset(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _setup(size);
    canvas.clipRect(Offset.zero & size);
    final n = mesh.n, count = n * n;
    final pos = Float32List(count * 2);
    final w = mesh.world;
    for (var k = 0; k < count; k++) {
      final (sx, sy, _) = _project(w[k * 3], w[k * 3 + 1], w[k * 3 + 2]);
      pos[k * 2] = sx;
      pos[k * 2 + 1] = sy;
    }
    final indices = mesh.indicesFor(yaw);

    Float32List tex(ui.Image img) {
      final t = Float32List(count * 2);
      for (var k = 0; k < count; k++) {
        t[k * 2] = mesh.uv[k * 2] * img.width;
        t[k * 2 + 1] = mesh.uv[k * 2 + 1] * img.height;
      }
      return t;
    }

    final identity = Matrix4.identity().storage;
    final baseVerts = ui.Vertices.raw(
      ui.VertexMode.triangles,
      pos,
      textureCoordinates: tex(base),
      colors: mesh.colors,
      indices: indices,
    );
    canvas.drawVertices(
      baseVerts,
      BlendMode.modulate,
      Paint()
        ..shader = ui.ImageShader(
          base,
          TileMode.clamp,
          TileMode.clamp,
          identity,
          filterQuality: FilterQuality.medium,
        ),
    );
    baseVerts.dispose();

    if (hazard != null) {
      final hv = ui.Vertices.raw(
        ui.VertexMode.triangles,
        pos,
        textureCoordinates: tex(hazard!),
        indices: indices,
      );
      canvas.drawVertices(
        hv,
        BlendMode.srcOver,
        Paint()
          ..shader = ui.ImageShader(hazard!, TileMode.clamp, TileMode.clamp, identity),
      );
      hv.dispose();
    }

    // Frame of the mesh footprint.
    final frame = Path();
    void edge(int k, bool first) {
      first ? frame.moveTo(pos[k * 2], pos[k * 2 + 1]) : frame.lineTo(pos[k * 2], pos[k * 2 + 1]);
    }

    for (var i = 0; i < n; i++) {
      edge(i, i == 0);
    }
    for (var j = 1; j < n; j++) {
      edge(j * n + n - 1, false);
    }
    for (var i = n - 2; i >= 0; i--) {
      edge((n - 1) * n + i, false);
    }
    for (var j = n - 2; j >= 0; j--) {
      edge(j * n, false);
    }
    canvas.drawPath(
      frame,
      Paint()
        ..color = VColors.bone.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Rover traverse.
    if (showTraverse) {
      final path = Path();
      var pen = false;
      for (final p in data.traverse.path) {
        final o = _projectLatLon(p.latitude, p.longitude, 2);
        if (o == null) {
          pen = false;
          continue;
        }
        pen ? path.lineTo(o.dx, o.dy) : path.moveTo(o.dx, o.dy);
        pen = true;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = VColors.bone.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Planned route.
    if (plan != null && plan!.hasTrack) {
      final path = Path(), walked = Path();
      var first = true, firstWalked = true;
      for (final s in plan!.samples) {
        final o = _projectLatLon(s.lat, s.lon);
        if (o == null) continue;
        first ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
        first = false;
        if (eva != null && s.timeS <= eva!.timeS) {
          firstWalked ? walked.moveTo(o.dx, o.dy) : walked.lineTo(o.dx, o.dy);
          firstWalked = false;
        }
      }
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, stroke..color = VColors.ink..strokeWidth = 5.5);
      canvas.drawPath(
        path,
        stroke
          ..color = eva == null ? VColors.bone : VColors.bone.withValues(alpha: 0.55)
          ..strokeWidth = 2.6,
      );
      if (eva != null) {
        final o = _projectLatLon(eva!.position.latitude, eva!.position.longitude);
        if (o != null && !firstWalked) walked.lineTo(o.dx, o.dy);
        canvas.drawPath(walked, stroke..color = VColors.oxide..strokeWidth = 3);
      }
    }

    // Survey marks: a pin from the ground to a floating label.
    void pin(double lat, double lon, String text, Color color, {bool filled = false, bool label = true}) {
      final ground = _projectLatLon(lat, lon, 0);
      if (ground == null) return;
      final top = ground - const Offset(0, 26);
      canvas.drawLine(ground, top, Paint()..color = color..strokeWidth = 1);
      canvas.drawCircle(ground, 2.2, Paint()..color = color);
      if (!label) {
        canvas.drawRect(
          Rect.fromCenter(center: top, width: 6, height: 6),
          Paint()..color = color,
        );
        return;
      }
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: VType.body(11, color: filled ? VColors.ink : VColors.bone, weight: 500),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 190);
      final r = Rect.fromLTWH(top.dx - 4, top.dy - tp.height - 6, tp.width + 10, tp.height + 6);
      canvas.drawRect(r, Paint()..color = filled ? color : VColors.ink);
      if (!filled) {
        canvas.drawRect(
          r,
          Paint()
            ..color = color.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      tp.paint(canvas, r.topLeft + const Offset(5, 3));
    }

    final stopIds = {for (final s in stops) s.targetId};
    if (showTargets) {
      for (final t in data.targets) {
        if (stopIds.contains(t.id)) continue;
        pin(t.position.latitude, t.position.longitude, t.name, VColors.dust,
            label: t.id == selectedTarget);
      }
    }
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final name = s.name.split(' · ').first;
      pin(s.position.latitude, s.position.longitude,
          i == 0 ? 'BASE  $name' : '$i  $name',
          i == 0 ? VColors.oxide : VColors.ice,
          filled: true);
    }

    if (eva != null) {
      final o = _projectLatLon(eva!.position.latitude, eva!.position.longitude);
      if (o != null) {
        canvas.drawCircle(o, 8, Paint()..color = VColors.ink);
        canvas.drawCircle(o, 5.5, Paint()..color = VColors.oxide);
        canvas.drawCircle(
          o,
          12,
          Paint()
            ..color = VColors.oxide.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    _northArrow(canvas, size);
  }

  void _northArrow(Canvas canvas, Size size) {
    final c = Offset(size.width - 44, 150);
    // Direction of geographic north on screen for the current yaw.
    final a = Offset(-_sy, -_cy * _sp);
    final len = a.distance;
    final dir = len < 1e-6 ? const Offset(0, -1) : a / len;
    final tip = c + dir * 16, tail = c - dir * 12;
    final paint = Paint()
      ..color = VColors.bone
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, 21, Paint()..color = VColors.basalt.withValues(alpha: 0.85));
    canvas.drawCircle(c, 21, paint..color = VColors.rule);
    canvas.drawLine(tail, tip, paint..color = VColors.bone);
    final perp = Offset(-dir.dy, dir.dx);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - dir * 7 + perp * 4).dx, (tip - dir * 7 + perp * 4).dy)
        ..lineTo((tip - dir * 7 - perp * 4).dx, (tip - dir * 7 - perp * 4).dy)
        ..close(),
      Paint()..color = VColors.oxide,
    );
    final tp = TextPainter(
      text: TextSpan(text: 'N', style: VType.label(color: VColors.bone, size: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + const Offset(-4, 25));
  }

  @override
  bool shouldRepaint(_TerrainPainter old) =>
      old.mesh != mesh ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.exaggeration != exaggeration ||
      old.base != base ||
      old.hazard != hazard ||
      old.plan != plan ||
      old.stops != stops ||
      old.showTargets != showTargets ||
      old.showTraverse != showTraverse ||
      old.selectedTarget != selectedTarget ||
      old.eva?.timeS != eva?.timeS;
}
