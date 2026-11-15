import 'dart:math' as math;

import 'mars_constants.dart';

/// Mars solar timing after Allison & McEwen (2000), "A post-Pathfinder
/// evaluation of areocentric solar coordinates…", Planet. Space Sci. 48, 215 —
/// the algorithm behind NASA GISS Mars24.
///
/// All angles in the public API are degrees; hours are Mars solar hours
/// (1/24 sol) unless stated otherwise.
class MarsTime {
  const MarsTime._();

  static const double _deg = math.pi / 180.0;

  /// TT − UTC in seconds (32.184 s + leap seconds). 69.184 s since 2017.
  static double ttMinusUtcSeconds(DateTime utc) {
    // Leap-second table from 1999 onwards is enough for the Mars missions
    // this app deals with.
    const table = <(int, int, int, double)>[
      (2017, 1, 1, 69.184),
      (2015, 7, 1, 68.184),
      (2012, 7, 1, 67.184),
      (2009, 1, 1, 66.184),
      (2006, 1, 1, 65.184),
      (1999, 1, 1, 64.184),
    ];
    for (final (y, m, d, v) in table) {
      if (!utc.isBefore(DateTime.utc(y, m, d))) return v;
    }
    return 64.184;
  }

  static double julianDateUtc(DateTime utc) =>
      utc.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  static double julianDateTt(DateTime utc) =>
      julianDateUtc(utc) + ttMinusUtcSeconds(utc) / 86400.0;

  /// Days since the J2000 epoch (TT).
  static double deltaJ2000(DateTime utc) => julianDateTt(utc) - 2451545.0;

  /// Mars mean anomaly M (deg).
  static double meanAnomaly(double dtJ2000) =>
      _norm360(19.3871 + 0.52402073 * dtJ2000);

  /// Angle of the fictitious mean sun αFMS (deg).
  static double fictitiousMeanSun(double dtJ2000) =>
      _norm360(270.3871 + 0.524038496 * dtJ2000);

  /// Planetary perturbation term PBS (deg).
  static double perturbers(double dtJ2000) {
    const a = [0.0071, 0.0057, 0.0039, 0.0037, 0.0021, 0.0020, 0.0018];
    const tau = [2.2353, 2.7543, 1.1177, 15.7866, 2.1354, 2.4694, 32.8493];
    const phi = [49.409, 168.173, 191.837, 21.736, 15.704, 95.528, 49.095];
    var s = 0.0;
    for (var i = 0; i < 7; i++) {
      s += a[i] * math.cos((0.985626 * dtJ2000 / tau[i] + phi[i]) * _deg);
    }
    return s;
  }

  /// Equation of centre ν − M (deg).
  static double equationOfCenter(double dtJ2000) {
    final m = meanAnomaly(dtJ2000) * _deg;
    return (10.691 + 3.0e-7 * dtJ2000) * math.sin(m) +
        0.623 * math.sin(2 * m) +
        0.050 * math.sin(3 * m) +
        0.005 * math.sin(4 * m) +
        0.0005 * math.sin(5 * m) +
        perturbers(dtJ2000);
  }

  /// Areocentric solar longitude Ls (deg) — the Martian season angle.
  /// 0° = northern spring equinox, 90° = northern summer solstice.
  static double solarLongitude(DateTime utc) {
    final dt = deltaJ2000(utc);
    return _norm360(fictitiousMeanSun(dt) + equationOfCenter(dt));
  }

  /// Equation of time (deg) for a given instant. Positive = true sun ahead of
  /// the mean sun.
  static double equationOfTimeDeg(DateTime utc) {
    final dt = deltaJ2000(utc);
    final ls = solarLongitude(utc) * _deg;
    return 2.861 * math.sin(2 * ls) -
        0.071 * math.sin(4 * ls) +
        0.002 * math.sin(6 * ls) -
        equationOfCenter(dt);
  }

  /// Equation of time (deg) as a function of season only, using the
  /// Keplerian equation of centre (e = 0.0934, perihelion at Ls = 250.99°).
  /// Agrees with [equationOfTimeDeg] to ~0.1° (< 30 s of clock time).
  ///
  /// LTST = LMST + EOT/15, so this converts between the true-sun clock used
  /// for illumination and the mean-sun clock MEDA records are stamped with.
  static double equationOfTimeFromLs(double ls) {
    const e = 0.0934, lsPeri = 250.99;
    final nu = _norm360(ls - lsPeri) * _deg;
    final ecc = 2 *
        math.atan2(
          math.sqrt(1 - e) * math.sin(nu / 2),
          math.sqrt(1 + e) * math.cos(nu / 2),
        );
    final m = ecc - e * math.sin(ecc);
    var nuMinusM = (nu - m) / _deg;
    nuMinusM = (nuMinusM + 540) % 360 - 180;
    final l = ls * _deg;
    return 2.861 * math.sin(2 * l) -
        0.071 * math.sin(4 * l) +
        0.002 * math.sin(6 * l) -
        nuMinusM;
  }

  /// Local mean solar time for a local true solar time at season [ls].
  static double lmstFromLtst(double ltst, double ls) =>
      _norm24(ltst - equationOfTimeFromLs(ls) / 15.0);

  /// Mars Sol Date.
  static double marsSolDate(DateTime utc) =>
      (julianDateTt(utc) - 2405522.0028779) / 1.0274912517;

  /// Coordinated Mars Time (mean solar time at 0° longitude), hours 0–24.
  static double coordinatedMarsTime(DateTime utc) =>
      (24.0 * marsSolDate(utc)) % 24.0;

  /// Local mean solar time at [lonEast] (deg), hours 0–24.
  static double localMeanSolarTime(DateTime utc, double lonEast) =>
      _norm24(coordinatedMarsTime(utc) + lonEast / 15.0);

  /// Local true solar time at [lonEast] (deg), hours 0–24.
  static double localTrueSolarTime(DateTime utc, double lonEast) =>
      _norm24(localMeanSolarTime(utc, lonEast) + equationOfTimeDeg(utc) / 15.0);

  /// Solar declination (deg) for solar longitude [ls] (deg).
  static double solarDeclination(double ls) {
    final l = ls * _deg;
    return math.asin(0.42565 * math.sin(l)) / _deg + 0.25 * math.sin(l);
  }

  /// Heliocentric distance (AU) for a given instant.
  static double sunDistanceAu(DateTime utc) =>
      sunDistanceAuFromMeanAnomaly(meanAnomaly(deltaJ2000(utc)));

  static double sunDistanceAuFromMeanAnomaly(double mDeg) {
    final m = mDeg * _deg;
    return 1.52367934 *
        (1.00436 -
            0.09309 * math.cos(m) -
            0.004336 * math.cos(2 * m) -
            0.00031 * math.cos(3 * m) -
            0.00003 * math.cos(4 * m));
  }

  /// Heliocentric distance (AU) as a function of season only, from the
  /// Keplerian orbit (a = 1.52368 AU, e = 0.0934, perihelion at Ls = 251°).
  /// Agrees with [sunDistanceAu] to better than 0.2 %.
  static double sunDistanceAuFromLs(double ls) {
    const a = 1.52367934, e = 0.0934, lsPeri = 250.99;
    final nu = (ls - lsPeri) * _deg;
    return a * (1 - e * e) / (1 + e * math.cos(nu));
  }

  /// Top-of-atmosphere solar flux (W/m²) at season [ls].
  static double solarFluxToa(double ls) {
    final r = sunDistanceAuFromLs(ls);
    return solarConstant1Au / (r * r);
  }

  /// Sun elevation above the ideal horizon (deg).
  ///
  /// [ltst] local true solar time in hours, [latDeg] planetocentric latitude.
  static double sunElevation({
    required double ls,
    required double latDeg,
    required double ltst,
  }) {
    final d = solarDeclination(ls) * _deg;
    final p = latDeg * _deg;
    final h = (ltst - 12.0) * 15.0 * _deg;
    final s =
        math.sin(d) * math.sin(p) + math.cos(d) * math.cos(p) * math.cos(h);
    return math.asin(s.clamp(-1.0, 1.0)) / _deg;
  }

  /// Sun azimuth, degrees clockwise from north.
  static double sunAzimuth({
    required double ls,
    required double latDeg,
    required double ltst,
  }) {
    final d = solarDeclination(ls) * _deg;
    final p = latDeg * _deg;
    final h = (ltst - 12.0) * 15.0 * _deg;
    // East, north components of the sun unit vector.
    final e = -math.cos(d) * math.sin(h);
    final n =
        math.sin(d) * math.cos(p) - math.cos(d) * math.sin(p) * math.cos(h);
    return _norm360(math.atan2(e, n) / _deg);
  }

  /// Half day length in solar hours (geometric, no refraction; the thin
  /// Martian atmosphere refracts < 0.1°). Returns 0 in polar night and 12 in
  /// polar day.
  static double halfDayHours({required double ls, required double latDeg}) {
    final d = solarDeclination(ls) * _deg;
    final p = latDeg * _deg;
    final c = -math.tan(p) * math.tan(d);
    if (c >= 1) return 0;
    if (c <= -1) return 12;
    return math.acos(c) / _deg / 15.0;
  }

  static double sunriseLtst({required double ls, required double latDeg}) =>
      12.0 - halfDayHours(ls: ls, latDeg: latDeg);

  static double sunsetLtst({required double ls, required double latDeg}) =>
      12.0 + halfDayHours(ls: ls, latDeg: latDeg);

  /// Name of the northern-hemisphere season for [ls].
  static String seasonName(double ls) {
    final l = _norm360(ls);
    if (l < 90) return 'Northern spring';
    if (l < 180) return 'Northern summer';
    if (l < 270) return 'Northern autumn';
    return 'Northern winter';
  }

  /// Formats solar hours as HH:MM.
  static String formatClock(double hours) {
    final h = _norm24(hours);
    var hh = h.floor();
    var mm = ((h - hh) * 60).round();
    if (mm == 60) {
      mm = 0;
      hh = (hh + 1) % 24;
    }
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  static double _norm360(double v) {
    final r = v % 360.0;
    return r < 0 ? r + 360.0 : r;
  }

  static double _norm24(double v) {
    final r = v % 24.0;
    return r < 0 ? r + 24.0 : r;
  }
}
