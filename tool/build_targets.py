"""Build assets/data/science_targets.json.

Positions are NOT hand-placed: each target takes the localized Perseverance
rover position (NASA/JPL MMGIS waypoints) for the sol on which the rover
worked that target. Descriptions summarise published Mars 2020 results; see
the `refs` on each entry. Elevation comes from the same waypoint record.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WP = [f["properties"] for f in json.load(open(ROOT / "tool/raw/M20_waypoints.json"))["features"]]

REFS = {
    "farley2022": "Farley, K.A. et al. (2022) Science 377, eabo2196 — Aqueously altered igneous rocks on the floor of Jezero crater.",
    "liu2022": "Liu, Y. et al. (2022) Science 377, 1513 — An olivine cumulate outcrop on the floor of Jezero crater.",
    "simon2023": "Simon, J.I. et al. (2023) JGR Planets 128, e2022JE007474 — Samples collected from the floor of Jezero crater.",
    "stack2024": "Stack, K.M. et al. (2024) JGR Planets 129 — Sedimentology and stratigraphy of the Shenandoah formation, western fan, Jezero.",
    "bosak2024": "Bosak, T. et al. (2024) AGU Advances 5 — Astrobiological potential of rocks acquired by Perseverance at a sedimentary fan front.",
    "mangold2021": "Mangold, N. et al. (2021) Science 374, 711 — Perseverance rover reveals an ancient delta-lake system and flood deposits at Jezero.",
    "horgan2020": "Horgan, B.H.N. et al. (2020) Icarus 339, 113526 — The mineral diversity of Jezero crater (CRISM orbital spectroscopy).",
    "goudge2015": "Goudge, T.A. et al. (2015) JGR Planets 120, 775 — Assessing the mineralogy of the watershed and fan deposits of the Jezero crater paleolake (CRISM).",
    "hurowitz2025": "Hurowitz, J.A. et al. (2025) Nature 645 — Redox-driven mineral and organic associations in Jezero crater, Mars.",
    "depot": "NASA/JPL (2023) Mars 2020 mission update — Three Forks sample depot completed, 10 tubes (Dec 2022 – Jan 2023).",
    "hecht2021": "Hecht, M. et al. (2021) Space Sci. Rev. 217, 9; Hoffman, J.A. et al. (2022) Science Advances 8, eabp8636 — MOXIE oxygen production on Mars.",
    "rim": "NASA/JPL (2024–2025) Mars 2020 Crater Rim Campaign mission updates.",
}

# (id, name, sol, kind, unit, summary, science value 1-5, resource tags, refs)
TARGETS = [
    ("oeb", "Octavia E. Butler Landing", 13, "landmark", "Crater floor · Máaz formation",
     "Perseverance touchdown site, 18 Feb 2021. Flat, fractured basaltic lava plain; the MOXIE experiment later produced oxygen from the CO₂ atmosphere on this crater floor, the first in-situ resource demonstration on another planet.",
     2, ["isru-oxygen"], ["farley2022", "hecht2021"]),
    ("roubion", "Roubion · Polygon Valley", 164, "geology", "Crater floor · Máaz formation",
     "First coring attempt of the mission. The altered basalt crumbled to powder — evidence of extensive aqueous weathering — and the tube sealed a sample of Martian atmosphere instead.",
     3, [], ["farley2022", "simon2023"]),
    ("rochette", "Rochette · Citadelle", 190, "geology", "Crater floor · Máaz formation (Artuby ridge)",
     "First rock cores collected on Mars (Montdenier, Montagnac). Basaltic lava with salt-filled voids: an igneous rock datable on Earth that also records later contact with liquid water.",
     4, [], ["farley2022", "simon2023"]),
    ("brac", "Brac outcrop · South Séítah", 262, "geology", "Crater floor · Séítah formation",
     "Olivine-rich cumulate, formed when crystals settled in a thick magma body. Olivine is partly altered to carbonate — a reaction that consumes water and CO₂ and can release hydrogen.",
     5, ["carbonate", "olivine"], ["liu2022", "farley2022"]),
    ("issole", "Issole · Séítah", 300, "geology", "Crater floor · Séítah formation",
     "Second Séítah sampling station (Robine, Malay cores). Layered olivine cumulate ridges separated by sand ripples; ripples and ledges make this the roughest ground on the crater floor.",
     4, ["olivine"], ["liu2022", "simon2023"]),
    ("threeforks", "Three Forks sample depot", 660, "cache", "Fan front · crater floor contact",
     "Ten sealed sample tubes were laid on the surface here as a backup cache for Mars Sample Return. Chosen because it is flat and rock-poor: a proven safe landing and staging zone at the foot of the delta.",
     4, ["landing-zone"], ["depot"]),
    ("amalik", "Amalik · Cape Nukshak", 577, "geology", "Fan front · Shenandoah formation",
     "Fine-grained sedimentary rocks at the base of the delta scarp (Shuyak, Mageik cores). Lowest exposed beds of the lake-deposited sequence, with sulfate and clay minerals.",
     4, ["hydrated-minerals"], ["stack2024", "bosak2024"]),
    ("wildcat", "Wildcat Ridge · Hogwallow Flats", 500, "astrobiology", "Fan front · Shenandoah formation",
     "Sulfate-bearing mudstone deposited in still lake water. SHERLOC measured the mission's strongest organic-associated signals to that date here; fine mudstones are the best preservers of biosignatures.",
     5, ["hydrated-minerals", "sulfate"], ["bosak2024", "stack2024"]),
    ("belva", "Belva crater overlook", 770, "geology", "Upper fan",
     "Rim of a ~0.9 km impact crater that punches into the fan top. Its walls expose steeply dipping sandstone beds and boulders, a natural cross-section through the river deposits.",
     3, [], ["mangold2021"]),
    ("onahu", "Onahu · Upper fan", 821, "geology", "Upper fan",
     "Conglomerate of rounded pebbles carried by a fast river from far outside the crater (Otis Peak core): a grab-bag of rocks from the ancient highlands watershed.",
     3, [], ["mangold2021"]),
    ("pelican", "Pelican Point · Margin unit", 925, "geology", "Margin unit",
     "First station in the carbonate-rich band along the inner crater edge, mapped from orbit by CRISM. Carbonates precipitate from water and can entomb organic matter.",
     4, ["carbonate"], ["horgan2020", "goudge2015"]),
    ("bunsen", "Bunsen Peak · Margin unit", 1084, "astrobiology", "Margin unit",
     "Carbonate and silica cemented rock (Comet Geyser core). Both minerals are excellent at preserving microfossils and organics on Earth.",
     5, ["carbonate", "hydrated-silica"], ["horgan2020"]),
    ("brightangel", "Bright Angel · Cheyava Falls", 1219, "astrobiology", "Neretva Vallis",
     "Mudstone in the inlet river channel with 'leopard spot' reaction fronts of iron phosphate and iron sulfide associated with organic carbon (Sapphire Canyon core) — reported as a potential biosignature that requires sample return to resolve.",
     5, ["hydrated-minerals"], ["hurowitz2025"]),
    ("lookout", "Lookout Hill · Crater rim", 1354, "landmark", "Jezero crater rim",
     "Highest point of the Perseverance traverse, about 780 m above the landing site. Commands a view of the whole crater floor and delta; the climb sustains the steepest slopes of the mission.",
     3, ["vantage"], ["rim"]),
    ("witchhazel", "Witch Hazel Hill", 1411, "geology", "Jezero crater rim · outer slope",
     "Layered outcrop on the outer rim exposing some of the oldest rocks sampled on Mars (Silver Mountain core), uplifted from deep crust by the Jezero impact.",
     5, [], ["rim"]),
]


def waypoint_for(sol):
    """Rover position on `sol`: the last localized waypoint at or before it."""
    return [p for p in WP if p["sol"] <= sol][-1]


out = []
for tid, name, sol, kind, unit, summary, value, tags, refs in TARGETS:
    p = waypoint_for(sol)
    out.append({
        "id": tid, "name": name, "kind": kind, "unit": unit, "summary": summary,
        "scienceValue": value, "resources": tags,
        "lon": round(p["lon"], 6), "lat": round(p["lat"], 6), "elevM": round(p["elev_geoid"], 1),
        "sol": p["sol"], "refs": refs,
    })
    print(f"{tid:12s} sol {p['sol']:5d} {p['lon']:.5f} {p['lat']:.5f} {p['elev_geoid']:.1f}")

(ROOT / "assets/data/science_targets.json").write_text(json.dumps({
    "positionSource": "Perseverance localized rover positions, NASA/JPL MMGIS M20_waypoints.json",
    "note": "scienceValue (1–5) is an editorial planning priority assigned by the Vivited team, not a NASA product.",
    "references": REFS,
    "targets": out,
}, indent=1, ensure_ascii=False))
