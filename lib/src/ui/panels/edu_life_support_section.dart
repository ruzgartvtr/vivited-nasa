import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../science/edu_life_support.dart';
import '../../science/provenance.dart';
import '../../state/demo_guide.dart';
import '../../theme/vivited_theme.dart';
import '../widgets/primitives.dart';

/// Educational oxygen / energy arithmetic for the jury demonstration.
class EduLifeSupportSection extends ConsumerWidget {
  const EduLifeSupportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edu = ref.watch(eduLifeSupportProvider);
    final ctl = ref.read(eduLifeSupportProvider.notifier);
    final warn = !edu.safe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('05', 'Educational life-support simulator'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: warn ? VColors.alarm : VColors.ruleStrong,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      EduLifeSupport.disclaimer,
                      style: VType.label(
                        color: warn ? VColors.alarm : VColors.sulfur,
                        size: 8.5,
                      ),
                    ),
                  ),
                  const ProvenanceChip(SourceClass.simulation, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Transparent teaching units (not EMU kilograms). Formula: '
                'consumed = mission minutes × rate; remaining = starting − '
                'consumed. Safe when consumed + reserve ≤ starting.',
                style: VType.body(11.5, color: VColors.dust),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            VButton(
              label: 'Sample scenario',
              dense: true,
              onPressed: ctl.resetSample,
            ),
            VButton(
              label: 'Sync from plan',
              dense: true,
              tooltip: 'Use walk and science dwell times from the current route',
              onPressed: ctl.syncFromPlan,
            ),
          ],
        ),
        ParamSlider(
          label: 'Starting oxygen',
          value: edu.startingOxygen,
          min: 40,
          max: 200,
          divisions: 32,
          display: edu.startingOxygen.toStringAsFixed(0),
          note: 'educational units',
          onChanged: (v) => ctl.update((e) => e.copyWith(startingOxygen: v)),
        ),
        ParamSlider(
          label: 'Oxygen rate',
          value: edu.oxygenRatePerMin,
          min: 0.1,
          max: 1.0,
          divisions: 18,
          display: '${edu.oxygenRatePerMin.toStringAsFixed(2)} / min',
          onChanged: (v) => ctl.update((e) => e.copyWith(oxygenRatePerMin: v)),
        ),
        ParamSlider(
          label: 'Oxygen reserve',
          value: edu.oxygenReserve,
          min: 0,
          max: 60,
          divisions: 12,
          display: edu.oxygenReserve.toStringAsFixed(0),
          onChanged: (v) => ctl.update((e) => e.copyWith(oxygenReserve: v)),
        ),
        ParamSlider(
          label: 'Travel duration',
          value: edu.travelMinutes,
          min: 10,
          max: 360,
          divisions: 35,
          display: '${edu.travelMinutes.round()} min',
          onChanged: (v) => ctl.update((e) => e.copyWith(travelMinutes: v)),
        ),
        ParamSlider(
          label: 'Science activity',
          value: edu.scienceMinutes,
          min: 0,
          max: 180,
          divisions: 36,
          display: '${edu.scienceMinutes.round()} min',
          onChanged: (v) => ctl.update((e) => e.copyWith(scienceMinutes: v)),
        ),
        ParamSlider(
          label: 'Starting battery',
          value: edu.startingBattery,
          min: 40,
          max: 200,
          divisions: 32,
          display: edu.startingBattery.toStringAsFixed(0),
          onChanged: (v) => ctl.update((e) => e.copyWith(startingBattery: v)),
        ),
        ParamSlider(
          label: 'Energy rate',
          value: edu.energyRatePerMin,
          min: 0.05,
          max: 0.8,
          divisions: 15,
          display: '${edu.energyRatePerMin.toStringAsFixed(2)} / min',
          onChanged: (v) => ctl.update((e) => e.copyWith(energyRatePerMin: v)),
        ),
        ParamSlider(
          label: 'Battery reserve',
          value: edu.batteryReserve,
          min: 0,
          max: 50,
          divisions: 10,
          display: edu.batteryReserve.toStringAsFixed(0),
          onChanged: (v) => ctl.update((e) => e.copyWith(batteryReserve: v)),
        ),
        const SizedBox(height: 12),
        KeyValue(
          'Mission duration',
          '${edu.missionMinutes.toStringAsFixed(0)} min',
          note: 'travel + science',
        ),
        KeyValue(
          'Oxygen consumed',
          edu.oxygenConsumed.toStringAsFixed(1),
          note: '${edu.missionMinutes.toStringAsFixed(0)} × ${edu.oxygenRatePerMin}',
        ),
        KeyValue(
          'Oxygen remaining',
          edu.oxygenRemaining.toStringAsFixed(1),
          valueColor: edu.oxygenOk ? VColors.lichen : VColors.alarm,
          note: edu.oxygenOk ? 'reserve OK' : 'reserve not met',
        ),
        KeyValue(
          'Energy consumed',
          edu.energyConsumed.toStringAsFixed(1),
        ),
        KeyValue(
          'Energy remaining',
          edu.energyRemaining.toStringAsFixed(1),
          valueColor: edu.energyOk ? VColors.lichen : VColors.alarm,
          note: edu.energyOk ? 'reserve OK' : 'reserve not met',
        ),
        if (warn) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: VColors.alarm.withValues(alpha: 0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EduLifeSupport.returnWarning,
                  style: VType.body(14, weight: 700, color: VColors.alarm),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated consumption plus the required reserve exceeds the '
                  'starting budget. Shorten the walk, reduce science time, or '
                  'return toward Habitat H0.',
                  style: VType.body(12, color: VColors.dust),
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Sample check: 120 min × 0.3 = 36 units consumed; 100 − 36 = 64 '
            'remaining with a 20-unit reserve → satisfied. These numbers are '
            'not astronaut oxygen-system specifications.',
            style: VType.body(11, color: VColors.ash),
          ),
        ),
      ],
    );
  }
}
