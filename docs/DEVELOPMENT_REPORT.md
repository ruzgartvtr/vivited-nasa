# Vivited — Development Report

NASA Space Apps Challenge 2026 · *Interplanetary Survival Guide: Martian Map*  
Improvement and completion pass against the Marswalk educational brief, preserving the existing Flutter architecture.

**Repository note:** Changes were left as local working-tree modifications. No commit, push, or Firebase deploy was performed.

---

## A. Requirements Review

### Already satisfied (preserved)

- Flutter / Dart web app with Atlas · Plan · Rehearse · Sources workspaces
- Jezero CTX 20 m DTM, orthomosaic, THEMIS night IR, MOLA globe, MEDA climatology, Perseverance traverse and science targets
- A* / Dijkstra routing, any-angle smoothing, walk-back field, go/no-go checks
- EVA metabolic / oxygen model (Marquez / Santee / EMU-style assumptions)
- Orbit / Map / Terrain views, analysis overlays, deep links
- Firebase Hosting config targeting `build/web` (SPA rewrite)
- Scientific honesty documentation in `docs/SCIENCE.md` and `docs/DATA.md`

### Newly implemented or refined

| Brief requirement | Implementation |
| --- | --- |
| Research question framing | Orbit intro + Atlas subtitle |
| H0 / CP1 / CP2 / CP3 / SH | `MissionCheckpoint` on real target IDs; map glyphs + Atlas list |
| Routes A–D | Educational presets `route-a`…`route-d` (aliases for old IDs) + rim stress case |
| Route measurements | Distance, elevation change, slope, duration, oxygen, constraint status in Plan |
| Optical / topo / MEDA layers | Atlas data-layer cards + layer panel provenance notes |
| Educational life-support sample | `EduLifeSupport` with brief formulas + UI + warning copy |
| “Return to Habitat / Reduce Mission Time” | Shown when oxygen or energy reserve fails |
| EDUCATIONAL SIMULATION banner | On simulator panel |
| NASA DATA / INTERPRETATION / SIMULATION | `SourceClass` + `ProvenanceChip` across Atlas, Plan, Rehearse, Sources |
| Guided demo (~3 min) | 15-step `DemoGuide` + DEMO rail control |
| Four functional areas | Workspace hints / panel kickers mapped without deleting features |
| Presentation + video | `docs/PRESENTATION.md`, `docs/VIDEO_SCRIPT.md` |

### Could not / did not complete

- Live browser console QA beyond widget/flow tests (no interactive Chrome session in this pass)
- Firebase deploy (explicitly forbidden without separate instruction)
- Adding `firebase_core` as a runtime dependency (app does not initialize Firebase; Hosting only)

---

## B. Files Changed

### New

- `lib/src/science/provenance.dart` — source classification enum
- `lib/src/science/edu_life_support.dart` — educational O₂ / energy arithmetic
- `lib/src/mission/checkpoints.dart` — H0 / CP1–CP3 / SH definitions
- `lib/src/state/demo_guide.dart` — guided demo + edu life-support Riverpod state
- `lib/src/ui/panels/edu_life_support_section.dart` — simulator UI
- `lib/src/ui/widgets/demo_overlay.dart` — demo narration bar
- `test/edu_life_support_test.dart` — sample scenario, warnings, routes, checkpoints
- `docs/PRESENTATION.md`, `docs/VIDEO_SCRIPT.md`, `docs/DEVELOPMENT_REPORT.md`

### Modified (grouped)

- **Mission / state:** `app_state.dart`, `launch_options.dart` — Routes A–D metadata, aliases, checkpoint toggle, params from presets
- **UI panels:** `atlas_panel.dart`, `plan_panel.dart`, `simulate_panel.dart`, `sources_panel.dart` — educational structure, labels, measurements
- **Map / shell:** `map_stage.dart`, `stage.dart`, `shell.dart`, `glyphs.dart`, `primitives.dart` — checkpoint marks, demo entry, provenance chips
- **Docs / config:** `README.md`, `analysis_options.yaml` (exclude unused FlutterFire options file)
- **Tests:** `mission_test.dart`, `widget_test.dart`, `app_flow_test.dart`

---

## C. Scientific Verification

| Item | Classification | Source / assumption |
| --- | --- | --- |
| Checkpoint coordinates | NASA DATA (positions) | Perseverance localized waypoints via `science_targets.json` |
| H0 / SH roles | SIMULATION | Fictional habitat / safety infrastructure on real stations |
| CP1–CP3 roles | SCIENTIFIC INTERPRETATION | Editorial mission roles on real geology / astrobiology stations |
| Elevation / slope / routes | NASA DATA + interpretation | CTX DTM 20 m; hazard classes and route difficulty derived |
| MEDA chart | NASA DATA | Historical climatology — not real-time weather |
| Planner O₂ (grams) | INTERPRETATION + assumptions | Santee metabolic model + editable EMU-like budget |
| Educational O₂ units | SIMULATION | Brief sample: 100, 0.3/min, reserve 20, 120 min → 64 remaining |
| Routes A–D geometry | SIMULATION corridors | Planned over real terrain; not NASA-approved paths |

Limitations unchanged: 20 m posting, Apollo-derived walking models, Gale RAD dose, no dust-storm forecast. See `docs/SCIENCE.md`.

---

## D. Functional Verification

- **Map:** Jezero sheet, optional checkpoint badges, BASE/H0 label, science stations, route polyline
- **Layers:** Imagery / relief bases; hazard and other overlays; provenance note in layer panel
- **Routes:** Selecting A–D loads stops, purpose, science objective, measurements and checks
- **Route D:** One-way return Wildcat → Three Forks (`returnToBase: false`)
- **Rim stress:** Still present; go/no-go fails as before
- **Simulator:** Sample scenario, sync-from-plan, parameter sliders, exact warning string
- **Sources:** Label legend + dataset list with NASA DATA chips
- **Demo:** Rail DEMO advances 15 real UI steps

---

## E. Testing Results

Commands actually executed:

```text
flutter analyze          → No issues found
flutter test             → All tests passed (72)
flutter build web --release → ✓ Built build/web
```

New coverage includes the educational sample scenario (36 consumed, 64 remaining), reserve failure warning, energy safety, checkpoint IDs, route aliases, and Route D one-way planning.

Note: app-flow tests may log NASA Trek tile HTTP 400s in the test harness; bundled Jezero rasters still drive the app and tests pass.

---

## F. Remaining Limitations

- Viking regional tiles still require network; absence is non-fatal
- Educational simulator units are intentionally abstract and independent of EMU grams unless the user presses “Sync from plan”
- Guided demo does not auto-scroll panel sections; narration tells the speaker what to point at
- `lib/firebase_options.dart` remains for Hosting project linkage but is analyzer-excluded because `firebase_core` is not a runtime dependency

---

## G. Local Launch Instructions

```sh
cd /Users/ruzgar/vivited
flutter pub get
flutter run -d chrome
```

Release web build (Firebase Hosting input):

```sh
flutter build web --release
# Output: build/web
# Deploy only when explicitly instructed: firebase deploy
```

Deep-link demo start:

```text
?workspace=plan&preset=route-a&view=map
```

Then press **DEMO** in the left rail for the full guided sequence.
