"""Build assets/data/meda_climatology.json from the Mars 2020 MEDA PDS4 archive.

Source: NASA PDS Atmospheres Node, Mars 2020 MEDA bundle
  https://pds-atmospheres.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/

For a sample of sols spanning one Mars year, the 1 Hz records are streamed,
binned by local mean solar hour (LMST) and averaged. Nothing is modelled or
interpolated here: an hour with no valid samples stays null.

  pressure     data_derived_env   DER_PS    PRESSURE                 [Pa]
  air temp     data_calibrated_env CAL_ATS  median(ATS_LOCAL_TEMP1-3) [K]  (mast, ~1.45 m)
  ground temp  data_calibrated_env CAL_TIRS GROUND_TEMP              [K]
  wind speed   data_derived_env   DER_WS    HORIZONTAL_WIND_SPEED    [m/s]

Usage: python3 tool/process_meda.py
"""
import csv
import io
import json
import re
import statistics
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from mars_time import m2020_sol_ls

BASE = "https://pds-atmospheres.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda"
OUT = Path(__file__).resolve().parent.parent / "assets" / "data" / "meda_climatology.json"
SOLS = list(range(15, 690, 30))
MISSING = 9.0e8


def fetch(url: str) -> str:
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=180) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:  # noqa: BLE001
            err = e
    raise err


def list_dir(url: str):
    return re.findall(r'href="([^"?/][^"]*)"', fetch(url))


def sol_dir(collection: str, sol: int):
    for rng in list_dir(f"{BASE}/{collection}/"):
        m = re.match(r"sol_(\d{4})_(\d{4})/", rng)
        if m and int(m.group(1)) <= sol <= int(m.group(2)):
            return f"{BASE}/{collection}/{rng}sol_{sol:04d}/"
    return None


def find_file(dir_url: str, key: str):
    try:
        names = [n for n in list_dir(dir_url) if key in n and n.upper().endswith(".CSV")]
    except Exception:  # noqa: BLE001
        return None
    return dir_url + sorted(names)[-1] if names else None


def lmst_hour(s: str):
    m = re.match(r"\d+M(\d\d):(\d\d):(\d\d)", s)
    return int(m.group(1)) if m else None


def valid(x: str):
    try:
        v = float(x)
    except ValueError:
        return None
    return None if abs(v) > MISSING else v


def hourly(url: str, extract):
    """Mean of extract(row) per LMST hour; returns 24 values (None if empty)."""
    sums, counts = [0.0] * 24, [0] * 24
    if url is None:
        return [None] * 24, 0
    rd = csv.DictReader(io.StringIO(fetch(url)))
    for row in rd:
        h = lmst_hour(row.get("LMST", ""))
        if h is None or h > 23:
            continue
        v = extract(row)
        if v is None:
            continue
        sums[h] += v
        counts[h] += 1
    out = [round(sums[h] / counts[h], 2) if counts[h] >= 30 else None for h in range(24)]
    return out, sum(counts)


def ats(row):
    vals = [valid(row.get(f"ATS_LOCAL_TEMP{i}", "")) for i in (1, 2, 3)]
    vals = [v for v in vals if v is not None and 120 < v < 330]
    return statistics.median(vals) if vals else None


def ground(row):
    v = valid(row.get("GROUND_TEMP", ""))
    return v if v is not None and 120 < v < 340 else None


def pressure(row):
    v = valid(row.get("PRESSURE", ""))
    return v if v is not None and 400 < v < 1200 else None


def wind(row):
    v = valid(row.get("HORIZONTAL_WIND_SPEED", ""))
    return v if v is not None and 0 <= v < 100 else None


def process_sol(sol):
    der, cal = sol_dir("data_derived_env", sol), sol_dir("data_calibrated_env", sol)
    if der is None or cal is None:
        return None
    with ThreadPoolExecutor(4) as ex:
        fp = ex.submit(lambda: hourly(find_file(der, "DER_PS"), pressure))
        ft = ex.submit(lambda: hourly(find_file(cal, "CAL_ATS"), ats))
        fg = ex.submit(lambda: hourly(find_file(cal, "CAL_TIRS"), ground))
        fw = ex.submit(lambda: hourly(find_file(der, "DER_WS"), wind))
        (p, np_), (t, nt), (g, ng), (w, nw) = fp.result(), ft.result(), fg.result(), fw.result()
    if np_ + nt + ng == 0:
        return None
    rec = {
        "sol": sol,
        "ls": round(m2020_sol_ls(sol), 2),
        "pressurePa": p,
        "airTempK": t,
        "groundTempK": g,
        "windMs": w,
        "samples": {"pressure": np_, "airTemp": nt, "groundTemp": ng, "wind": nw},
    }
    print(f"sol {sol} ls {rec['ls']} samples p={np_} t={nt} g={ng} w={nw}", flush=True)
    return rec


def main():
    with ThreadPoolExecutor(6) as ex:
        records = [r for r in ex.map(process_sol, SOLS) if r is not None]
    records.sort(key=lambda r: r["sol"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "source": "NASA PDS Atmospheres Node — Mars 2020 MEDA (Perseverance), Jezero crater",
        "url": BASE + "/",
        "citation": "Rodriguez-Manfredi, J.A. et al. (2021), Space Sci. Rev. 217, 48; MEDA PDS4 bundle urn:nasa:pds:mars2020_meda",
        "method": "1 Hz records averaged per local-mean-solar hour; hours with <30 valid samples are null. No gap filling.",
        "sols": records,
    }, separators=(",", ":")))
    print("done", len(records), file=sys.stderr)


if __name__ == "__main__":
    main()
