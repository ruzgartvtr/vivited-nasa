"""Convert authentic NASA/USGS rasters into compact assets for the Vivited app.

Inputs (downloaded into tool/raw/, see tool/fetch_raw.sh):
  * USGS Astrogeology Mars 2020 TRN CTX DTM mosaic, 20 m/px   (MRO CTX stereo, tied to MOLA)
  * USGS Astrogeology Mars 2020 TRN CTX orthomosaic, 6 m/px   (MRO CTX)
  * MGS MOLA MEGDR 16 px/deg topography (megt90n000eb.img)     (PDS Geosciences)
  * Mars 2020 traverse + waypoints GeoJSON                     (NASA/JPL MMGIS)
Fetched here from NASA Solar System Treks WMTS:
  * THEMIS night-time IR controlled mosaic 100 m (Mars Odyssey)
  * Viking MDIM 2.1 colour mosaic (global context)

No value is synthesised. The only operations are cropping, resampling,
quantisation (0.05 m for the DTM) and format conversion.
"""
import io
import json
import math
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "tool" / "raw"
DATA = ROOT / "assets" / "data"
IMG = ROOT / "assets" / "images"
DATA.mkdir(parents=True, exist_ok=True)
IMG.mkdir(parents=True, exist_ok=True)

R_MARS = 3396190.0
UL_X, UL_Y = 4573663.250853, 1109693.140188
DTM_RES = 20.0
ELEV_OFFSET, ELEV_SCALE = -2800.0, 0.05
TREK = "https://trek.nasa.gov/tiles/Mars/EQ/{layer}/1.0.0/default/default028mm/{z}/{row}/{col}.{ext}"


def lonlat_to_rc(lon, lat, res=DTM_RES):
    x, y = R_MARS * math.radians(lon), R_MARS * math.radians(lat)
    return (UL_Y - y) / res, (x - UL_X) / res


def bilinear(a, r, c):
    r0, c0 = int(math.floor(r)), int(math.floor(c))
    fr, fc = r - r0, c - c0
    return ((a[r0, c0] * (1 - fc) + a[r0, c0 + 1] * fc) * (1 - fr)
            + (a[r0 + 1, c0] * (1 - fc) + a[r0 + 1, c0 + 1] * fc) * fr)


def trek_mosaic(layer, ext, z, west, east, south, north):
    """Stitch Trek WMTS tiles (equirectangular, 2x1 tiles at level 0) and crop to the bbox."""
    n = 2 ** z
    px_per_deg = 256 * 2 * n / 360.0
    c0, c1 = int((west + 180) / 360 * 2 * n), int((east + 180) / 360 * 2 * n - 1e-9)
    r0, r1 = int((90 - north) / 180 * n), int((90 - south) / 180 * n - 1e-9)
    canvas = Image.new("RGB", ((c1 - c0 + 1) * 256, (r1 - r0 + 1) * 256))
    for r in range(r0, r1 + 1):
        for c in range(c0, c1 + 1):
            url = TREK.format(layer=layer, z=z, row=r, col=c, ext=ext)
            with urllib.request.urlopen(url, timeout=60) as resp:
                tile = Image.open(io.BytesIO(resp.read())).convert("RGB")
            canvas.paste(tile, ((c - c0) * 256, (r - r0) * 256))
    left = (west + 180) * px_per_deg - c0 * 256
    top = (90 - north) * px_per_deg - r0 * 256
    return canvas.crop((round(left), round(top), round(left + (east - west) * px_per_deg),
                        round(top + (north - south) * px_per_deg)))


def main():
    report = {}

    # ---- CTX DTM ---------------------------------------------------------
    dtm = np.array(Image.open(RAW / "JEZ_ctx_B_soc_008_DTM_MOLAtopography_DeltaGeoid_20m_Eqc_latTs0_lon0.tif"))
    rows, cols = dtm.shape
    assert (dtm > -1e30).all(), "DTM contains nodata"
    q = np.round((dtm - ELEV_OFFSET) / ELEV_SCALE)
    assert q.min() >= 0 and q.max() < 65535
    q.astype("<u2").tofile(DATA / "jezero_dem.bin")
    west = math.degrees(UL_X / R_MARS)
    north = math.degrees(UL_Y / R_MARS)
    east = math.degrees((UL_X + cols * DTM_RES) / R_MARS)
    south = math.degrees((UL_Y - rows * DTM_RES) / R_MARS)
    meta = {
        "name": "Jezero crater — Mars 2020 TRN CTX DTM mosaic",
        "rows": rows, "cols": cols,
        "projection": "Equirectangular, lat_ts=0, lon0=0, sphere R=3396190 m (planetocentric, east-positive)",
        "radiusM": R_MARS, "upperLeftX": UL_X, "upperLeftY": UL_Y, "pixelSizeM": DTM_RES,
        "west": west, "east": east, "south": south, "north": north,
        "elevOffsetM": ELEV_OFFSET, "elevScaleM": ELEV_SCALE,
        "elevMinM": float(dtm.min()), "elevMaxM": float(dtm.max()),
        "verticalDatum": "MOLA areoid (DeltaGeoid applied by USGS)",
        "encoding": "uint16 little-endian, row-major from north-west corner; elevation = offset + scale * value",
    }

    # ---- CTX orthomosaic ---------------------------------------------------
    ortho = Image.open(RAW / "JEZ_ctx_B_soc_008_orthoMosaic_6m_Eqc_latTs0_lon0.tif")
    # Orthomosaic shares the DTM's upper-left corner; crop to the DTM footprint.
    ow, oh = round(cols * DTM_RES / 6.0), round(rows * DTM_RES / 6.0)
    ortho = ortho.crop((0, 0, ow, oh)).resize((ow // 2, oh // 2), Image.LANCZOS)
    ortho.save(IMG / "jezero_ctx_ortho.jpg", quality=86, optimize=True)
    ortho.resize((ow // 5, oh // 5), Image.LANCZOS).save(IMG / "jezero_ctx_ortho_lo.jpg", quality=84, optimize=True)
    meta["ortho"] = {"file": "jezero_ctx_ortho.jpg", "width": ow // 2, "height": oh // 2, "metersPerPixel": 12.0}

    # ---- THEMIS night IR ----------------------------------------------------
    th = trek_mosaic("THEMIS_NightIR_ControlledMosaics_100m_v2_oct2018", "png", 9, west, east, south, north).convert("L")
    th.save(IMG / "jezero_themis_night.png", optimize=True)
    tha = np.array(th)
    meta["themisNight"] = {"file": "jezero_themis_night.png", "width": th.width, "height": th.height,
                           "note": "8-bit normalised mosaic DN (relative night-time brightness temperature, not kelvin)"}
    report["themis_dn_range"] = [int(tha.min()), int(tha.max())]
    report["themis_zero_fraction"] = float((tha == 0).mean())

    # ---- Global context: Viking MDIM + MOLA ---------------------------------
    trek_mosaic("Mars_Viking_MDIM21_ClrMosaic_global_232m", "jpg", 2, -180, 180, -90, 90).save(
        IMG / "mars_global_viking.jpg", quality=88, optimize=True)
    mola = np.fromfile(RAW / "megt90n000eb.img", dtype=">i2").reshape(2880, 5760)
    # MEGDR samples start at 0 E; roll so column 0 is 180 W, then average 4x4 -> 4 px/deg.
    mola_c = np.roll(mola, 2880, axis=1).astype(np.float64)
    g = mola_c.reshape(720, 4, 1440, 4).mean(axis=(1, 3))
    np.round(g).astype("<i2").tofile(DATA / "mola_global.bin")
    meta_global = {"rows": 720, "cols": 1440, "pixelsPerDegree": 4, "west": -180, "north": 90,
                   "encoding": "int16 little-endian metres above the MOLA areoid, row-major from 90N/180W",
                   "source": "MGS MOLA MEGDR megt90n000eb.img (16 px/deg) box-averaged to 4 px/deg",
                   "minM": float(g.min()), "maxM": float(g.max())}
    (DATA / "mola_global.json").write_text(json.dumps(meta_global, indent=1))

    # ---- Cross-mission consistency checks -----------------------------------
    # MOLA 16 ppd vs the mean of the CTX DTM cells inside each MOLA cell.
    diffs = []
    for lat in np.arange(south + 0.05, north - 0.05, 0.0625):
        for lon in np.arange(west + 0.05, east - 0.05, 0.0625):
            mr, mc = int((90 - lat) * 16), int((lon % 360) * 16)
            lat_c, lon_c = 90 - (mr + 0.5) / 16, (mc + 0.5) / 16
            r, c = lonlat_to_rc(lon_c, lat_c)
            hw_r, hw_c = 0.03125 * math.pi / 180 * R_MARS / DTM_RES, 0.03125 * math.pi / 180 * R_MARS / DTM_RES
            r0, r1, c0, c1 = int(r - hw_r), int(r + hw_r), int(c - hw_c), int(c + hw_c)
            if r0 < 0 or c0 < 0 or r1 >= rows or c1 >= cols:
                continue
            diffs.append(float(dtm[r0:r1, c0:c1].mean()) - float(mola[mr, mc]))
    diffs = np.array(sorted(set(diffs)))
    report["ctx_minus_mola_m"] = {"n": int(diffs.size), "mean": float(diffs.mean()), "rms": float(np.sqrt((diffs ** 2).mean()))}

    # ---- Perseverance traverse ----------------------------------------------
    wp = json.load(open(RAW / "M20_waypoints.json"))["features"]
    tr = json.load(open(RAW / "M20_traverse.json"))["features"]
    resid = []
    waypoints = []
    for f in wp:
        p = f["properties"]
        r, c = lonlat_to_rc(p["lon"], p["lat"])
        if 1 <= r < rows - 2 and 1 <= c < cols - 2:
            resid.append(bilinear(dtm, r, c) - p["elev_geoid"])
        waypoints.append([round(p["lon"], 6), round(p["lat"], 6), p["sol"], round(p["elev_geoid"], 1),
                          round(p["dist_total_m"], 1)])
    resid = np.array(resid)
    report["ctx_minus_rover_elev_m"] = {"n": int(resid.size), "mean": float(resid.mean()),
                                        "rms": float(np.sqrt((resid ** 2).mean())),
                                        "p95_abs": float(np.percentile(np.abs(resid), 95))}
    line = []
    for f in tr:
        geom = f["geometry"]
        parts = geom["coordinates"] if geom["type"] == "MultiLineString" else [geom["coordinates"]]
        for part in parts:
            for pt in part:
                line.append((pt[0], pt[1], f["properties"]["sol"]))
    # Thin to >= 8 m spacing (keeps shape; the rover often re-localises in place).
    thin = [line[0]]
    kx = math.cos(math.radians(18.45)) * math.pi / 180 * R_MARS
    ky = math.pi / 180 * R_MARS
    for pt in line[1:]:
        d = math.hypot((pt[0] - thin[-1][0]) * kx, (pt[1] - thin[-1][1]) * ky)
        if d >= 8.0:
            thin.append(pt)
    thin.append(line[-1])
    (DATA / "m20_traverse.json").write_text(json.dumps({
        "source": "NASA/JPL-Caltech Mars 2020 'Where is Perseverance?' MMGIS layers (M20_traverse.json, M20_waypoints.json)",
        "url": "https://mars.nasa.gov/mmgis-maps/M20/Layers/json/",
        "lastSol": wp[-1]["properties"]["sol"],
        "totalDistanceM": wp[-1]["properties"]["dist_total_m"],
        "path": [[round(a, 6), round(b, 6), s] for a, b, s in thin],
        "waypointFields": ["lon", "lat", "sol", "elevGeoidM", "odometryM"],
        "waypoints": waypoints,
    }, separators=(",", ":")))
    report["traverse_points"] = len(thin)

    meta["validation"] = report
    (DATA / "jezero_meta.json").write_text(json.dumps(meta, indent=1))
    print(json.dumps(report, indent=1))
    print("bounds", west, east, south, north, "size", cols, rows)


if __name__ == "__main__":
    main()
