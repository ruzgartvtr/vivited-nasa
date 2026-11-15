# Vivited — Seven-Slide English Presentation

NASA Space Apps Challenge 2026 · *Interplanetary Survival Guide: Martian Map*

Team Vivited · ~7 slides · keep each slide to about 30–40 seconds of speaking.

---

## Slide 1 — Introducing Vivited

**Title:** Vivited — Martian Exploration Intelligence

**Talking points:**
- Vivited is our Flutter web map for planning imagined astronaut walks at Jezero crater.
- We keep the research question on screen: *How can astronauts explore Mars safely, check earlier robotic observations, and collect new scientific data using one interactive map?*
- Branding is Vivited (not Marswalk). The app is educational — not a NASA flight system.

**On screen:** Vivited mark, Jezero globe intro, research question.

---

## Slide 2 — The Exploration Problem

**Title:** One crater. Limited oxygen. Real terrain.

**Talking points:**
- Jezero holds a dry lake, a river delta, and more than two thousand sols of Perseverance ground truth.
- Astronauts would need to choose routes that respect slopes, daylight, and life-support reserves — and still reach science.
- Vivited puts habitat, checkpoints, routes and resources on the same map so those trade-offs are visible.

**On screen:** Atlas view with Habitat H0 and checkpoints H0 / CP1–CP3 / SH labelled.

---

## Slide 3 — NASA Scientific Data

**Title:** Three data families — honestly labelled

**Talking points:**
- **Optical:** MRO CTX orthomosaic — rocks, scarps, visible obstacles (**NASA DATA**).
- **Topography:** USGS Mars 2020 CTX stereo DTM at 20 m — elevation, slope, route profiles (**NASA DATA**; hazard classes are **SCIENTIFIC INTERPRETATION**).
- **Atmosphere:** Perseverance MEDA climatology by season and local hour — historical, not live weather (**NASA DATA**).
- Habitat H0 and oxygen teaching units are **SIMULATION**.

**On screen:** Layer panel open — imagery, shaded relief + hazard, Plan MEDA chart.

---

## Slide 4 — The Four Mission Routes

**Title:** Routes A–D inside the same Jezero sheet

**Talking points:**
- **A · Safe Access** — H0 → fan-front terrain (CP1) and validation mudstones (CP2) on manageable ground.
- **B · Validation** — from the SH safety mark to Séítah / Rochette to check early robotic geology.
- **C · Discovery** — margin unit to Bright Angel / Cheyava Falls (CP3) for a new geological question.
- **D · Return** — one-way corridor from CP2 back to Habitat H0, tied to life-support checks.
- These are educational planning corridors, not NASA-approved walking paths.

**On screen:** Plan workspace cycling Routes A–D with distance, climb, duration, go/no-go.

---

## Slide 5 — Astronaut Survival Simulation

**Title:** Transparent life support — teaching units

**Talking points:**
- Planner oxygen uses published metabolic models (Santee / EMU-style assumptions) on the real route.
- The educational simulator uses the brief’s worked example: 100 units, 120 minutes, 0.3 / min, reserve 20 → remaining 64, reserve OK.
- Stretch the duration and the app shows: **Return to Habitat / Reduce Mission Time**.
- Banner on screen: *EDUCATIONAL SIMULATION — NOT FOR REAL ASTRONAUT OPERATIONS*.

**On screen:** Rehearse workspace + educational simulator with warning triggered.

---

## Slide 6 — Live Web Demonstration

**Title:** Three minutes, one guided path

**Talking points:**
- Press **DEMO** in the rail. Fifteen steps drive the real UI: region → H0 → layers → Routes A–D → life support → sources → summary.
- No login. Bundled NASA assets load in the browser (Firebase Hosting compatible).
- Judges can follow without prior technical knowledge.

**On screen:** Live demo overlay advancing through the app.

---

## Slide 7 — What We Learned

**Title:** What the map taught us

**Talking points:**
- Safety on Mars is a map problem: terrain, science goals and consumables have to be read together.
- Real NASA data makes the story credible — but only if we label interpretation and simulation honestly.
- A 20 m DTM cannot see boulders; Apollo-derived walk models are uncertain; MEDA is climatology, not a forecast.
- Vivited shows how a crew *might* rehearse Jezero walks — and where the models stop.

**On screen:** Sources workspace with NASA DATA / INTERPRETATION / SIMULATION legend.

---

## Speaker tips

- Say “Vivited” every time you name the product.
- Never claim NASA certification or real-time Martian weather.
- If a layer is still computing, narrate the uncertainty instead of apologising for the wait.
