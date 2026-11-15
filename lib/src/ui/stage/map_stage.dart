import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../mission/checkpoints.dart';
import '../../mission/mission_plan.dart';
import '../../science/geodesy.dart';
import '../../state/app_state.dart';
import '../../theme/vivited_theme.dart';
import '../widgets/glyphs.dart';

const _trek = 'https://trek.nasa.gov/tiles/Mars/EQ';

/// The 2D atlas: NASA Trek global context tiles under the bundled Jezero
/// rasters, analysis overlays, the rover traverse, the planned route and
/// survey marks. Plate carrée (EPSG:4326-style) so that every layer shares
/// the projection of the USGS source products.
class MapStage extends ConsumerStatefulWidget {
  const MapStage({super.key});

  @override
  ConsumerState<MapStage> createState() => _MapStageState();
}

class _MapStageState extends ConsumerState<MapStage>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  LatLng? _flyFromCenter, _flyToCenter;
  double _flyFromZoom = 0, _flyToZoom = 0;
  String? _fittedPlanKey;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _fly.addListener(() {
      if (_flyFromCenter == null) return;
      final t = Curves.easeInOutCubic.transform(_fly.value);
      _map.move(
        LatLng(
          _flyFromCenter!.latitude +
              (_flyToCenter!.latitude - _flyFromCenter!.latitude) * t,
          _flyFromCenter!.longitude +
              (_flyToCenter!.longitude - _flyFromCenter!.longitude) * t,
        ),
        _flyFromZoom + (_flyToZoom - _flyFromZoom) * t,
      );
    });
  }

  @override
  void dispose() {
    _fly.dispose();
    _map.dispose();
    super.dispose();
  }

  void _flyTo(LatLng center, double zoom) {
    if (!_ready) return;
    _flyFromCenter = _map.camera.center;
    _flyFromZoom = _map.camera.zoom;
    _flyToCenter = center;
    _flyToZoom = zoom;
    _fly.forward(from: 0);
  }

  void _flyToBounds(LatLngBounds b) {
    if (!_ready) return;
    final fit = CameraFit.bounds(
      bounds: b,
      padding: const EdgeInsets.fromLTRB(70, 90, 70, 190),
      maxZoom: 13.8,
    ).fit(_map.camera);
    _flyTo(fit.center, fit.zoom);
  }

  void _fitPlan(MissionPlan plan, String key) {
    if (!plan.hasTrack || _fittedPlanKey == key) return;
    _fittedPlanKey = key;
    _flyToBounds(LatLngBounds.fromPoints(plan.track));
  }

  void _onTap(LatLng p) {
    final ui = ref.read(uiProvider);
    final planner = ref.read(plannerProvider.notifier);
    switch (ui.pickMode) {
      case PickMode.base:
        if (planner.setBase(p)) {
          ref.read(uiProvider.notifier).setPickMode(PickMode.inspect);
        }
      case PickMode.stop:
        planner.addStop(p);
      case PickMode.inspect:
        ref.read(cursorProvider.notifier).set(p);
        ref.read(uiProvider.notifier).selectTarget(null);
    }
  }

  void _onTargetTap(ScienceTarget t) {
    final ui = ref.read(uiProvider);
    final planner = ref.read(plannerProvider.notifier);
    switch (ui.pickMode) {
      case PickMode.base:
        planner.setBase(t.position, target: t);
        ref.read(uiProvider.notifier).setPickMode(PickMode.inspect);
      case PickMode.stop:
        planner.addStop(t.position, target: t);
      case PickMode.inspect:
        ref.read(uiProvider.notifier).selectTarget(t.id);
        ref.read(cursorProvider.notifier).set(t.position);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataProvider);
    final uiState = ref.watch(uiProvider);
    final plan = ref.watch(plannerProvider.select((p) => p.plan));
    final stops = ref.watch(plannerProvider.select((p) => p.stops));
    final rehearsing = uiState.workspace == Workspace.simulate;
    final g = data.terrain;
    final bounds = LatLngBounds(LatLng(g.south, g.west), LatLng(g.north, g.east));

    ref.listen(uiProvider.select((u) => u.focus), (prev, next) {
      if (next == null || identical(prev, next)) return;
      if (next.bounds != null) {
        _flyToBounds(LatLngBounds(next.bounds!.$1, next.bounds!.$2));
      } else {
        _flyTo(next.center, next.zoom ?? _map.camera.zoom);
      }
    });
    ref.listen(plannerProvider, (prev, next) {
      final p = next.plan;
      if (p == null || next.computing) return;
      // Re-frame when a preset is loaded or the base moves.
      final b = next.stops.first.position;
      _fitPlan(p, '${next.presetId}|${b.latitude}|${b.longitude}');
    });

    ui.Image? overlayImage(MapOverlay o) => switch (o) {
          MapOverlay.hazard => ref.watch(hazardImageProvider).value,
          MapOverlay.thermal => ref.watch(thermalImageProvider).value,
          MapOverlay.solar => ref.watch(solarImageProvider).value,
          MapOverlay.illumination => ref.watch(illuminationImageProvider).value,
          MapOverlay.walkBack => ref.watch(walkBackImageProvider).value,
        };

    final base = uiState.basemap == Basemap.relief
        ? ref.watch(reliefImageProvider).value ?? data.ortho
        : data.ortho;

    final routeIds = {for (final s in stops) s.targetId};
    final track = plan?.track ?? const <LatLng>[];

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        crs: const Epsg4326(),
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
        minZoom: 3,
        maxZoom: 14.5,
        backgroundColor: VColors.ink,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          scrollWheelVelocity: 0.008,
        ),
        onMapReady: () {
          _ready = true;
          final p = ref.read(plannerProvider);
          if (p.plan != null && p.stops.isNotEmpty) {
            final b = p.stops.first.position;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _fitPlan(p.plan!, '${p.presetId}|${b.latitude}|${b.longitude}');
              }
            });
          }
        },
        onTap: (_, p) => _onTap(p),
        onPointerHover: (_, p) => ref.read(cursorProvider.notifier).set(p),
      ),
      children: [
        // Global context (online, NASA Solar System Treks). Failing tiles are
        // simply absent: the bundled Jezero rasters never depend on them.
        TileLayer(
          urlTemplate:
              '$_trek/Mars_Viking_MDIM21_ClrMosaic_global_232m/1.0.0/default/default028mm/{z}/{y}/{x}.jpg',
          maxNativeZoom: 7,
          userAgentPackageName: 'space.vivited.app',
          // The browser's HTTP cache already holds tiles on the web target.
          tileProvider: NetworkTileProvider(
            cachingProvider: const DisabledMapCachingProvider(),
          ),
          errorTileCallback: (_, _, _) {},
          tileBuilder: (context, tile, _) => ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.42, 0.18, 0.05, 0, 0, //
              0.30, 0.22, 0.05, 0, 0, //
              0.24, 0.16, 0.10, 0, 0, //
              0, 0, 0, 1, 0,
            ]),
            child: tile,
          ),
        ),
        _RasterLayer(image: base, bounds: bounds),
        for (final o in MapOverlay.values)
          if (uiState.overlays.contains(o) && overlayImage(o) != null)
            _RasterLayer(
              image: overlayImage(o)!,
              bounds: bounds,
              smooth: o != MapOverlay.hazard,
            ),
        const _GraticuleLayer(),
        _FootprintLayer(bounds: bounds),
        if (uiState.showTraverse)
          PolylineLayer(
            polylines: [
              Polyline(
                points: data.traverse.path,
                strokeWidth: 1.2,
                color: VColors.bone.withValues(alpha: 0.55),
                pattern: StrokePattern.dashed(segments: const [5, 4]),
              ),
            ],
          ),
        if (track.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: track,
                strokeWidth: 3,
                color: rehearsing ? VColors.bone.withValues(alpha: 0.5) : VColors.bone,
                borderStrokeWidth: 2,
                borderColor: VColors.ink,
              ),
              if (rehearsing) _walkedLine(ref, plan!),
            ],
          ),
        if (uiState.showTargets)
          MarkerLayer(
            markers: [
              for (final t in data.targets) ...[
                Marker(
                  point: t.position,
                  width: 26,
                  height: 26,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _onTargetTap(t),
                      child: Tooltip(
                        message: t.name,
                        child: Center(
                          child: TargetGlyph(
                            kind: t.kind,
                            selected: t.id == uiState.selectedTargetId,
                            inRoute: routeIds.contains(t.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (t.id == uiState.selectedTargetId)
                  Marker(
                    point: t.position,
                    width: 240,
                    height: 22,
                    alignment: Alignment.centerRight,
                    child: IgnorePointer(child: _MapLabel(t.name)),
                  ),
              ],
            ],
          ),
        if (uiState.showCheckpoints)
          MarkerLayer(
            markers: [
              for (final cp in MissionCheckpoint.all)
                if (data.target(cp.targetId) != null) ...[
                  Marker(
                    point: data.target(cp.targetId)!.position,
                    width: 44,
                    height: 22,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _onTargetTap(data.target(cp.targetId)!),
                        child: Tooltip(
                          message: '${cp.title} — ${cp.role}\n'
                              '${cp.classification.label}',
                          child: Center(
                            child: CheckpointGlyph(
                              code: cp.code,
                              selected: uiState.selectedTargetId == cp.targetId,
                              signal: cp.code == 'H0' || cp.code == 'SH',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
            ],
          ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < stops.length; i++)
              Marker(
                point: stops[i].position,
                width: 24,
                height: 24,
                child: IgnorePointer(
                  child: Center(child: StopGlyph(index: i)),
                ),
              ),
            if (stops.isNotEmpty)
              Marker(
                point: stops.first.position,
                width: 110,
                height: 22,
                alignment: Alignment.centerLeft,
                child: IgnorePointer(
                  child: _MapLabel(
                    MissionCheckpoint.forTarget(stops.first.targetId)?.code ==
                            'H0'
                        ? 'H0 · HABITAT'
                        : 'BASE',
                    alignRight: true,
                    signal: true,
                  ),
                ),
              ),
          ],
        ),
        if (rehearsing) const _WalkerLayer(),
        const _ScaleBar(),
      ],
    );
  }

  Polyline _walkedLine(WidgetRef ref, MissionPlan plan) {
    final st = ref.watch(evaStateProvider);
    final pts = <LatLng>[];
    if (st != null) {
      for (final s in plan.samples) {
        if (s.timeS > st.timeS) break;
        pts.add(s.position);
      }
      pts.add(st.position);
    }
    return Polyline(
      points: pts.length < 2 ? [plan.track.first, plan.track.first] : pts,
      strokeWidth: 3.2,
      color: VColors.oxide,
    );
  }
}

/// Draws a georeferenced image through the live map camera.
class _RasterLayer extends StatelessWidget {
  const _RasterLayer({required this.image, required this.bounds, this.smooth = true});
  final ui.Image image;
  final LatLngBounds bounds;
  final bool smooth;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final nw = camera.latLngToScreenOffset(bounds.northWest);
    final se = camera.latLngToScreenOffset(bounds.southEast);
    return SizedBox.expand(
      child: CustomPaint(
        painter: _RasterPainter(image, Rect.fromPoints(nw, se), smooth),
      ),
    );
  }
}

class _RasterPainter extends CustomPainter {
  _RasterPainter(this.image, this.dst, this.smooth);
  final ui.Image image;
  final Rect dst;
  final bool smooth;

  @override
  void paint(Canvas canvas, Size size) {
    if (!dst.overlaps(Offset.zero & size)) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = smooth ? FilterQuality.medium : FilterQuality.none,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RasterPainter old) =>
      old.image != image || old.dst != dst || old.smooth != smooth;
}

/// Hairline frame and corner ticks around the DTM footprint.
class _FootprintLayer extends StatelessWidget {
  const _FootprintLayer({required this.bounds});
  final LatLngBounds bounds;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return SizedBox.expand(
      child: CustomPaint(
        painter: _FootprintPainter(Rect.fromPoints(
          camera.latLngToScreenOffset(bounds.northWest),
          camera.latLngToScreenOffset(bounds.southEast),
        )),
      ),
    );
  }
}

class _FootprintPainter extends CustomPainter {
  _FootprintPainter(this.r);
  final Rect r;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      r,
      Paint()
        ..color = VColors.bone.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FootprintPainter old) => old.r != r;
}

/// Latitude / longitude graticule with labels along the frame.
class _GraticuleLayer extends StatelessWidget {
  const _GraticuleLayer();

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return SizedBox.expand(
      child: IgnorePointer(
        child: CustomPaint(painter: _GraticulePainter(camera)),
      ),
    );
  }
}

class _GraticulePainter extends CustomPainter {
  _GraticulePainter(this.camera);
  final MapCamera camera;

  static const _steps = [10.0, 5.0, 2.0, 1.0, 0.5, 0.2, 0.1, 0.05, 0.02, 0.01];

  @override
  void paint(Canvas canvas, Size size) {
    final b = camera.visibleBounds;
    final span = b.north - b.south;
    final step = _steps.firstWhere((s) => span / s >= 3, orElse: () => 0.01);
    final line = Paint()
      ..color = VColors.bone.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final style = VType.data(9.5, color: VColors.bone.withValues(alpha: 0.6));
    final digits = step >= 1 ? 0 : (step >= 0.1 ? 1 : 2);

    void label(String s, Offset at, Alignment a) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        at - Offset((a.x + 1) / 2 * tp.width, (a.y + 1) / 2 * tp.height),
      );
    }

    for (var lat = (b.south / step).ceil() * step; lat <= b.north; lat += step) {
      final y = camera.latLngToScreenOffset(LatLng(lat, b.west)).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      label('${lat.abs().toStringAsFixed(digits)}°${lat >= 0 ? 'N' : 'S'}',
          Offset(size.width - 8, y - 3), Alignment.bottomRight);
    }
    final west = math.max(b.west, -180.0), east = math.min(b.east, 180.0);
    for (var lon = (west / step).ceil() * step; lon <= east; lon += step) {
      final x = camera.latLngToScreenOffset(LatLng(b.north, lon)).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      label('${lon.toStringAsFixed(digits)}°E', Offset(x + 5, size.height - 8),
          Alignment.bottomLeft);
    }
  }

  @override
  bool shouldRepaint(_GraticulePainter old) =>
      old.camera.center != camera.center || old.camera.zoom != camera.zoom ||
      old.camera.size != camera.size;
}

class _MapLabel extends StatelessWidget {
  const _MapLabel(this.text, {this.alignRight = false, this.signal = false});
  final String text;
  final bool alignRight;
  final bool signal;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: alignRight ? 0 : 16, right: alignRight ? 16 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: signal ? VColors.oxide : VColors.ink,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: signal
                ? VType.label(color: VColors.ink, size: 9)
                : VType.body(11.5, weight: 500),
          ),
        ),
      );
}

class _WalkerLayer extends ConsumerWidget {
  const _WalkerLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(evaStateProvider);
    if (st == null) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        Marker(
          point: st.position,
          width: 44,
          height: 44,
          child: IgnorePointer(
            child: WalkerGlyph(headingDeg: st.headingDeg, moving: st.walking),
          ),
        ),
      ],
    );
  }
}

/// Ground-distance scale bar (east–west, at the latitude of the map centre).
class _ScaleBar extends StatelessWidget {
  const _ScaleBar();

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final degPerPx = 180.0 / (256.0 * math.pow(2, camera.zoom));
    final mPerPx = degPerPx * Geodesy.metersPerDegLon(camera.center.latitude);
    const nice = [
      50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0, 20000.0,
      50000.0, 100000.0, 200000.0, 500000.0, 1000000.0, 2000000.0,
    ];
    final len = nice.lastWhere((n) => n / mPerPx <= 150, orElse: () => nice.first);
    final px = len / mPerPx;
    return Align(
      alignment: Alignment.bottomLeft,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                len >= 1000 ? '${(len / 1000).round()} km' : '${len.round()} m',
                style: VType.data(10, color: VColors.bone),
              ),
              const SizedBox(height: 3),
              Container(
                width: px,
                height: 5,
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: VColors.bone),
                    right: BorderSide(color: VColors.bone),
                    bottom: BorderSide(color: VColors.bone),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
