import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/data_repository.dart';
import '../../data/models.dart';
import '../../mission/checkpoints.dart';
import '../../science/hazard.dart';
import '../../science/provenance.dart';
import '../../state/app_state.dart';
import '../../theme/vivited_theme.dart';
import '../widgets/glyphs.dart';
import '../widgets/primitives.dart';

/// Terrain statistics derived once from the DTM.
final terrainStatsProvider = Provider<List<double>>((ref) {
  final g = ref.watch(dataProvider).terrain;
  return g.slopeHistogram(HazardClass.edgesDeg);
});

class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String kicker;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(kicker.toUpperCase(), style: VType.label())),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: VType.display(38)),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(subtitle!, style: VType.body(13, color: VColors.dust)),
          ],
        ],
      );
}

class AtlasPanel extends ConsumerWidget {
  const AtlasPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataProvider);
    final g = data.terrain;
    final hist = ref.watch(terrainStatsProvider);
    final selectedId = ref.watch(uiProvider.select((u) => u.selectedTargetId));
    final extentNs = g.rows * g.pixelSizeM / 1000;
    final extentEw = g.cols * g.cellDx(g.rows ~/ 2) / 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelHeader(
          kicker: 'Mission + map · 18.44°N 77.45°E',
          title: 'Jezero crater',
          subtitle:
              'How can astronauts explore Mars safely, check earlier robotic '
              'observations, and collect new scientific data using one '
              'interactive map? Vivited answers that inside Jezero — a 45 km '
              'impact basin that held a lake about 3.5 billion years ago.',
        ),
        const SectionHeader('01', 'Exploration region'),
        Text(
          'The study area is the bundled Mars 2020 CTX terrain sheet covering '
          'the crater floor, western fan and inner rim. Habitat and safety '
          'marks are simulated mission infrastructure placed on real rover '
          'stations — never invented coordinates.',
          style: VType.body(12.5, color: VColors.dust),
        ),
        const SizedBox(height: 10),
        for (final cp in MissionCheckpoint.all)
          _CheckpointRow(checkpoint: cp, data: data),
        const SectionHeader('02', 'Data layers'),
        _DataLayerCard(
          title: 'Optical surface',
          source: 'MRO CTX orthomosaic · 6 m (bundled at 12 m)',
          purpose:
              'Visible rocks, scarps, fans and traversal obstacles. Switch the '
              'map base to CTX imagery.',
          klass: SourceClass.nasaData,
          onShow: () {
            final ui = ref.read(uiProvider.notifier);
            ui.setBasemap(Basemap.imagery);
            ui.setOverlays({});
            ui.setView(StageView.map);
          },
        ),
        _DataLayerCard(
          title: 'Elevation and topography',
          source: 'Mars 2020 TRN CTX DTM · 20 m · USGS',
          purpose:
              'Surface elevation, slope, hazard classes and route profiles. '
              'Distances use Mars geodesy on the 20 m grid.',
          klass: SourceClass.nasaData,
          note: 'Derived slope hazard classes are SCIENTIFIC INTERPRETATION.',
          onShow: () {
            final ui = ref.read(uiProvider.notifier);
            ui.setBasemap(Basemap.relief);
            ui.setOverlays({MapOverlay.hazard});
            ui.setView(StageView.map);
          },
        ),
        _DataLayerCard(
          title: 'Historical MEDA atmosphere',
          source: 'Mars 2020 MEDA · PDS Atmospheres',
          purpose:
              'Air and ground temperature, pressure and wind by local hour — '
              'a climatology of past sols, not real-time weather.',
          klass: SourceClass.nasaData,
          onShow: () {
            ref.read(uiProvider.notifier).setWorkspace(Workspace.plan);
          },
        ),
        const SectionHeader('03', 'The ground'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Figure(
                value: '${(g.maxElevation - g.minElevation).round()}',
                unit: 'm',
                caption: 'Relief on this sheet',
              ),
            ),
            Expanded(
              child: Figure(
                value: '${(hist[0] * 100).round()}',
                unit: '%',
                caption: 'Level walking',
                color: VColors.lichen,
              ),
            ),
            Expanded(
              child: Figure(
                value: (hist[4] * 100).toStringAsFixed(1),
                unit: '%',
                caption: 'No-go slope',
                color: VColors.alarm,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        KeyValue('Sheet extent',
            '${extentEw.toStringAsFixed(1)} × ${extentNs.toStringAsFixed(1)} km'),
        KeyValue('Elevation range',
            '${g.minElevation.round()} to ${g.maxElevation.round()} m',
            note: 'MOLA areoid'),
        KeyValue('Terrain model', '${g.cols} × ${g.rows} cells', note: '20 m'),
        const SectionHeader('04', 'Slope hazard classes'),
        for (final h in HazardClass.values)
          _HazardLegendRow(hazard: h, fraction: hist[h.index]),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Share of the sheet in each class, from the 20 m CTX stereo terrain '
            'model. Boulders, ripples and scarps smaller than about 60 m are '
            'below its resolution. Hazard classes are SCIENTIFIC INTERPRETATION.',
            style: VType.body(11.5, color: VColors.ash),
          ),
        ),
        SectionHeader(
          '05',
          'Science stations',
          trailing: Text('${data.targets.length}', style: VType.data(10, color: VColors.dust)),
        ),
        for (final t in data.targets)
          _TargetRow(target: t, expanded: t.id == selectedId, data: data),
      ],
    );
  }
}

class _CheckpointRow extends ConsumerWidget {
  const _CheckpointRow({required this.checkpoint, required this.data});
  final MissionCheckpoint checkpoint;
  final AppData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = data.target(checkpoint.targetId);
    if (t == null) return const SizedBox.shrink();
    final selected =
        ref.watch(uiProvider.select((u) => u.selectedTargetId)) == t.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(uiProvider.notifier).selectTarget(
                selected ? null : t.id,
                fly: !selected,
                target: t,
              ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckpointGlyph(
                code: checkpoint.code,
                selected: selected,
                signal: checkpoint.code == 'H0' || checkpoint.code == 'SH',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(checkpoint.title, style: VType.body(13, weight: 600)),
                    Text(checkpoint.role, style: VType.data(10, color: VColors.ash)),
                    if (selected) ...[
                      const SizedBox(height: 6),
                      Text(
                        checkpoint.summary,
                        style: VType.body(12, color: VColors.dust, height: 1.45),
                      ),
                      const SizedBox(height: 6),
                      ProvenanceChip(checkpoint.classification, compact: true),
                      const SizedBox(height: 4),
                      Text(
                        'At ${t.name} · Sol ${t.sol}',
                        style: VType.data(10, color: VColors.ash),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataLayerCard extends StatelessWidget {
  const _DataLayerCard({
    required this.title,
    required this.source,
    required this.purpose,
    required this.klass,
    required this.onShow,
    this.note,
  });
  final String title;
  final String source;
  final String purpose;
  final SourceClass klass;
  final VoidCallback onShow;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: VType.body(13.5, weight: 600)),
                ),
                ProvenanceChip(klass, compact: true),
              ],
            ),
            const SizedBox(height: 3),
            Text(source, style: VType.data(10, color: VColors.ash)),
            const SizedBox(height: 4),
            Text(purpose, style: VType.body(12, color: VColors.dust)),
            if (note != null) ...[
              const SizedBox(height: 3),
              Text(note!, style: VType.body(11, color: VColors.ash)),
            ],
            const SizedBox(height: 8),
            VButton(label: 'Show on map', dense: true, onPressed: onShow),
          ],
        ),
      );
}

class _HazardLegendRow extends StatelessWidget {
  const _HazardLegendRow({required this.hazard, required this.fraction});
  final HazardClass hazard;
  final double fraction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Tooltip(
          message: hazard.guidance,
          child: Row(
            children: [
              Container(width: 10, height: 10, color: VColors.hazard(hazard)),
              const SizedBox(width: 10),
              SizedBox(
                width: 74,
                child: Text(hazard.label, style: VType.body(12.5, weight: 500)),
              ),
              SizedBox(
                width: 52,
                child: Text(hazard.range, style: VType.data(11, color: VColors.dust)),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction.clamp(0.004, 1.0),
                    child: Container(height: 3, color: VColors.hazard(hazard)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '${(fraction * 100).toStringAsFixed(fraction < 0.1 ? 1 : 0)} %',
                  textAlign: TextAlign.right,
                  style: VType.data(11),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TargetRow extends ConsumerWidget {
  const _TargetRow({required this.target, required this.expanded, required this.data});
  final ScienceTarget target;
  final bool expanded;
  final AppData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.read(uiProvider.notifier);
    final color = targetColor(target.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ui.selectTarget(
              expanded ? null : target.id,
              fly: !expanded,
              target: target,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  TargetGlyph(kind: target.kind, selected: expanded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target.name,
                          style: VType.body(13.5, weight: expanded ? 600 : 500),
                        ),
                        Text(target.unit, style: VType.data(10, color: VColors.ash)),
                      ],
                    ),
                  ),
                  _ValuePips(target.scienceValue, color),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded ? _TargetDetail(target: target, data: data) : const SizedBox(width: double.infinity),
        ),
        const Hairline(),
      ],
    );
  }
}

class _ValuePips extends StatelessWidget {
  const _ValuePips(this.value, this.color);
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Planning priority $value of 5 (Vivited editorial ranking)',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Container(
                width: 4,
                height: 10,
                margin: const EdgeInsets.only(left: 2),
                color: i < value ? color : VColors.rule,
              ),
          ],
        ),
      );
}

class _TargetDetail extends ConsumerWidget {
  const _TargetDetail({required this.target, required this.data});
  final ScienceTarget target;
  final AppData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = target.position;
    final slope = data.terrain.slopeAt(p.latitude, p.longitude);
    final planner = ref.read(plannerProvider.notifier);
    final ui = ref.read(uiProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(target.summary, style: VType.body(12.5, color: VColors.bone, height: 1.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Tag(target.kind.label, color: targetColor(target.kind)),
              for (final r in target.resources)
                Tag(ScienceTarget.resourceLabels[r] ?? r, color: VColors.sulfur),
            ],
          ),
          const SizedBox(height: 8),
          KeyValue('Position',
              '${p.latitude.toStringAsFixed(4)}°N  ${p.longitude.toStringAsFixed(4)}°E'),
          KeyValue('Elevation', '${target.elevationM.round()} m'),
          KeyValue(
            'Local slope',
            '${slope.toStringAsFixed(1)}°',
            valueColor: VColors.hazard(HazardClass.fromSlope(slope)),
            note: HazardClass.fromSlope(slope).label,
          ),
          KeyValue('Rover on station', 'Sol ${target.sol}', note: 'Mars 2020'),
          const SizedBox(height: 6),
          for (final r in target.references)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(r, style: VType.body(10.5, color: VColors.ash, height: 1.35)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              VButton(
                label: 'Add to walk',
                icon: Icons.add,
                dense: true,
                primary: true,
                onPressed: () {
                  planner.addStop(p, target: target);
                  ui.setWorkspace(Workspace.plan);
                },
              ),
              VButton(
                label: 'Set as base',
                icon: Icons.home_outlined,
                dense: true,
                onPressed: () {
                  planner.setBase(p, target: target);
                  ui.setWorkspace(Workspace.plan);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
