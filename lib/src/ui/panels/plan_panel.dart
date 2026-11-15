import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../mission/checkpoints.dart';
import '../../mission/mission_plan.dart';
import '../../routing/cost_model.dart';
import '../../science/eva_model.dart';
import '../../science/hazard.dart';
import '../../science/mars_time.dart';
import '../../science/provenance.dart';
import '../../state/app_state.dart';
import '../../theme/vivited_theme.dart';
import '../widgets/charts.dart';
import '../widgets/glyphs.dart';
import '../widgets/primitives.dart';
import 'atlas_panel.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.computing = false});
  final CheckStatus status;
  final bool computing;

  @override
  Widget build(BuildContext context) {
    final c = computing ? VColors.dust : checkColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: c)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, color: c),
          const SizedBox(width: 7),
          Text(
            computing ? 'ROUTING' : checkWord(status),
            style: VType.label(color: c, size: 9.5),
          ),
        ],
      ),
    );
  }
}

class PlanPanel extends ConsumerWidget {
  const PlanPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plannerProvider);
    final planner = ref.read(plannerProvider.notifier);
    final ui = ref.read(uiProvider.notifier);
    final pick = ref.watch(uiProvider.select((u) => u.pickMode));
    final plan = state.plan;
    final p = state.params;
    final data = ref.watch(dataProvider);
    final baseLat = state.base?.position.latitude ?? 18.44;
    final sunrise = MarsTime.sunriseLtst(ls: p.ls, latDeg: baseLat);
    final sunset = MarsTime.sunsetLtst(ls: p.ls, latDeg: baseLat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelHeader(
          kicker: 'Routes + science',
          title: 'Plan the walk',
          subtitle: 'Compare Routes A–D inside Jezero. Vivited routes each leg '
              'over the CTX terrain model and checks oxygen, daylight and the '
              'way home. These are educational planning corridors — not '
              'NASA-approved astronaut walking paths.',
          trailing: StatusPill(
            plan?.overall ?? CheckStatus.info,
            computing: state.computing,
          ),
        ),
        const SectionHeader('01', 'Mission routes'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in EvaPreset.all)
              VButton(
                label: preset.chipLabel,
                dense: true,
                active: state.presetId == preset.id,
                tooltip: preset.blurb,
                onPressed: () => planner.loadPreset(preset),
              ),
          ],
        ),
        if (state.presetId != null) ...[
          Builder(builder: (context) {
            final preset = EvaPreset.byId(state.presetId);
            if (preset == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(preset.title, style: VType.body(14, weight: 600)),
                      ),
                      const ProvenanceChip(SourceClass.simulation, compact: true),
                    ],
                  ),
                  if (preset.purpose != null) ...[
                    const SizedBox(height: 6),
                    Text(preset.purpose!, style: VType.body(12.5, color: VColors.dust)),
                  ],
                  if (preset.scienceObjective != null) ...[
                    const SizedBox(height: 8),
                    Text('SCIENCE OBJECTIVE', style: VType.label(size: 9)),
                    const SizedBox(height: 4),
                    Text(
                      preset.scienceObjective!,
                      style: VType.body(12, color: VColors.bone, height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(preset.blurb, style: VType.body(11.5, color: VColors.ash)),
                ],
              ),
            );
          }),
        ],
        SectionHeader(
          '02',
          'Itinerary',
          trailing: state.stops.length > 1
              ? MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: planner.clearStops,
                    child: Text('CLEAR', style: VType.label(size: 9)),
                  ),
                )
              : null,
        ),
        for (var i = 0; i < state.stops.length; i++)
          _StopRow(
            index: i,
            stop: state.stops[i],
            leg: plan != null && i > 0 && i - 1 < plan.legs.length
                ? plan.legs[i - 1]
                : null,
            last: i == state.stops.length - 1,
          ),
        if (p.returnToBase && plan != null && plan.legs.length == state.stops.length && state.stops.length > 1)
          _ReturnRow(leg: plan.legs.last),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            VButton(
              label: pick == PickMode.stop ? 'Tap the map…' : 'Add stop on map',
              icon: Icons.add_location_alt_outlined,
              dense: true,
              active: pick == PickMode.stop,
              onPressed: () => ui.setPickMode(
                pick == PickMode.stop ? PickMode.inspect : PickMode.stop,
              ),
            ),
            VButton(
              label: pick == PickMode.base ? 'Tap the map…' : 'Move base',
              icon: Icons.home_outlined,
              dense: true,
              active: pick == PickMode.base,
              onPressed: () => ui.setPickMode(
                pick == PickMode.base ? PickMode.inspect : PickMode.base,
              ),
            ),
          ],
        ),
        ToggleRow(
          label: 'Return to base',
          caption: 'Close the loop back to the airlock',
          value: p.returnToBase,
          onChanged: () => planner.updateParams(
            (q) => q.copyWith(returnToBase: !q.returnToBase),
          ),
        ),
        if (plan != null && plan.hasTrack) ...[
          const SectionHeader('03', 'Route measurements'),
          _Figures(plan: plan),
          const SizedBox(height: 8),
          KeyValue('Distance', formatDistance(plan.distanceM), note: 'along track'),
          KeyValue(
            'Elevation change',
            '${plan.minElevM.isFinite ? plan.minElevM.round() : '—'} → '
            '${plan.maxElevM.isFinite ? plan.maxElevM.round() : '—'} m',
            note: '↑${plan.ascentM.round()} ↓${plan.descentM.round()} m',
          ),
          KeyValue(
            'Max terrain slope',
            '${plan.maxTerrainSlopeDeg.toStringAsFixed(1)}°',
            valueColor: VColors.hazard(
              HazardClass.fromSlope(plan.maxTerrainSlopeDeg),
            ),
          ),
          KeyValue(
            'Estimated duration',
            formatDuration(plan.durationS),
            note: 'pace ${(plan.parameters.eva.paceFactor * 100).round()} %',
          ),
          KeyValue(
            'Oxygen (planning model)',
            '${(plan.o2Kg * 1000).round()} g',
            note: 'Santee / EMU assumptions',
          ),
          KeyValue(
            'Constraints',
            plan.overall == CheckStatus.pass
                ? 'Satisfied'
                : plan.overall == CheckStatus.warn
                    ? 'Caution'
                    : plan.overall == CheckStatus.fail
                        ? 'Not satisfied'
                        : 'See checks',
            valueColor: checkColor(plan.overall),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Evidence: CTX 20 m DTM slopes and elevations. Uncertainty: features '
              'smaller than ~60 m are invisible; walking models are Apollo-derived. '
              'Missing values show as unavailable rather than invented.',
              style: VType.body(11, color: VColors.ash),
            ),
          ),
          const SectionHeader('04', 'Profile'),
          ElevationProfile(
            plan: plan,
            onScrub: (t) {
              ref.read(simProvider.notifier).seek(t);
            },
          ),
          const SizedBox(height: 10),
          SegmentBar(
            values: plan.hazardDistanceM,
            colors: [for (final h in HazardClass.values) VColors.hazard(h)],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final h in HazardClass.values)
                if (plan.hazardDistanceM[h.index] > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 7, height: 7, color: VColors.hazard(h)),
                      const SizedBox(width: 5),
                      Text(
                        '${h.label} ${formatDistance(plan.hazardDistanceM[h.index])}',
                        style: VType.data(10, color: VColors.dust),
                      ),
                    ],
                  ),
            ],
          ),
        ],
        if (plan != null) ...[
          const SectionHeader('05', 'Go / no-go'),
          for (final c in plan.checks) CheckRow(c),
        ],
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Planner error: ${state.error}',
              style: VType.body(12, color: VColors.alarm),
            ),
          ),
        const SizedBox(height: 16),
        VButton(
          label: 'Rehearse this walk',
          icon: Icons.play_arrow,
          primary: true,
          onPressed: plan != null && plan.routeFound
              ? () => ui.setWorkspace(Workspace.simulate)
              : null,
        ),
        const SectionHeader('06', 'When'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SeasonDial(
              ls: p.ls,
              onChanged: (v) => planner.updateParams((q) => q.copyWith(ls: v)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Figure(
                    value: 'Ls ${p.ls.round()}°',
                    caption: MarsTime.seasonName(p.ls),
                    size: 30,
                  ),
                  const SizedBox(height: 12),
                  KeyValue('Sunrise', MarsTime.formatClock(sunrise)),
                  KeyValue('Sunset', MarsTime.formatClock(sunset)),
                  KeyValue(
                    'Sunlight',
                    '${MarsTime.solarFluxToa(p.ls).round()} W/m²',
                    note: 'top of atm.',
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          'Drag the planet along its orbit to set the season.',
          style: VType.data(10, color: VColors.ash),
        ),
        ParamSlider(
          label: 'Egress, local true solar time',
          value: p.startLtst,
          min: 5,
          max: 17,
          divisions: 48,
          display: MarsTime.formatClock(p.startLtst),
          onChanged: (v) =>
              planner.updateParams((q) => q.copyWith(startLtst: v)),
        ),
        const SizedBox(height: 14),
        DiurnalChart(
          climate: data.climate,
          ls: p.ls,
          latDeg: baseLat,
          evaStart: p.startLtst,
          evaEnd: plan != null && plan.hasTrack
              ? p.startLtst + plan.durationS / MissionPlan.marsHourS
              : null,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(width: 12, height: 2, color: VColors.bone),
            const SizedBox(width: 6),
            Text('Air 1.45 m', style: VType.data(10, color: VColors.dust)),
            const SizedBox(width: 14),
            Container(width: 12, height: 2, color: VColors.ember),
            const SizedBox(width: 6),
            Text('Ground', style: VType.data(10, color: VColors.dust)),
            const SizedBox(width: 14),
            Container(width: 10, height: 8, color: VColors.oxide.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            Text('EVA', style: VType.data(10, color: VColors.dust)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '°C against local true solar time. Perseverance MEDA, sols '
            '${data.climate.sample(p.ls, 12).solBefore}–'
            '${data.climate.sample(p.ls, 12).solAfter} bracketing this season.',
            style: VType.body(11, color: VColors.ash),
          ),
        ),
        const SectionHeader('07', 'Route and suit'),
        Text('Optimise for', style: VType.body(12.5, color: VColors.dust)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final o in RouteObjective.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: o == RouteObjective.values.last ? 0 : 6),
                  child: VButton(
                    label: o.label,
                    dense: true,
                    active: p.objective == o,
                    tooltip: o.description,
                    onPressed: () =>
                        planner.updateParams((q) => q.copyWith(objective: o)),
                  ),
                ),
              ),
          ],
        ),
        ParamSlider(
          label: 'Slope limit',
          value: p.maxSlopeDeg,
          min: 8,
          max: 25,
          divisions: 17,
          display: '${p.maxSlopeDeg.round()}°',
          onChanged: (v) =>
              planner.updateParams((q) => q.copyWith(maxSlopeDeg: v)),
        ),
        ParamSlider(
          label: 'Pace, share of Apollo-derived speed',
          value: p.eva.paceFactor,
          min: 0.4,
          max: 1,
          divisions: 12,
          display: '${(p.eva.paceFactor * 100).round()} %',
          note: 'Level pace ${(p.eva.speed(0) * 3.6).toStringAsFixed(1)} km/h',
          onChanged: (v) => planner.updateParams(
            (q) => q.copyWith(eva: q.eva.copyWith(paceFactor: v)),
          ),
        ),
        ParamSlider(
          label: 'Crew member',
          value: p.eva.crewMassKg,
          min: 50,
          max: 110,
          divisions: 12,
          display: '${p.eva.crewMassKg.round()} kg',
          onChanged: (v) => planner.updateParams(
            (q) => q.copyWith(eva: q.eva.copyWith(crewMassKg: v)),
          ),
        ),
        ParamSlider(
          label: 'Suit, life support and tools',
          value: p.eva.suitMassKg,
          min: 40,
          max: 160,
          divisions: 12,
          display: '${p.eva.suitMassKg.round()} kg',
          note:
              'Weighs ${(p.eva.totalMassKg * p.eva.gravity / 9.80665).round()} kg-force in total on Mars',
          onChanged: (v) => planner.updateParams(
            (q) => q.copyWith(eva: q.eva.copyWith(suitMassKg: v)),
          ),
        ),
        ParamSlider(
          label: 'Primary oxygen',
          value: p.lifeSupport.primaryO2Kg,
          min: 0.3,
          max: 1.5,
          divisions: 24,
          display: '${(p.lifeSupport.primaryO2Kg * 1000).round()} g',
          note: 'ISS EMU carries 550 g',
          onChanged: (v) => planner.updateParams(
            (q) => q.copyWith(lifeSupport: q.lifeSupport.copyWith(primaryO2Kg: v)),
          ),
        ),
        ParamSlider(
          label: 'Oxygen reserve on ingress',
          value: p.lifeSupport.reserveFraction,
          min: 0,
          max: 0.4,
          divisions: 8,
          display: '${(p.lifeSupport.reserveFraction * 100).round()} %',
          onChanged: (v) => planner.updateParams(
            (q) => q.copyWith(
              lifeSupport: q.lifeSupport.copyWith(reserveFraction: v),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Walking speed after Marquez (2008), metabolic cost after Santee '
            'et al. (2001), as used by NASA-funded SEXTANT planning. Suit '
            'masses and oxygen budget are editable assumptions, not flight '
            'values. See Sources.',
            style: VType.body(11, color: VColors.ash),
          ),
        ),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.plan});
  final MissionPlan plan;

  @override
  Widget build(BuildContext context) {
    final usable = plan.parameters.lifeSupport.usableO2Kg;
    final o2Color = plan.o2Kg > usable
        ? VColors.alarm
        : plan.o2Kg > 0.85 * usable
            ? VColors.sulfur
            : VColors.bone;
    final h = plan.durationS ~/ 3600, m = ((plan.durationS % 3600) / 60).round();
    final figures = [
      Figure(
        value: (plan.distanceM / 1000).toStringAsFixed(2),
        unit: 'km',
        caption: 'On foot',
      ),
      Figure(
        value: '$h:${m.toString().padLeft(2, '0')}',
        unit: 'h',
        caption: 'Airlock to airlock',
      ),
      Figure(
        value: '${(plan.o2Kg * 1000).round()}',
        unit: 'g O₂',
        caption: 'Oxygen breathed',
        color: o2Color,
      ),
      Figure(
        value: '${EvaModel.kcal(plan.energyJ).round()}',
        unit: 'kcal',
        caption: 'Metabolic work',
      ),
      Figure(
        value: '${plan.ascentM.round()}',
        unit: 'm',
        caption: 'Total climb',
      ),
      Figure(
        value: '${plan.doseUsv.round()}',
        unit: 'µSv',
        caption: 'Cosmic-ray dose',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 20,
          children: [for (final f in figures) SizedBox(width: w, child: f)],
        );
      },
    );
  }
}

String _stopCaption(EvaStop stop, bool isBase) {
  final cp = MissionCheckpoint.forTarget(stop.targetId);
  if (isBase) {
    return cp != null ? '${cp.code} · ${cp.role}' : 'Airlock · egress and ingress';
  }
  if (cp != null) {
    return '${cp.code} · station ${stop.dwellMinutes.round()} min';
  }
  return 'Station work ${stop.dwellMinutes.round()} min';
}

class _StopRow extends ConsumerWidget {
  const _StopRow({required this.index, required this.stop, required this.leg, required this.last});
  final int index;
  final EvaStop stop;
  final LegSummary? leg;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planner = ref.read(plannerProvider.notifier);
    final isBase = index == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leg != null) _LegLine(leg: leg!),
        Row(
          children: [
            SizedBox(width: 26, child: Center(child: StopGlyph(index: index))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VType.body(13.5, weight: 500),
                  ),
                  Text(
                    _stopCaption(stop, isBase),
                    style: VType.data(10, color: VColors.ash),
                  ),
                ],
              ),
            ),
            if (!isBase) ...[
              _MiniIcon(Icons.remove, 'Less time on station',
                  () => planner.setDwell(index, (stop.dwellMinutes - 5).clamp(0, 120))),
              _MiniIcon(Icons.add, 'More time on station',
                  () => planner.setDwell(index, (stop.dwellMinutes + 5).clamp(0, 120))),
              _MiniIcon(Icons.keyboard_arrow_up, 'Visit earlier',
                  index > 1 ? () => planner.moveStop(index, -1) : null),
              _MiniIcon(Icons.keyboard_arrow_down, 'Visit later',
                  !last ? () => planner.moveStop(index, 1) : null),
              _MiniIcon(Icons.close, 'Remove stop', () => planner.removeStop(index)),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReturnRow extends StatelessWidget {
  const _ReturnRow({required this.leg});
  final LegSummary leg;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegLine(leg: leg),
          Row(
            children: [
              const SizedBox(width: 26, child: Center(child: StopGlyph(index: 0))),
              const SizedBox(width: 10),
              Text('Return to airlock', style: VType.body(13.5, color: VColors.dust)),
            ],
          ),
        ],
      );
}

class _LegLine extends StatelessWidget {
  const _LegLine({required this.leg});
  final LegSummary leg;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: Row(
          children: [
            const SizedBox(
              width: 26,
              child: Center(child: Hairline(vertical: true, color: VColors.ruleStrong)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                leg.found
                    ? '${formatDistance(leg.distanceM)}  ·  ${formatDuration(leg.timeS)}'
                        '  ·  ↑${leg.ascentM.round()} ↓${leg.descentM.round()} m'
                    : 'No walkable route within the slope limit',
                style: VType.data(
                  10.5,
                  color: leg.found ? VColors.dust : VColors.alarm,
                ),
              ),
            ),
          ],
        ),
      );
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon(this.icon, this.tooltip, this.onTap);
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: MouseRegion(
            cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  icon,
                  size: 15,
                  color: onTap == null ? VColors.rule : VColors.dust,
                ),
              ),
            ),
          ),
        ),
      );
}
