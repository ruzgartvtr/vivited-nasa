"""Mars solar-timing helpers (Allison & McEwen 2000, the "Mars24" algorithm).

Shared by the offline data-processing scripts. The Flutter app has its own
native Dart implementation in lib/src/science/mars_time.dart.
"""
import math
from datetime import datetime, timedelta, timezone

M2020_LANDING_UTC = datetime(2021, 2, 18, 20, 55, 0, tzinfo=timezone.utc)
M2020_LANDING_LMST_H = 15.9  # local mean solar time at touchdown (approx.)
SOL_SECONDS = 88775.244


def julian_date_tt(utc: datetime) -> float:
    jd_utc = utc.timestamp() / 86400.0 + 2440587.5
    return jd_utc + 69.184 / 86400.0  # TT-UTC since 2017


def solar_longitude(utc: datetime) -> float:
    dt = julian_date_tt(utc) - 2451545.0
    m = math.radians(19.3871 + 0.52402073 * dt)
    a_fms = 270.3871 + 0.524038496 * dt
    amp = [0.0071, 0.0057, 0.0039, 0.0037, 0.0021, 0.0020, 0.0018]
    tau = [2.2353, 2.7543, 1.1177, 15.7866, 2.1354, 2.4694, 32.8493]
    phi = [49.409, 168.173, 191.837, 21.736, 15.704, 95.528, 49.095]
    pbs = sum(a * math.cos(math.radians(0.985626 * dt / t + p)) for a, t, p in zip(amp, tau, phi))
    nu_m = ((10.691 + 3.0e-7 * dt) * math.sin(m) + 0.623 * math.sin(2 * m) + 0.050 * math.sin(3 * m)
            + 0.005 * math.sin(4 * m) + 0.0005 * math.sin(5 * m) + pbs)
    return (a_fms + nu_m) % 360.0


def m2020_sol_noon_utc(sol: int) -> datetime:
    return M2020_LANDING_UTC + timedelta(seconds=(sol + (12.0 - M2020_LANDING_LMST_H) / 24.0) * SOL_SECONDS)


def m2020_sol_ls(sol: int) -> float:
    return solar_longitude(m2020_sol_noon_utc(sol))


if __name__ == "__main__":
    for s in (0, 100, 362, 668):
        print(s, m2020_sol_noon_utc(s).isoformat(), round(m2020_sol_ls(s), 2))
