import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/data_repository.dart';
import '../data/models.dart';
import '../mission/mission_plan.dart';
import '../mission/planner.dart';
import '../render/rasters.dart';
import '../routing/cost_model.dart';
import '../routing/pathfinder.dart';
import 'launch_options.dart';

/// Initial state requested by the page address (empty in tests).
final launchOptionsProvider =
    Provider<LaunchOptions>((ref) => const LaunchOptions());

// ---- Data ---------------------------------------------------------------------

final repositoryProvider = Provider<DataRepository>((ref) => DataRepository());

final appDataProvider = FutureProvider<AppData>(
  (ref) => ref.watch(repositoryProvider).load(),
);

/// Synchronous access once the app shell is mounted.
final dataProvider = Provider<AppData>(
  (ref) => ref.watch(appDataProvider).requireValue,
);

final rastersProvider = Provider<TerrainRasters>(
  (ref) => TerrainRasters(ref.watch(dataProvider)),
);

// ---- Interface state ----------------------------------------------------------

enum Workspace {
  atlas('Atlas', 'Mission + map · Jezero region'),
  plan('Plan', 'Routes + science · A–D'),
  simulate('Rehearse', 'Life support + timeline'),
  sources('Sources', 'Data, methods, limits');

  const Workspace(this.label, this.hint);
  final String label;
  final String hint;
}

enum StageView {
  orbit('Orbit'),
  map('Map'),
  terrain('Terrain');

  const StageView(this.label);
  final String label;
}

enum Basemap {
  imagery('CTX imagery', 'MRO Context Camera orthomosaic'),
  relief('Shaded relief', 'CTX stereo elevation, 25 m contours');

  const Basemap(this.label, this.source);
  final String label;
  final String source;
}

enum MapOverlay {
  hazard('Slope hazard', 'MRO CTX DTM · 20 m'),
  thermal('Night infrared', 'Odyssey THEMIS · 100 m'),
  solar('Solar exposure', 'Computed · DTM + Mars24'),
  illumination('Shadows at EVA time', 'Computed · DTM + Mars24'),
  walkBack('Walk-back time', 'Computed · Dijkstra field');

  const MapOverlay(this.label, this.source);
  final String label;
  final String source;
}

/// What a tap on the map does.
enum PickMode { inspect, base, stop }

class UiState {
  const UiState({
    this.workspace = Workspace.atlas,
    this.view = StageView.orbit,
    this.basemap = Basemap.imagery,
    this.overlays = const {},
    this.showTraverse = true,
    this.showTargets = true,
    this.showCheckpoints = true,
    this.selectedTargetId,
    this.pickMode = PickMode.inspect,
    this.introSeen = false,
    this.focus,
  });

  final Workspace workspace;
  final StageView view;
  final Basemap basemap;
  final Set<MapOverlay> overlays;
  final bool showTraverse;
  final bool showTargets;

  /// Educational mission marks H0 / CP1–CP3 / SH.
  final bool showCheckpoints;
  final String? selectedTargetId;
  final PickMode pickMode;
  final bool introSeen;

  /// A request for the map to fly somewhere; consumed by the map stage.
  final MapFocus? focus;

  UiState copyWith({
    Workspace? workspace,
    StageView? view,
    Basemap? basemap,
    Set<MapOverlay>? overlays,
    bool? showTraverse,
    bool? showTargets,
    bool? showCheckpoints,
    String? Function()? selectedTargetId,
    PickMode? pickMode,
    bool? introSeen,
    MapFocus? focus,
  }) =>
      UiState(
        workspace: workspace ?? this.workspace,
        view: view ?? this.view,
        basemap: basemap ?? this.basemap,
        overlays: overlays ?? this.overlays,
        showTraverse: showTraverse ?? this.showTraverse,
        showTargets: showTargets ?? this.showTargets,
        showCheckpoints: showCheckpoints ?? this.showCheckpoints,
        selectedTargetId:
            selectedTargetId != null ? selectedTargetId() : this.selectedTargetId,
        pickMode: pickMode ?? this.pickMode,
        introSeen: introSeen ?? this.introSeen,
        focus: focus ?? this.focus,
      );
}

class MapFocus {
  MapFocus(this.center, {this.zoom, this.bounds});
  final LatLng center;
  final double? zoom;
  final (LatLng, LatLng)? bounds;
}

class UiController extends Notifier<UiState> {
  @override
  UiState build() {
    final o = ref.watch(launchOptionsProvider);
    if (o.isEmpty) return const UiState();
    // Any explicit request skips the orbital introduction unless it asks
    // for the globe itself.
    final workspace = o.workspace ?? Workspace.atlas;
    return UiState(
      workspace: workspace,
      view: o.view ?? StageView.map,
      basemap: o.basemap ?? Basemap.imagery,
      overlays: o.overlays,
      introSeen: true,
    );
  }

  void setWorkspace(Workspace w) {
    var s = state.copyWith(workspace: w, pickMode: PickMode.inspect);
    if (s.view == StageView.orbit && w != Workspace.sources) {
      s = s.copyWith(view: StageView.map, introSeen: true);
    }
    state = s;
  }

  void setView(StageView v) =>
      state = state.copyWith(view: v, introSeen: true);

  void enterSite() => state = state.copyWith(
        view: StageView.map,
        introSeen: true,
        workspace: Workspace.atlas,
      );

  void setBasemap(Basemap b) => state = state.copyWith(basemap: b);

  void toggleOverlay(MapOverlay o) {
    final next = {...state.overlays};
    if (!next.remove(o)) next.add(o);
    state = state.copyWith(overlays: next);
  }

  void toggleTraverse() =>
      state = state.copyWith(showTraverse: !state.showTraverse);

  void toggleTargets() =>
      state = state.copyWith(showTargets: !state.showTargets);

  void toggleCheckpoints() =>
      state = state.copyWith(showCheckpoints: !state.showCheckpoints);

  void setShowCheckpoints(bool v) =>
      state = state.copyWith(showCheckpoints: v);

  void setOverlays(Set<MapOverlay> overlays) =>
      state = state.copyWith(overlays: overlays);

  void selectTarget(String? id, {bool fly = false, ScienceTarget? target}) {
    state = state.copyWith(
      selectedTargetId: () => id,
      focus: fly && target != null ? MapFocus(target.position, zoom: 12.6) : null,
    );
  }

  void setPickMode(PickMode m) => state = state.copyWith(
        pickMode: m,
        view: m == PickMode.inspect ? null : StageView.map,
      );

  void focusOn(MapFocus f) => state = state.copyWith(focus: f);
}

final uiProvider = NotifierProvider<UiController, UiState>(UiController.new);

/// Coordinate under the pointer (or last tap) for the inspector read-out.
class CursorController extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;
  void set(LatLng? p) => state = p;
}

final cursorProvider =
    NotifierProvider<CursorController, LatLng?>(CursorController.new);

// ---- Planner ------------------------------------------------------------------

class EvaPreset {
  const EvaPreset({
    required this.id,
    required this.title,
    required this.blurb,
    required this.baseTarget,
    required this.stopTargets,
    this.ls = 90,
    this.startLtst = 9,
    this.routeLetter,
    this.purpose,
    this.scienceObjective,
    this.aliases = const [],
    this.returnToBase = true,
    this.objective,
    this.buttonLabel,
  });

  final String id;
  final String title;
  final String blurb;
  final String baseTarget;
  final List<String> stopTargets;
  final double ls;
  final double startLtst;

  /// Educational letter A–D, or null for the rim stress case.
  final String? routeLetter;
  final String? purpose;
  final String? scienceObjective;
  final List<String> aliases;
  final bool returnToBase;
  final RouteObjective? objective;

  /// Short chip label in the Plan panel.
  final String? buttonLabel;

  String get chipLabel =>
      buttonLabel ?? (routeLetter != null ? 'Route $routeLetter' : title);

  static EvaPreset? byId(String? id) {
    if (id == null) return null;
    for (final p in all) {
      if (p.id == id || p.aliases.contains(id)) return p;
    }
    return null;
  }

  /// Four educational routes plus the rim stress case (checks must refuse it).
  static const all = [
    EvaPreset(
      id: 'route-a',
      aliases: ['delta-front'],
      routeLetter: 'A',
      buttonLabel: 'A · Safe Access',
      title: 'Route A · Safe Access',
      purpose: 'Reach the fan-front exploration region on manageable terrain.',
      scienceObjective:
          'Inspect surface conditions at CP1 (Amalik) and establish a safe '
          'corridor from Habitat H0 across the crater-floor / fan contact.',
      blurb: 'From Habitat H0 at Three Forks to the delta-scarp terrain '
          'checkpoint (Amalik) and the validation mudstones at Wildcat Ridge. '
          'Favours walkable ground — not a NASA-approved walking path.',
      baseTarget: 'threeforks',
      stopTargets: ['amalik', 'wildcat'],
      objective: RouteObjective.safest,
    ),
    EvaPreset(
      id: 'route-b',
      aliases: ['seitah'],
      routeLetter: 'B',
      buttonLabel: 'B · Validation',
      title: 'Route B · Validation',
      purpose: 'Check earlier robotic observations with new field context.',
      scienceObjective:
          'At Séítah and Rochette, a crew could compare Perseverance\'s igneous '
          'and aqueous-alteration findings (olivine cumulates, first rock cores) '
          'with outcrop-scale observations a suited astronaut can make.',
      blurb: 'Out from the SH safety mark at Octavia E. Butler Landing to the '
          'olivine cumulates of Séítah and the first cored rock on Mars — a '
          'validation walk against early Mars 2020 geology.',
      baseTarget: 'oeb',
      stopTargets: ['brac', 'rochette'],
      ls: 20,
    ),
    EvaPreset(
      id: 'route-c',
      aliases: ['neretva'],
      routeLetter: 'C',
      buttonLabel: 'C · Discovery',
      title: 'Route C · Discovery',
      purpose: 'Reach an area selected for new scientific observations.',
      scienceObjective:
          'At CP3 (Bright Angel / Cheyava Falls): what field context surrounds '
          'the leopard-spot reaction fronts and organic-associated signals, and '
          'what additional documentation would help sample-return planning?',
      blurb: 'Along the carbonate margin and down Neretva Vallis to the '
          'Cheyava Falls mudstone — a discovery stop for a new geological '
          'question, not a cleared path.',
      baseTarget: 'bunsen',
      stopTargets: ['brightangel'],
      ls: 150,
      startLtst: 8.5,
    ),
    EvaPreset(
      id: 'route-d',
      routeLetter: 'D',
      buttonLabel: 'D · Return',
      title: 'Route D · Return',
      purpose: 'One-way return corridor toward Habitat H0.',
      scienceObjective:
          'From the fan-front validation zone back to H0. Connected to '
          'walk-back time, oxygen margin and the educational life-support check.',
      blurb: 'Start at Wildcat Ridge (CP2) and walk home to Habitat H0 at '
          'Three Forks. Emphasises return-to-base safety — not a NASA flight rule.',
      baseTarget: 'wildcat',
      stopTargets: ['threeforks'],
      returnToBase: false,
      objective: RouteObjective.safest,
      ls: 90,
      startLtst: 14,
    ),
    EvaPreset(
      id: 'rim',
      buttonLabel: 'Rim · stress',
      title: 'Rim ascent · stress case',
      purpose: 'Show a plan the go/no-go checks should refuse.',
      blurb: 'A climb from the river channel to the crater rim. Included to '
          'show a plan the checks should refuse.',
      baseTarget: 'brightangel',
      stopTargets: ['lookout'],
      ls: 250,
      startLtst: 10,
    ),
  ];
}

class PlannerState {
  const PlannerState({
    this.stops = const [],
    this.params = const EvaParameters(),
    this.plan,
    this.walkBack,
    this.computing = false,
    this.presetId,
    this.error,
  });

  final List<EvaStop> stops;
  final EvaParameters params;
  final MissionPlan? plan;
  final CostField? walkBack;
  final bool computing;
  final String? presetId;
  final String? error;

  EvaStop? get base => stops.isEmpty ? null : stops.first;

  PlannerState copyWith({
    List<EvaStop>? stops,
    EvaParameters? params,
    MissionPlan? Function()? plan,
    CostField? Function()? walkBack,
    bool? computing,
    String? Function()? presetId,
    String? Function()? error,
  }) =>
      PlannerState(
        stops: stops ?? this.stops,
        params: params ?? this.params,
        plan: plan != null ? plan() : this.plan,
        walkBack: walkBack != null ? walkBack() : this.walkBack,
        computing: computing ?? this.computing,
        presetId: presetId != null ? presetId() : this.presetId,
        error: error != null ? error() : this.error,
      );
}

class PlannerController extends Notifier<PlannerState> {
  late AppData _data;
  late MissionPlanner _planner;
  int _generation = 0;
  String? _walkBackKey;
  Timer? _debounce;

  @override
  PlannerState build() {
    _data = ref.watch(dataProvider);
    _planner = MissionPlanner(
      grid: _data.terrain,
      pathfinder: _data.pathfinder,
      climatology: _data.climate,
    );
    ref.onDispose(() => _debounce?.cancel());
    final launch = ref.watch(launchOptionsProvider);
    final preset =
        EvaPreset.byId(launch.presetId) ?? EvaPreset.all.first;
    final initial = PlannerState(
      stops: _presetStops(preset),
      params: _paramsFor(preset, launch),
      presetId: preset.id,
      computing: true,
    );
    Future.microtask(_recompute);
    return initial;
  }

  EvaParameters _paramsFor(EvaPreset p, [LaunchOptions? launch]) =>
      EvaParameters(
        ls: launch?.ls ?? p.ls,
        startLtst: launch?.startLtst ?? p.startLtst,
        returnToBase: p.returnToBase,
        objective: p.objective ?? RouteObjective.fastest,
      );

  List<EvaStop> _presetStops(EvaPreset p) {
    final base = _data.target(p.baseTarget)!;
    return [
      EvaStop(
        position: base.position,
        name: base.name,
        targetId: base.id,
        dwellMinutes: 0,
      ),
      for (final id in p.stopTargets)
        EvaStop(
          position: _data.target(id)!.position,
          name: _data.target(id)!.name,
          targetId: id,
        ),
    ];
  }

  void loadPreset(EvaPreset p) {
    state = state.copyWith(
      stops: _presetStops(p),
      params: state.params.copyWith(
        ls: p.ls,
        startLtst: p.startLtst,
        returnToBase: p.returnToBase,
        objective: p.objective ?? RouteObjective.fastest,
      ),
      presetId: () => p.id,
    );
    _schedule(immediate: true);
  }

  bool _onMap(LatLng p) =>
      _data.terrain.containsLatLon(p.latitude, p.longitude);

  String _freeName(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)}°N ${p.longitude.toStringAsFixed(4)}°E';

  /// Moves the base (airlock) to [p]. Returns false if off the DTM.
  bool setBase(LatLng p, {ScienceTarget? target}) {
    if (!_onMap(p)) return false;
    final base = EvaStop(
      position: target?.position ?? p,
      name: target?.name ?? 'Base · ${_freeName(p)}',
      targetId: target?.id,
      dwellMinutes: 0,
    );
    state = state.copyWith(
      stops: [base, ...state.stops.skip(1)],
      presetId: () => null,
    );
    _schedule();
    return true;
  }

  bool addStop(LatLng p, {ScienceTarget? target}) {
    if (!_onMap(p)) return false;
    if (state.stops.isEmpty) return setBase(p, target: target);
    state = state.copyWith(
      stops: [
        ...state.stops,
        EvaStop(
          position: target?.position ?? p,
          name: target?.name ?? 'Waypoint · ${_freeName(p)}',
          targetId: target?.id,
        ),
      ],
      presetId: () => null,
    );
    _schedule();
    return true;
  }

  void removeStop(int index) {
    if (index <= 0 || index >= state.stops.length) return;
    state = state.copyWith(
      stops: [...state.stops]..removeAt(index),
      presetId: () => null,
    );
    _schedule();
  }

  void moveStop(int index, int delta) {
    final j = index + delta;
    if (index <= 0 || j <= 0 || j >= state.stops.length) return;
    final next = [...state.stops];
    final s = next.removeAt(index);
    next.insert(j, s);
    state = state.copyWith(stops: next, presetId: () => null);
    _schedule();
  }

  void setDwell(int index, double minutes) {
    final next = [...state.stops];
    next[index] = next[index].copyWith(dwellMinutes: minutes);
    state = state.copyWith(stops: next);
    _schedule();
  }

  void clearStops() {
    state = state.copyWith(
      stops: state.stops.take(1).toList(),
      presetId: () => null,
    );
    _schedule();
  }

  void updateParams(EvaParameters Function(EvaParameters) f) {
    state = state.copyWith(params: f(state.params));
    _schedule();
  }

  void _schedule({bool immediate = false}) {
    _generation++;
    _debounce?.cancel();
    state = state.copyWith(computing: true);
    _debounce = Timer(
      Duration(milliseconds: immediate ? 0 : 140),
      _recompute,
    );
  }

  Future<void> _recompute() async {
    final gen = ++_generation;
    bool cancelled() => gen != _generation;
    final stops = state.stops;
    final params = state.params;
    if (stops.isEmpty) {
      state = state.copyWith(plan: () => null, computing: false);
      return;
    }
    try {
      // The walk-back field depends only on the base and the walking model.
      final base = stops.first;
      final key = '${base.position.latitude},${base.position.longitude},'
          '${params.eva.paceFactor},${params.maxSlopeDeg}';
      var field = state.walkBack;
      if (key != _walkBackKey || field == null) {
        field = await _planner.computeWalkBack(
          base,
          params,
          isCancelled: cancelled,
        );
        if (cancelled()) return;
        _walkBackKey = key;
      }
      final plan = await _planner.plan(
        stops,
        params,
        walkBack: field,
        isCancelled: cancelled,
      );
      if (cancelled()) return;
      state = state.copyWith(
        plan: () => plan,
        walkBack: () => field,
        computing: false,
        error: () => null,
      );
    } catch (e) {
      if (cancelled()) return;
      state = state.copyWith(computing: false, error: () => '$e');
    }
  }
}

final plannerProvider =
    NotifierProvider<PlannerController, PlannerState>(PlannerController.new);

// ---- Simulation ---------------------------------------------------------------

class SimState {
  const SimState({this.timeS = 0, this.playing = false, this.rate = 300});
  final double timeS;
  final bool playing;

  /// Simulated seconds per real second.
  final double rate;

  static const rates = [60.0, 300.0, 900.0];

  SimState copyWith({double? timeS, bool? playing, double? rate}) => SimState(
        timeS: timeS ?? this.timeS,
        playing: playing ?? this.playing,
        rate: rate ?? this.rate,
      );
}

class SimController extends Notifier<SimState> {
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  double _duration = 0;

  @override
  SimState build() {
    // A new plan resets the rehearsal.
    final plan = ref.watch(plannerProvider.select((p) => p.plan));
    _duration = plan?.durationS ?? 0;
    _stop();
    ref.onDispose(_stop);
    return const SimState();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  void play() {
    if (_duration <= 0) return;
    final from = state.timeS >= _duration ? 0.0 : state.timeS;
    state = state.copyWith(playing: true, timeS: from);
    _clock
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final dt = _clock.elapsedMicroseconds / 1e6;
      _clock.reset();
      final t = state.timeS + dt * state.rate;
      if (t >= _duration) {
        _stop();
        state = state.copyWith(timeS: _duration, playing: false);
      } else {
        state = state.copyWith(timeS: t);
      }
    });
  }

  void pause() {
    _stop();
    state = state.copyWith(playing: false);
  }

  void toggle() => state.playing ? pause() : play();

  void seek(double t) =>
      state = state.copyWith(timeS: t.clamp(0.0, _duration).toDouble());

  void setRate(double r) => state = state.copyWith(rate: r);

  void reset() {
    _stop();
    state = state.copyWith(timeS: 0, playing: false);
  }
}

final simProvider = NotifierProvider<SimController, SimState>(SimController.new);

/// EVA state at the rehearsal clock, or null without a walkable plan.
final evaStateProvider = Provider<EvaState?>((ref) {
  final plan = ref.watch(plannerProvider.select((p) => p.plan));
  if (plan == null || !plan.hasTrack) return null;
  return plan.stateAt(ref.watch(simProvider.select((s) => s.timeS)));
});

// ---- Raster layers ------------------------------------------------------------

final reliefImageProvider = FutureProvider<ui.Image>(
  (ref) => ref.watch(rastersProvider).relief(),
);

final hazardImageProvider = FutureProvider<ui.Image>(
  (ref) => ref.watch(rastersProvider).hazard(),
);

final thermalImageProvider = FutureProvider<ui.Image>(
  (ref) => ref.watch(rastersProvider).thermal(),
);

final solarImageProvider = FutureProvider<ui.Image>((ref) {
  final ls = ref.watch(plannerProvider.select((p) => p.params.ls));
  return ref.watch(rastersProvider).solar(ls);
});

/// Local true solar time the illumination layer is drawn for: the rehearsal
/// clock while rehearsing, otherwise the planned egress time. Quantised to
/// 10 minutes so scrubbing does not recompute every frame.
final illuminationTimeProvider = Provider<double>((ref) {
  final rehearsing =
      ref.watch(uiProvider.select((u) => u.workspace == Workspace.simulate));
  final start = ref.watch(plannerProvider.select((p) => p.params.startLtst));
  if (!rehearsing) return start;
  final t = ref.watch(simProvider.select((s) => (s.timeS / 600).floor()));
  return (start + t * 600 / MissionPlan.marsHourS) % 24.0;
});

final illuminationImageProvider = FutureProvider<ui.Image>((ref) {
  final ls = ref.watch(plannerProvider.select((p) => p.params.ls));
  final ltst = ref.watch(illuminationTimeProvider);
  return ref.watch(rastersProvider).illumination(ls, ltst);
});

final walkBackImageProvider = FutureProvider<ui.Image?>((ref) async {
  final field = ref.watch(plannerProvider.select((p) => p.walkBack));
  if (field == null) return null;
  return ref.watch(rastersProvider).walkBack(field);
});
