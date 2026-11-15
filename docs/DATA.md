# Data: sources and processing

Vivited — Martian Exploration Intelligence System bundles processed copies
of public NASA products. Nothing is synthesised: where a product has no data,
the app shows "no data".

## Sources

| Product | Origin | Used for | Bundled as |
| --- | --- | --- | --- |
| Mars 2020 TRN CTX DTM mosaic, 20 m (MRO CTX stereo; USGS Astrogeology, Fergason et al. 2020) | [USGS label](https://asc-pds-services.s3.us-west-2.amazonaws.com/mosaic/mars2020_trn/CTX/JEZ_ctx_B_soc_008_DTM_MOLAtopography_DeltaGeoid_20m_Eqc_latTs0_lon0.lbl) | Elevation, slope, hazard, routing, shadows, 3D terrain | `assets/data/jezero_dem.bin`, `jezero_meta.json` |
| Mars 2020 TRN CTX orthomosaic, 6 m | [USGS label](https://asc-pds-services.s3.us-west-2.amazonaws.com/mosaic/mars2020_trn/CTX/JEZ_ctx_B_soc_008_orthoMosaic_6m_Eqc_latTs0_lon0.lbl) | Base imagery, terrain drape | `assets/images/jezero_ctx_ortho.jpg`, `_lo.jpg` |
| Mars Odyssey THEMIS night-time IR global mosaic, 100 m | [NASA Mars Trek](https://trek.nasa.gov/mars/) | Night infrared layer | `assets/images/jezero_themis_night.png` |
| Viking MDIM 2.1 colour mosaic | [NASA Mars Trek](https://trek.nasa.gov/mars/) | Globe texture (bundled); regional tiles (streamed) | `assets/images/mars_global_viking.jpg` |
| MGS MOLA MEGDR, 16 px/degree (Smith et al. 2001) | [PDS Geosciences](https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg016/) | Globe elevations, landing-site elevations, independent check of the DTM | `assets/data/mola_global.bin`, `.json` |
| Perseverance traverse and waypoints, to sol 2022 | [NASA/JPL MMGIS layers](https://mars.nasa.gov/mmgis-maps/M20/Layers/json/M20_waypoints.json) | Rover track, station positions, DTM validation | `assets/data/m20_traverse.json` |
| Mars 2020 MEDA calibrated data (Rodriguez-Manfredi et al. 2021) | [PDS Atmospheres](https://pds-atmospheres.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/) | Pressure, air and ground temperature, wind by local hour | `assets/data/meda_climatology.json` |
| MSL RAD surface dose (Hassler et al. 2014) | [doi:10.1126/science.1244797](https://doi.org/10.1126/science.1244797) | Radiation dose | constants in `lib/src/science/radiation.dart` |

## Processing

Run `tool/fetch_raw.sh` to download the raw products (about 80 MB into
`tool/raw/`), then the Python scripts. None of this is needed to run the
app; the processed assets are already in `assets/`.

- **`process_terrain.py`**
  - DTM: read at its native 20 m posting (1596 × 1512 cells, equirectangular
    on a 3 396 190 m sphere, elevations relative to the MOLA areoid) and
    stored as little-endian uint16 with a 5 cm step
    (`elevation = −2800 + 0.05 × value`). Elevations span −2710.7 m to
    −1515.5 m. No smoothing or resampling.
  - Orthomosaic: resampled from 6 m to 12 m and JPEG-compressed; a
    lower-resolution copy is used for the 3D drape.
  - MOLA: box-averaged from 16 to 4 px/degree for the globe.
  - THEMIS night IR and the Viking globe texture are assembled from Mars
    Trek tiles. THEMIS values are normalised mosaic brightness, not kelvin.
  - Rover traverse and waypoints are converted to compact JSON without
    editing positions.
- **`process_meda.py`** averages MEDA's 1 Hz records per local mean solar
  hour for 23 sols spread across one Mars year. Hours with fewer than 30
  valid samples are stored as null. There is no gap filling: the wind sensor
  was damaged in early 2022, so later sols have no wind.
- **`build_targets.py`** builds the 15 science stations. Positions come from
  the localised rover waypoints; descriptions cite the literature listed in
  `science_targets.json`. The 1–5 science-value rating is Vivited's
  editorial planning priority, not a NASA product.
- **`mars_time.py`** holds the Mars24 solar-longitude routine that
  `process_meda.py` uses to assign each sol its season.

## Checks on the terrain model

Computed by `process_terrain.py` and stored in `jezero_meta.json`:

| Comparison | n | Mean difference | RMS | 95 % within |
| --- | --- | --- | --- | --- |
| DTM minus rover waypoint elevations | 708 | −0.8 m | 2.8 m | 5.4 m |
| DTM minus MOLA 16 px/degree | 56 | −3.1 m | 35.7 m | n/a |

The rover comparison confirms that the bundled grid is georeferenced
correctly and agrees with ground truth to a few metres along the traverse.
The MOLA figure mostly reflects MOLA's 3.7 km cells averaging over crater
walls; it shows there is no gross datum offset and should not be read as DTM
error.

`test/terrain_test.dart` repeats the georeferencing and rover checks against
the bundled assets on every test run.

## Known limits of the data

- 20 m posting resolves features of roughly 60 m and larger. Boulders, sand
  ripples and small scarps are invisible to it.
- Stereo DTMs carry local artefacts, especially in bland or shadowed
  terrain. Agreement along the rover traverse does not guarantee the same
  accuracy on the crater rim.
- MEDA values are a climatology of past sols at the rover's location, not a
  forecast. Dust storms are not represented.
- RAD measured at Gale crater in 2012–13. Jezero's elevation differs and
  dose varies with the solar cycle.
- Regional Viking tiles need a connection; all analysis works without them.
