import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mission/checkpoints.dart';
import '../science/edu_life_support.dart';
import 'app_state.dart';

/// One beat of the ~3-minute jury demonstration.
class DemoStep {
  const DemoStep({
    required this.index,
    required this.title,
    required this.narration,
    required this.apply,
  });

  final int index;
  final String title;
  final String narration;
  final void Function(Ref ref) apply;
}

/// Guided walkthrough that drives the real UI — no fake screens.
class DemoGuide {
  DemoGuide._();

  static final steps = <DemoStep>[
    DemoStep(
      index: 1,
      title: 'Open Vivited',
      narration:
          'Vivited is a Jezero crater exploration map. Everything that follows '
          'uses bundled NASA observations and transparent planning models.',
      apply: (ref) {
        ref.read(uiProvider.notifier).setView(StageView.orbit);
        ref.read(uiProvider.notifier).setWorkspace(Workspace.atlas);
      },
    ),
    DemoStep(
      index: 2,
      title: 'Jezero exploration region',
      narration:
          'Enter the site atlas. The 20 m CTX terrain model covers the crater '
          'floor, delta and rim that Perseverance has been surveying.',
      apply: (ref) {
        ref.read(uiProvider.notifier).enterSite();
        ref.read(uiProvider.notifier).setWorkspace(Workspace.atlas);
        ref.read(uiProvider.notifier).setBasemap(Basemap.imagery);
      },
    ),
    DemoStep(
      index: 3,
      title: 'Habitat H0',
      narration:
          'Habitat H0 is a simulated airlock at Three Forks — flat ground NASA '
          'already used as a sample depot. The habitat is fiction; the place is not.',
      apply: (ref) {
        final h0 = MissionCheckpoint.byCode('H0')!;
        final t = ref.read(dataProvider).target(h0.targetId)!;
        ref.read(uiProvider.notifier).selectTarget(t.id, fly: true, target: t);
        ref.read(uiProvider.notifier)
          ..setShowCheckpoints(true)
          ..setWorkspace(Workspace.atlas);
      },
    ),
    DemoStep(
      index: 4,
      title: 'Optical surface data',
      narration:
          'CTX orthomosaic imagery shows rocks, scarps and visible obstacles '
          'astronauts would use to judge the ground ahead.',
      apply: (ref) {
        final ui = ref.read(uiProvider.notifier);
        ui.setBasemap(Basemap.imagery);
        ui.setOverlays({});
        ui.setView(StageView.map);
      },
    ),
    DemoStep(
      index: 5,
      title: 'Terrain and elevation',
      narration:
          'Switch to shaded relief and the slope-hazard layer. Elevation and '
          'slope come from the USGS Mars 2020 CTX stereo DTM.',
      apply: (ref) {
        final ui = ref.read(uiProvider.notifier);
        ui.setBasemap(Basemap.relief);
        ui.setOverlays({MapOverlay.hazard});
        ui.setView(StageView.map);
      },
    ),
    DemoStep(
      index: 6,
      title: 'Historical MEDA weather',
      narration:
          'In Plan, the diurnal chart shows Perseverance MEDA climatology — '
          'past sols by season, not live weather.',
      apply: (ref) {
        ref.read(uiProvider.notifier).setWorkspace(Workspace.plan);
        ref.read(uiProvider.notifier).setOverlays({});
        ref.read(uiProvider.notifier).setBasemap(Basemap.imagery);
      },
    ),
    DemoStep(
      index: 7,
      title: 'Route A · Safe Access',
      narration:
          'Load Route A: from Habitat H0 toward the delta scarp on manageable '
          'terrain. Distance, climb and oxygen update from the terrain model.',
      apply: (ref) {
        ref.read(uiProvider.notifier).setWorkspace(Workspace.plan);
        ref.read(uiProvider.notifier).setView(StageView.map);
        ref.read(plannerProvider.notifier).loadPreset(EvaPreset.byId('route-a')!);
      },
    ),
    DemoStep(
      index: 8,
      title: 'Route B · Validation',
      narration:
          'Route B visits crater-floor stations where a crew could check early '
          'robotic geology against new field observations.',
      apply: (ref) {
        ref.read(plannerProvider.notifier).loadPreset(EvaPreset.byId('route-b')!);
      },
    ),
    DemoStep(
      index: 9,
      title: 'Route C · Discovery',
      narration:
          'Route C reaches Bright Angel / Cheyava Falls — a discovery stop for '
          'a new geological question about organic-associated reaction fronts.',
      apply: (ref) {
        ref.read(plannerProvider.notifier).loadPreset(EvaPreset.byId('route-c')!);
      },
    ),
    DemoStep(
      index: 10,
      title: 'Route D · Return',
      narration:
          'Route D is a one-way return from the fan-front science zone back to '
          'Habitat H0, tied directly to walk-back and life-support checks.',
      apply: (ref) {
        ref.read(plannerProvider.notifier).loadPreset(EvaPreset.byId('route-d')!);
      },
    ),
    DemoStep(
      index: 11,
      title: 'Life-support simulator',
      narration:
          'Open Rehearse. Below the EVA clock is the educational oxygen and '
          'energy simulator — transparent units, not a flight suit.',
      apply: (ref) {
        ref.read(uiProvider.notifier).setWorkspace(Workspace.simulate);
        ref.read(eduLifeSupportProvider.notifier).resetSample();
      },
    ),
    DemoStep(
      index: 12,
      title: 'Change mission duration',
      narration:
          'Lengthen travel time. Consumed oxygen and energy rise with the same '
          'formulas shown on screen.',
      apply: (ref) {
        ref.read(uiProvider.notifier).setWorkspace(Workspace.simulate);
        ref.read(eduLifeSupportProvider.notifier).apply(const EduLifeSupport(
          travelMinutes: 200,
          scienceMinutes: 40,
        ));
      },
    ),
    DemoStep(
      index: 13,
      title: 'Resource warning',
      narration:
          'When consumption plus reserve exceeds the starting budget, Vivited '
          'shows: Return to Habitat / Reduce Mission Time.',
      apply: (ref) {
        ref.read(eduLifeSupportProvider.notifier).apply(const EduLifeSupport(
          startingOxygen: 100,
          oxygenRatePerMin: 0.3,
          oxygenReserve: 20,
          travelMinutes: 280,
          scienceMinutes: 40,
        ));
      },
    ),
    DemoStep(
      index: 14,
      title: 'Scientific sources',
      narration:
          'Sources lists every NASA product, method and limit — with links you '
          'can copy. Nothing is anonymous.',
      apply: (ref) {
        ref.read(uiProvider.notifier).setWorkspace(Workspace.sources);
      },
    ),
    DemoStep(
      index: 15,
      title: 'Mission summary',
      narration:
          'One map ties optical data, topography, MEDA climate, four routes and '
          'an honest life-support check to the question: how can astronauts '
          'explore Jezero safely?',
      apply: (ref) {
        ref.read(uiProvider.notifier).setWorkspace(Workspace.atlas);
        ref.read(uiProvider.notifier).setView(StageView.map);
        ref.read(uiProvider.notifier).setShowCheckpoints(true);
        ref.read(plannerProvider.notifier).loadPreset(EvaPreset.byId('route-a')!);
        ref.read(eduLifeSupportProvider.notifier).resetSample();
      },
    ),
  ];
}

class DemoState {
  const DemoState({this.active = false, this.stepIndex = 0});
  final bool active;
  final int stepIndex;

  DemoStep get step =>
      DemoGuide.steps[stepIndex.clamp(0, DemoGuide.steps.length - 1)];
  bool get isFirst => stepIndex <= 0;
  bool get isLast => stepIndex >= DemoGuide.steps.length - 1;

  DemoState copyWith({bool? active, int? stepIndex}) => DemoState(
        active: active ?? this.active,
        stepIndex: stepIndex ?? this.stepIndex,
      );
}

class DemoController extends Notifier<DemoState> {
  @override
  DemoState build() => const DemoState();

  void start() {
    state = const DemoState(active: true);
    DemoGuide.steps.first.apply(ref);
  }

  void stop() => state = const DemoState();

  void next() {
    if (state.isLast) {
      stop();
      return;
    }
    final i = state.stepIndex + 1;
    state = state.copyWith(stepIndex: i);
    DemoGuide.steps[i].apply(ref);
  }

  void previous() {
    if (state.isFirst) return;
    final i = state.stepIndex - 1;
    state = state.copyWith(stepIndex: i);
    DemoGuide.steps[i].apply(ref);
  }
}

final demoProvider = NotifierProvider<DemoController, DemoState>(DemoController.new);

/// Educational life-support knobs (separate from the EMU planner model).
class EduLifeSupportController extends Notifier<EduLifeSupport> {
  @override
  EduLifeSupport build() => EduLifeSupport.sampleScenario;

  void resetSample() => state = EduLifeSupport.sampleScenario;

  void apply(EduLifeSupport next) => state = next;

  void update(EduLifeSupport Function(EduLifeSupport) f) => state = f(state);

  void syncFromPlan() {
    final plan = ref.read(plannerProvider).plan;
    if (plan == null || !plan.hasTrack) return;
    state = state.syncedToPlan(
      walkSeconds: plan.walkS,
      dwellSeconds: plan.dwellS,
    );
  }
}

final eduLifeSupportProvider =
    NotifierProvider<EduLifeSupportController, EduLifeSupport>(
  EduLifeSupportController.new,
);
