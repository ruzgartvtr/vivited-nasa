import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../mission/mission_plan.dart';
import '../../science/geodesy.dart';
import '../../science/mars_time.dart';
import '../../science/provenance.dart';
import '../../state/app_state.dart';
import '../../theme/vivited_theme.dart';
import '../widgets/charts.dart';
import '../widgets/primitives.dart';
import 'atlas_panel.dart';
import 'edu_life_support_section.dart';

/// Rehearsal: the evaluated plan played against the clock, with live
/// telemetry derived from the same models that produced the plan.
class SimulatePanel extends ConsumerWidget {
  const SimulatePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(plannerProvider.select((p) => p.plan));
    final computing = ref.watch(plannerProvider.select((p) => p.computing));
    if (plan == null || !plan.hasTrack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelHeader(
            kicker: 'Life support + rehearsal',
            title: 'Nothing to rehearse',
            subtitle: 'Build a walk with at least one reachable stop, then '
                'come back to fly its timeline. The educational simulator '
                'below still works with the sample scenario.',
          ),
          const SizedBox(height: 20),
          VButton(
            label: computing ? 'Routing…' : 'Open the planner',
            icon: Icons.route_outlined,
            primary: true,
            onPressed: computing
                ? null
                : () => ref.read(uiProvider.notifier).setWorkspace(Workspace.plan),
          ),
          const EduLifeSupportSection(),
        ],
      );
    }
    final sim = ref.watch(simProvider);
    final ctl = ref.read(simProvider.notifier);
    final st = ref.watch(evaStateProvider)!;
    final lss = plan.parameters.lifeSupport;
    final reserve = lss.primaryO2Kg * lss.reserveFraction;
    final o2Color = st.o2RemainingKg < reserve
        ? VColors.alarm
        : st.o2RemainingKg < reserve + 0.15 * lss.usableO2Kg
            ? VColors.sulfur
            : VColors.lichen;
    final c = st.climate;
    String opt(double? v, String unit, [int digits = 0]) =>
        v == null ? 'no data' : '${v.toStringAsFixed(digits)} $unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'LIFE SUPPORT + REHEARSAL · MISSION ELAPSED TIME',
                style: VType.label(),
              ),
            ),
            const ProvenanceChip(SourceClass.interpretation, compact: true),
            const SizedBox(width: 8),
            Text('LTST ${MarsTime.formatClock(st.ltst)}', style: VType.data(11, color: VColors.dust)),
          ],
        ),
        const SizedBox(height: 8),
        Text(formatMet(st.timeS), style: VType.display(64)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              color: st.walking ? VColors.oxide : VColors.ice,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                st.activity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VType.body(13.5, weight: 500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VButton(
                  label: sim.playing
                      ? 'Pause'
                      : (sim.timeS >= plan.durationS ? 'Replay' : 'Play'),
                  icon: sim.playing ? Icons.pause : Icons.play_arrow,
                  primary: true,
                  onPressed: ctl.toggle,
                ),
                const SizedBox(width: 8),
                VButton(label: 'Reset', icon: Icons.skip_previous, onPressed: ctl.reset),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in SimState.rates)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: VButton(
                      label: '${(r / 60).round()}×',
                      dense: true,
                      active: sim.rate == r,
                      tooltip: '${(r / 60).round()} minutes of EVA per second',
                      onPressed: () => ctl.setRate(r),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 28,
          child: Slider(
            value: sim.timeS.clamp(0.0, plan.durationS),
            max: plan.durationS,
            onChanged: ctl.seek,
            semanticFormatterCallback: (v) => 'Elapsed ${formatMet(v)}',
          ),
        ),
        Row(
          children: [
            Text('0:00:00', style: VType.data(10, color: VColors.ash)),
            const Spacer(),
            Text(formatMet(plan.durationS), style: VType.data(10, color: VColors.ash)),
          ],
        ),
        const SectionHeader('01', 'Life support'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Figure(
                value: '${(st.o2RemainingKg * 1000).round()}',
                unit: 'g',
                caption: 'Primary oxygen left',
                color: o2Color,
              ),
            ),
            Expanded(
              child: Figure(
                value: st.walkBackS.isFinite
                    ? '${(st.walkBackS / 60).round()}'
                    : (st.walkBackS.isNaN ? '—' : '>150'),
                unit: 'min',
                caption: 'Walk-back to airlock',
              ),
            ),
            Expanded(
              child: Figure(
                value: '${st.metabolicW.round()}',
                unit: 'W',
                caption: 'Metabolic rate',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Gauge(
          fraction: st.o2RemainingKg / lss.primaryO2Kg,
          marker: lss.reserveFraction,
          color: o2Color,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('Reserve ${(reserve * 1000).round()} g',
                style: VType.data(10, color: VColors.ash)),
            const Spacer(),
            Text('${(lss.primaryO2Kg * 1000).round()} g',
                style: VType.data(10, color: VColors.ash)),
          ],
        ),
        const SectionHeader('02', 'Traverse'),
        KeyValue('Distance walked',
            '${formatDistance(st.distM)} of ${formatDistance(plan.distanceM)}'),
        KeyValue('Speed', '${(st.speedMs * 3.6).toStringAsFixed(2)} km/h'),
        KeyValue(
          'Grade underfoot',
          '${st.slopeDeg >= 0 ? '+' : ''}${st.slopeDeg.toStringAsFixed(1)}°',
          valueColor: VColors.hazard(st.hazard),
          note: st.hazard.label,
        ),
        KeyValue('Heading',
            '${st.headingDeg.round().toString().padLeft(3, '0')}° ${Geodesy.compass(st.headingDeg)}'),
        KeyValue('Elevation', '${st.elevM.round()} m'),
        KeyValue('Position',
            '${st.position.latitude.toStringAsFixed(4)}°N ${st.position.longitude.toStringAsFixed(4)}°E'),
        const SizedBox(height: 10),
        ElevationProfile(plan: plan, playheadS: st.timeS, onScrub: ctl.seek, height: 104),
        const SectionHeader('03', 'Environment'),
        KeyValue(
          'Sun',
          st.sunElevationDeg > 0
              ? '${st.sunElevationDeg.toStringAsFixed(0)}° up, bearing ${st.sunAzimuthDeg.round()}°'
              : 'Below horizon',
          valueColor: st.sunElevationDeg > 10
              ? VColors.bone
              : (st.sunElevationDeg > 0 ? VColors.sulfur : VColors.alarm),
        ),
        KeyValue('Air temperature', opt(c?.airTempC, '°C'), note: 'MEDA'),
        KeyValue('Ground temperature', opt(c?.groundTempC, '°C'), note: 'MEDA'),
        KeyValue('Pressure', opt(c?.pressurePa, 'Pa'), note: 'MEDA'),
        KeyValue('Wind', opt(c?.windMs, 'm/s', 1), note: 'MEDA'),
        KeyValue('Radiation dose', '${st.doseUsv.toStringAsFixed(1)} µSv', note: 'RAD'),
        const SizedBox(height: 10),
        DiurnalChart(
          climate: plan.climatology!,
          ls: plan.parameters.ls,
          latDeg: plan.baseLat,
          evaStart: plan.parameters.startLtst,
          evaEnd: plan.parameters.startLtst + plan.durationS / MissionPlan.marsHourS,
          nowLtst: plan.parameters.startLtst + st.timeS / MissionPlan.marsHourS,
          height: 110,
        ),
        const SectionHeader('04', 'Timeline'),
        for (final e in plan.events) _EventRow(event: e, now: st.timeS),
        const EduLifeSupportSection(),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'MEDA values above are historical climatology at Perseverance\'s '
            'location — not a live forecast. Radiation is Gale-crater RAD '
            'prorated over the walk. See Sources.',
            style: VType.body(11, color: VColors.ash),
          ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.now});
  final MissionEvent event;
  final double now;

  @override
  Widget build(BuildContext context) {
    final past = event.timeS <= now + 0.5;
    final color = switch (event.severity) {
      EventSeverity.info => VColors.bone,
      EventSeverity.caution => VColors.sulfur,
      EventSeverity.warning => VColors.alarm,
    };
    return Opacity(
      opacity: past ? 1 : 0.42,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(formatMet(event.timeS), style: VType.data(11, color: VColors.dust)),
            ),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: past ? color : Colors.transparent,
                border: Border.all(color: color),
              ),
            ),
            Expanded(child: Text(event.message, style: VType.body(12.5, color: color))),
          ],
        ),
      ),
    );
  }
}
