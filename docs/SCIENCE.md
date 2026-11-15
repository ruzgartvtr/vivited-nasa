# Science: models, assumptions and uncertainty

Vivited — Martian Exploration Intelligence System separates three kinds of
number:

- **Measurements** come from NASA products (see [DATA.md](DATA.md)).
- **Models** are published methods applied to those measurements.
- **Planning assumptions** are values no one has measured for a Mars suit.
  They are labelled in the app and editable.

## Mars time and the Sun

`lib/src/science/mars_time.dart` implements Allison & McEwen (2000), *Planet.
Space Sci.* 48, 215, the algorithm behind NASA GISS Mars24: areocentric solar
longitude (Ls), equation of time, local true solar time, solar declination,
elevation and azimuth, sunrise and sunset, and Sun–Mars distance. The test
suite checks it against the worked example published with Mars24.

Sunrise and sunset are geometric for a flat horizon. Crater walls delay
sunrise and advance sunset locally; the shadow layer shows this, the daylight
check does not account for it.

## Walking speed

Marquez (2008), MIT PhD thesis, fitted to Apollo lunar traverses and used by
the NASA-funded SEXTANT planner and its open-source successor pextant. Speed
in m/s for along-track slope *s* in degrees (uphill positive):

| Slope | Speed |
| --- | --- |
| above 15° | 0.05 |
| 6° to 15° | 0.634 − 0.039 s |
| 0° to 6° | 1.6 − 0.2 s |
| −10° to 0° | 1.6 + 0.06 s |
| −20° to −10° | 1.95 + 0.095 s |
| below −20° | 0.05 |

Vivited multiplies this by a pace factor, 0.75 by default. That derate is a
planning margin chosen by the team, not a measurement.

## Metabolic cost and oxygen

Santee et al. (2001), *Aviat. Space Environ. Med.* 72, 562: load carriage on
level, uphill and downhill ground, with the slope term scaled by local
gravity (3.721 m/s²) as in SEXTANT. Oxygen follows from 20.1 kJ per litre
O₂ at 1.429 g/L. Work at a station is taken as 250 W, within the range of
Apollo surface averages.

Suit mass, crew mass, primary oxygen (0.55 kg, after the Shuttle/ISS EMU),
the 15 % reserve and the 8-hour limit are planning assumptions.

Separately, the **educational life-support simulator** (`EduLifeSupport`) uses
abstract teaching units for jury demonstrations (default: 100 units, 0.3 per
minute, 20 reserve, 120 minutes → 36 consumed, 64 remaining). It is labelled
*EDUCATIONAL SIMULATION — NOT FOR REAL ASTRONAUT OPERATIONS* and must not be
confused with the EMU-style planner model above.

## Hazard classes

Slope from the 20 m DTM, with boundaries aligned to the break-points of the
walking model so a map colour means the same as a routing penalty:

| Class | Slope |
| --- | --- |
| Nominal | below 6° |
| Caution | 6° to 10° |
| Difficult | 10° to 15° |
| Severe | 15° to 20° |
| No-go | 20° and above |

"Nominal" means free of slope hazards the DTM can resolve, nothing more.

## Routing

`lib/src/routing/` is native Dart.

- **Search.** A* over the eight-connected 20 m grid with a binary heap.
  Dijkstra is available and is used in tests to confirm A* returns optimal
  cost. The heuristic is straight-line distance at the best speed (or lowest
  energy per metre) the model can produce, so it never overestimates.
- **Objectives.** Fastest (time), least energy, or safest (time multiplied
  by 1 + (slope / 6°)²).
- **Closed ground.** Cells steeper than the slope limit, and moves whose
  along-track slope exceeds it, cannot be crossed. If no route exists the
  leg is refused and the plan is marked no-go.
- **Any-angle smoothing.** Grid paths can only turn in 45° steps, which
  overstates distance by up to about 8 %. `PathSmoother` replaces runs of
  grid steps with straight segments, sampled across the DTM, and accepts a
  segment only if it crosses no closed ground and costs no more than the
  grid path it replaces. Smoothed routes are therefore never worse under the
  chosen objective.
- **Walk-back field.** A Dijkstra field of the fastest return time to the
  airlock from every cell within 2.5 hours, after the walk-back constraint
  used for Apollo J-mission traverses. It is computed on the grid without
  smoothing, so it overestimates return time by up to about 8 %. That error
  is on the safe side.

## Computed layers

- **Shadows** are ray-marched across the DTM towards the Mars24 Sun position
  at a quarter of the grid resolution (80 m), reaching up to 9 km.
- **Solar exposure** is the cosine-weighted direct sun on each cell's own
  slope, integrated over the sol and shown relative to level ground (±30 %).
  It ignores shadows cast by distant terrain, atmospheric dust and diffuse
  light, so it is a relative guide to warm and cold slopes, not an
  irradiance in W/m².
- **Night infrared** is THEMIS mosaic brightness. Brighter at night suggests
  rockier or more consolidated ground (higher thermal inertia); it is not a
  temperature.

## Radiation

Hassler et al. (2014), *Science* 343: 0.64 ± 0.12 mSv/day dose equivalent
and 0.210 ± 0.040 mGy/day absorbed dose from galactic cosmic rays, measured
by MSL RAD at Gale crater in 2012–13. Vivited prorates this over the walk.
Solar particle events are not modelled, and the value changes with the solar
cycle and with elevation.

## Go/no-go checks

A plan is checked for: every leg routable; duration within the suit limit;
oxygen on return above the reserve; return before sunset (a warning when the
margin is thin); the steepest ground crossed; walk-back time and the oxygen
margin on a direct return from the farthest point; air temperature during
the walk (MEDA); and radiation dose. These are screening checks for a
planning tool, not flight rules.

## Uncertainty, plainly

- No one has walked on Mars. The speed and metabolic models come from Apollo
  lunar EVAs at one-sixth gravity and from treadmill trials on Earth. Errors
  of tens of percent in time and oxygen are plausible.
- The terrain model agrees with rover elevations to 2.8 m RMS along the
  traverse, but cannot see obstacles smaller than about 60 m. A route marked
  nominal is a candidate for detailed survey with HiRISE and on the ground,
  not a cleared path.
- Slopes over a 20 m baseline understate local steepness.
- Weather is a climatology, radiation is from another site and another part
  of the solar cycle, and dust is not modelled.

## References

- Allison, M. & McEwen, M. (2000). *Planet. Space Sci.* 48, 215–235.
- Fergason, R. L. et al. (2020). Mars 2020 Terrain Relative Navigation CTX
  DTM mosaic. USGS Astrogeology Science Center.
- Hassler, D. M. et al. (2014). *Science* 343, 1244797.
- Johnson, A. W. et al. (2010). SEXTANT traverse planner, MIT.
- Marquez, J. J. (2008). *Human-automation collaboration: decision support
  for lunar and planetary exploration.* PhD thesis, MIT.
- Norheim, J. et al. (2018). pextant, MIT.
- Rodriguez-Manfredi, J. A. et al. (2021). *Space Sci. Rev.* 217, 48.
- Santee, W. R. et al. (2001). *Aviat. Space Environ. Med.* 72, 562–566.
- Smith, D. E. et al. (2001). *J. Geophys. Res.* 106, 23689–23722.
