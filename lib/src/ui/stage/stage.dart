import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../render/rasters.dart';
import '../../science/geodesy.dart';
import '../../science/hazard.dart';
import '../../science/mars_time.dart';
import '../../state/app_state.dart';
import '../../theme/vivited_theme.dart';
import '../widgets/primitives.dart';
import 'map_stage.dart';
import 'orbit_stage.dart';
import 'terrain_stage.dart';

/// The right-hand "plate": the globe, the map or the terrain model, with the
/// chrome that floats above it.
class Stage extends ConsumerStatefulWidget {
  const Stage({super.key, this.compact = false});

  /// Phone layout: smaller chrome, layer panel closed by default.
  final bool compact;

  @override
  ConsumerState<Stage> createState() => _StageState();
}

class _StageState extends ConsumerState<Stage> {
  bool _layersOpen = false;
  bool _mapBuilt = false;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(uiProvider.select((u) => u.view));
    final introSeen = ref.watch(uiProvider.select((u) => u.introSeen));
    final pick = ref.watch(uiProvider.select((u) => u.pickMode));
    final computing = ref.watch(plannerProvider.select((p) => p.computing));
    final compact = widget.compact;
    if (view == StageView.map) _mapBuilt = true;

    return ColoredBox(
      color: VColors.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The map keeps its camera while other views are shown.
          if (_mapBuilt)
            Offstage(
              offstage: view != StageView.map,
              child: TickerMode(
                enabled: view == StageView.map,
                child: const MapStage(),
              ),
            ),
          if (view == StageView.orbit) const OrbitStage(),
          if (view == StageView.terrain) const TerrainStage(),

          // View switcher.
          Positioned(
            top: 14,
            left: 14,
            child: _ViewSwitcher(view: view),
          ),

          // Layers.
          if (view != StageView.orbit)
            Positioned(
              top: 14,
              right: 14,
              bottom: compact ? 60 : 70,
              child: Align(
                alignment: Alignment.topRight,
                child: _layersOpen
                    ? _LayerPanel(
                        terrainView: view == StageView.terrain,
                        onClose: () => setState(() => _layersOpen = false),
                      )
                    : VIconButton(
                        icon: Icons.layers_outlined,
                        tooltip: 'Layers',
                        onPressed: () => setState(() => _layersOpen = true),
                      ),
              ),
            ),

          if (view == StageView.map && pick != PickMode.inspect)
            Positioned(
              top: 60,
              left: 14,
              child: _PickBanner(mode: pick),
            ),

          if (computing && view != StageView.orbit)
            const Positioned(top: 22, left: 0, right: 0, child: Center(child: _Computing())),

          if (view == StageView.map)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StatusStrip(compact: compact),
            ),

          if (view == StageView.orbit)
            Positioned(
              left: compact ? 20 : 44,
              right: compact ? 20 : null,
              bottom: compact ? 28 : 48,
              child: _OrbitIntro(first: !introSeen, compact: compact),
            ),
        ],
      ),
    );
  }
}

class _ViewSwitcher extends ConsumerWidget {
  const _ViewSwitcher({required this.view});
  final StageView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        decoration: BoxDecoration(
          color: VColors.basalt,
          border: Border.all(color: VColors.rule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in StageView.values)
              Semantics(
                button: true,
                selected: v == view,
                label: '${v.label} view',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref.read(uiProvider.notifier).setView(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      color: v == view ? VColors.bone : Colors.transparent,
                      child: Text(
                        v.label.toUpperCase(),
                        style: VType.label(
                          color: v == view ? VColors.ink : VColors.dust,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _LayerPanel extends ConsumerWidget {
  const _LayerPanel({required this.terrainView, required this.onClose});
  final bool terrainView;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(uiProvider);
    final c = ref.read(uiProvider.notifier);
    final ls = ref.watch(plannerProvider.select((p) => p.params.ls));
    final ltst = ref.watch(illuminationTimeProvider);
    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: VColors.basalt.withValues(alpha: 0.96),
        border: Border.all(color: VColors.rule),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text('LAYERS', style: VType.label(color: VColors.bone))),
                Tooltip(
                  message: 'Close layers',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onClose,
                      child: const Icon(Icons.close, size: 16, color: VColors.dust),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Hairline(),
            const SizedBox(height: 6),
            Text('BASE', style: VType.label(size: 9)),
            for (final b in Basemap.values)
              ToggleRow(
                label: b.label,
                caption: b.source,
                radio: true,
                value: s.basemap == b,
                onChanged: () => c.setBasemap(b),
              ),
            const SizedBox(height: 8),
            Text('ANALYSIS', style: VType.label(size: 9)),
            for (final o in MapOverlay.values)
              if (!terrainView || o == MapOverlay.hazard) ...[
                ToggleRow(
                  label: o.label,
                  caption: o.source,
                  value: s.overlays.contains(o),
                  onChanged: () => c.toggleOverlay(o),
                ),
                if (s.overlays.contains(o)) _Legend(o, ls: ls, ltst: ltst),
              ],
            if (terrainView)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Other analysis layers are drawn on the map view.',
                  style: VType.data(10, color: VColors.ash),
                ),
              ),
            const SizedBox(height: 8),
            Text('MARKS', style: VType.label(size: 9)),
            ToggleRow(
              label: 'Perseverance traverse',
              caption: 'Mars 2020 · to sol ${ref.watch(dataProvider).traverse.lastSol}',
              value: s.showTraverse,
              onChanged: c.toggleTraverse,
            ),
            ToggleRow(
              label: 'Science stations',
              caption: 'Sampled and studied by Perseverance · NASA DATA',
              value: s.showTargets,
              onChanged: c.toggleTargets,
            ),
            ToggleRow(
              label: 'Mission checkpoints',
              caption: 'H0 · CP1–CP3 · SH · SIMULATION roles',
              value: s.showCheckpoints,
              onChanged: c.toggleCheckpoints,
            ),
            const SizedBox(height: 8),
            Text('DATA CLASSES', style: VType.label(size: 9)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Optical CTX imagery and elevation: NASA DATA. Slope hazard '
                'and route difficulty: SCIENTIFIC INTERPRETATION. Habitat H0 '
                'and life-support units: SIMULATION.',
                style: VType.data(9.5, color: VColors.ash),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.overlay, {required this.ls, required this.ltst});
  final MapOverlay overlay;
  final double ls;
  final double ltst;

  Widget _ramp(Color Function(double) ramp, String lo, String hi) => Column(
        children: [
          SizedBox(
            height: 6,
            child: Row(
              children: [
                for (var i = 0; i < 24; i++)
                  Expanded(child: ColoredBox(color: ramp(i / 23), child: const SizedBox.expand())),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(lo, style: VType.data(9.5, color: VColors.ash)),
              const Spacer(),
              Text(hi, style: VType.data(9.5, color: VColors.ash)),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (overlay) {
      MapOverlay.hazard => Column(
          children: [
            SizedBox(
              height: 6,
              child: Row(
                children: [
                  for (final h in HazardClass.values)
                    Expanded(
                      child: ColoredBox(
                        color: VColors.hazard(h),
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final e in ['0°', '6°', '10°', '15°', '20°', ''])
                  Text(e, style: VType.data(9.5, color: VColors.ash)),
              ],
            ),
          ],
        ),
      MapOverlay.thermal => _ramp(ColorRamp.thermal.color, 'cooler · dust, sand', 'warmer · rock'),
      MapOverlay.solar => _ramp(
          ColorRamp.solar.color,
          '−30 % vs level',
          '+30 % · Ls ${ls.round()}°',
        ),
      MapOverlay.illumination => Text(
          'Cast shadows at ${MarsTime.formatClock(ltst)} LTST, Ls ${ls.round()}°',
          style: VType.data(9.5, color: VColors.ash),
        ),
      MapOverlay.walkBack => _ramp(
          ColorRamp.walkBack.color,
          '0 · lines every 5 min',
          '150 min',
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 23, bottom: 8),
      child: body,
    );
  }
}

class _PickBanner extends ConsumerWidget {
  const _PickBanner({required this.mode});
  final PickMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        color: VColors.oxide,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode == PickMode.base
                  ? 'Tap the map to place the airlock'
                  : 'Tap the map or a station to add stops',
              style: VType.body(12.5, color: VColors.ink, weight: 600),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'Done placing',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () =>
                      ref.read(uiProvider.notifier).setPickMode(PickMode.inspect),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: VColors.ink,
                    child: Text('DONE', style: VType.label(color: VColors.bone, size: 9.5)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Computing extends StatelessWidget {
  const _Computing();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: VColors.basalt,
          border: Border.all(color: VColors.rule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.4, color: VColors.oxide),
            ),
            const SizedBox(width: 8),
            Text('ROUTING OVER TERRAIN', style: VType.label(size: 9)),
          ],
        ),
      );
}

/// Read-out of every dataset under the pointer.
class _StatusStrip extends ConsumerWidget {
  const _StatusStrip({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(cursorProvider);
    final data = ref.watch(dataProvider);
    final field = ref.watch(plannerProvider.select((s) => s.walkBack));
    final g = data.terrain;
    final inside = p != null && g.containsLatLon(p.latitude, p.longitude);

    Widget cell(String label, String value, {Color color = VColors.bone}) => Padding(
          padding: const EdgeInsets.only(right: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: VType.label(size: 8.5, color: VColors.ash)),
              const SizedBox(height: 2),
              Text(value, style: VType.data(compact ? 11 : 12, color: color)),
            ],
          ),
        );

    final cells = <Widget>[];
    if (p == null) {
      cells.add(cell(
        'INSPECT',
        compact ? 'Tap the map to read the terrain' : 'Move over the map to read the terrain',
        color: VColors.dust,
      ));
    } else {
      cells.add(cell(
        'POSITION',
        '${Geodesy.formatLat(p.latitude)}  ${Geodesy.formatLon(p.longitude)}',
      ));
      if (inside) {
        final slope = g.slopeAt(p.latitude, p.longitude);
        final h = HazardClass.fromSlope(slope);
        cells.add(cell('ELEVATION', '${g.elevationAt(p.latitude, p.longitude).round()} m'));
        cells.add(cell(
          'SLOPE',
          '${slope.toStringAsFixed(1)}° ${h.label.toLowerCase()}',
          color: VColors.hazard(h),
        ));
        if (!compact) {
          final dn = data.themisAt(p.latitude, p.longitude);
          cells.add(cell('NIGHT IR', dn < 0 ? '—' : '$dn / 255'));
          final wb = field?.atLatLon(p.latitude, p.longitude);
          cells.add(cell(
            'WALK-BACK',
            wb == null
                ? '—'
                : wb.isFinite
                    ? formatDuration(wb)
                    : 'beyond 2 h 30',
          ));
        }
      } else {
        cells.add(cell(
          'ELEVATION',
          '${data.relief.elevationAt(p.latitude, p.longitude).round()} m · MOLA',
        ));
        cells.add(cell('SURVEY', 'Outside the 20 m terrain model', color: VColors.dust));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: VColors.basalt.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: VColors.rule)),
      ),
      padding: EdgeInsets.fromLTRB(14, 8, 14, compact ? 8 : 9),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: cells),
      ),
    );
  }
}

class _OrbitIntro extends ConsumerWidget {
  const _OrbitIntro({required this.first, required this.compact});
  final bool first;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'JEZERO CRATER · 18.44°N 77.45°E · ISIDIS PLANITIA',
              style: VType.label(color: VColors.oxide),
            ),
            const SizedBox(height: 12),
            Text(
              'How can astronauts\nexplore Mars safely\non one interactive map?',
              style: VType.display(compact ? 28 : 38),
            ),
            const SizedBox(height: 12),
            Text(
              'Perseverance has walked Jezero since 2021. Vivited combines NASA '
              'optical imagery, topography and MEDA climatology with transparent '
              'route and life-support models — educational planning, not flight ops.',
              style: VType.body(compact ? 13 : 14, color: VColors.dust),
            ),
            const SizedBox(height: 18),
            VButton(
              label: first ? 'Enter the site' : 'Return to the site',
              icon: Icons.south_east,
              primary: true,
              onPressed: () => ref.read(uiProvider.notifier).enterSite(),
            ),
          ],
        ),
      );
}
