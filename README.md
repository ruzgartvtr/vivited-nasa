# Vivited — Martian Exploration Intelligence System

Vivited is a Flutter Web application for planning and rehearsing crewed
surface walks at Jezero crater, Mars. It was built by team Vivited for the
NASA Space Apps Challenge 2026 challenge *Interplanetary Survival Guide:
Martian Map*.

It takes what NASA has measured at Jezero (terrain, imagery, weather,
radiation, and two thousand sols of rover ground truth) and answers the
questions a crew would ask before opening the airlock: where can we walk, how
long will it take, how much oxygen will it cost, and how far are we from home
at every step.

Everything is written in Flutter and Dart. Python is used only offline, to
turn the raw NASA products into the compact assets bundled with the app.

Checks:

```sh
flutter analyze
flutter test
```

The app works offline except for the regional Viking context tiles around the
Jezero footprint, which stream from NASA Solar System Treks. If they are
unreachable they are simply absent.

# Vivited — Martian Exploration Intelligence System
Our site is at https://vivited-nasa-space-apps.web.app/ and you can access it in your browser if you have JavaScript

## What is in it

| Workspace | What it does |
| --- | --- |
| Atlas | Mission + map: Jezero region, Habitat H0 / CP1–CP3 / SH, optical · topography · MEDA layer briefs, science stations. |
| Plan | Routes + science: educational Routes A–D (Safe Access, Validation, Discovery, Return), measurements, profile, go/no-go. |
| Rehearse | Life support + timeline: EVA rehearsal clock, and the educational oxygen/energy simulator with reserve warnings. |
| Sources | Provenance labels (NASA DATA / INTERPRETATION / SIMULATION), every dataset, method and limit. |

Three views share the stage: **Orbit** (a globe from MOLA and Viking data
with NASA landing sites), **Map** (CTX imagery or shaded relief with analysis
layers) and **Terrain** (a 3D CTX terrain model around the route).

Analysis layers: slope hazard, THEMIS night infrared, solar exposure relative
to level ground, cast shadows at the planned time, and walk-back time to the
airlock.

### Deep links

The URL selects the starting state, which is handy for demos:

```
?workspace=atlas|plan|rehearse|sources
&view=orbit|map|terrain
&preset=route-a|route-b|route-c|route-d|rim
           (aliases: delta-front, seitah, neretva)
&layers=hazard,thermal,solar,illumination,walkBack
&base=imagery|relief
&ls=0..360        season, areocentric solar longitude in degrees
&start=5..17      egress time, local true solar time in hours
```

Example: `?workspace=plan&preset=route-c&view=terrain&layers=hazard`

Press **DEMO** in the left rail for a guided ~3-minute jury walkthrough.

## Project layout

```
lib/
  main.dart, src/app.dart      entry point and app widget
  src/science/                 Mars time, geodesy, walking and metabolic models, hazard classes, radiation
  src/data/                    asset loading, terrain grid, climatology, models
  src/routing/                 A*, Dijkstra, binary heap, cost model, any-angle smoothing
  src/mission/                 planner, plan samples, go/no-go checks, simulation state
  src/render/                  computed raster layers (relief, hazard, solar, shadows, walk-back)
  src/state/                   Riverpod controllers, deep-link options
  src/theme/                   colours and type
  src/ui/                      shell, stage (orbit, map, terrain), panels, custom widgets
assets/                        processed NASA data, imagery, fonts
tool/                          offline Python processing and the raw-data download script
test/                          unit, widget and end-to-end flow tests
docs/                          SCIENCE.md (models, uncertainty), DATA.md (sources, processing)
```

## Tests

Supporting materials: [docs/SCIENCE.md](docs/SCIENCE.md), [docs/DATA.md](docs/DATA.md),
[docs/PRESENTATION.md](docs/PRESENTATION.md), [docs/VIDEO_SCRIPT.md](docs/VIDEO_SCRIPT.md),
[docs/DEVELOPMENT_REPORT.md](docs/DEVELOPMENT_REPORT.md).

`flutter test` runs the science, terrain, routing, mission, educational
life-support, widget and end-to-end flow suites:

- `science_test.dart`: Mars24 against the published worked example, Sun
  geometry, walking speed, metabolic and oxygen models, radiation.
- `terrain_test.dart`: the bundled DTM, georeferencing, slopes, agreement
  with rover elevations.
- `routing_test.dart`: heap, A* against Dijkstra, obstacles, slope limits,
  objectives, cost fields, path smoothing.
- `mission_test.dart`: scenario plans, totals, simulation state, walk-back,
  daylight and oxygen checks.
- `widget_test.dart`, `app_flow_test.dart`: loading and error screens, deep
  links, and the whole app driven through its workspaces on desktop, tablet
  and phone sizes with the real data.

## Honesty about the numbers

Measurements are NASA's; models are published ones; planning assumptions are
labelled as such and editable. A 20 m terrain model cannot see boulders or
sand ripples, and no one has walked on Mars. See [docs/SCIENCE.md](docs/SCIENCE.md)
and [docs/DATA.md](docs/DATA.md), or the Sources workspace in the app.

## Credits

Data: NASA/JPL-Caltech, USGS Astrogeology, MSSS, Arizona State University,
GSFC, NASA PDS. Vivited is not affiliated with or endorsed by NASA.

Fonts: Instrument Serif, Schibsted Grotesk and IBM Plex Mono, under the SIL
Open Font License (licences in `assets/fonts/`).
