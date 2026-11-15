import 'dart:math' as math;

/// One sampled sol of Perseverance MEDA measurements, averaged per local
/// mean solar hour. `null` = the instrument has no valid data in that hour.
class ClimateRecord {
  ClimateRecord({
    required this.sol,
    required this.ls,
    required this.pressurePa,
    required this.airTempK,
    required this.groundTempK,
    required this.windMs,
  });

  factory ClimateRecord.fromJson(Map<String, dynamic> j) {
    List<double?> arr(String k) => [
          for (final v in (j[k] as List)) (v as num?)?.toDouble(),
        ];
    return ClimateRecord(
      sol: j['sol'] as int,
      ls: (j['ls'] as num).toDouble(),
      pressurePa: arr('pressurePa'),
      airTempK: arr('airTempK'),
      groundTempK: arr('groundTempK'),
      windMs: arr('windMs'),
    );
  }

  final int sol;
  final double ls;
  final List<double?> pressurePa;
  final List<double?> airTempK;
  final List<double?> groundTempK;
  final List<double?> windMs;
}

/// Conditions at one season and time of day, with provenance.
class ClimateSample {
  const ClimateSample({
    this.airTempK,
    this.groundTempK,
    this.pressurePa,
    this.windMs,
    required this.solBefore,
    required this.solAfter,
  });

  final double? airTempK;
  final double? groundTempK;
  final double? pressurePa;
  final double? windMs;

  /// The two measured sols the values were interpolated between.
  final int solBefore;
  final int solAfter;

  double? get airTempC => airTempK == null ? null : airTempK! - 273.15;
  double? get groundTempC =>
      groundTempK == null ? null : groundTempK! - 273.15;
}

/// Seasonal/diurnal lookup over measured MEDA sols.
///
/// Values between sampled sols are linearly interpolated in solar longitude
/// and local time. This describes the Mars-year sampled (MY 36, 2021–2022);
/// year-to-year variability, especially during dust storms, is not captured.
class Climatology {
  Climatology(List<ClimateRecord> records, {this.source = '', this.citation = ''})
      : records = [...records]..sort((a, b) => a.ls.compareTo(b.ls)) {
    if (this.records.isEmpty) {
      throw ArgumentError('Climatology needs at least one record');
    }
  }

  factory Climatology.fromJson(Map<String, dynamic> j) => Climatology(
        [
          for (final s in j['sols'] as List)
            ClimateRecord.fromJson(s as Map<String, dynamic>),
        ],
        source: j['source'] as String? ?? '',
        citation: j['citation'] as String? ?? '',
      );

  /// Records sorted by solar longitude.
  final List<ClimateRecord> records;
  final String source;
  final String citation;

  static double? _hourly(List<double?> a, double lmst) {
    final x = (lmst - 0.5) % 24.0;
    final i0 = x.floor() % 24, i1 = (i0 + 1) % 24;
    final f = x - x.floor();
    final v0 = a[i0], v1 = a[i1];
    if (v0 == null) return v1;
    if (v1 == null) return v0;
    return v0 * (1 - f) + v1 * f;
  }

  static double? _mix(double? a, double? b, double f) {
    if (a == null) return b;
    if (b == null) return a;
    return a * (1 - f) + b * f;
  }

  /// Bracketing records for [ls] and the interpolation weight of the second.
  (ClimateRecord, ClimateRecord, double) _bracket(double ls) {
    final l = ls % 360.0;
    final n = records.length;
    var hi = records.indexWhere((r) => r.ls >= l);
    if (hi == -1) hi = 0; // wraps past the last record
    final lo = (hi - 1 + n) % n;
    final a = records[lo], b = records[hi];
    final span = (b.ls - a.ls + 360.0) % 360.0;
    if (span == 0) return (a, b, 0);
    final f = ((l - a.ls + 360.0) % 360.0) / span;
    return (a, b, f.clamp(0.0, 1.0));
  }

  /// Measured conditions interpolated to season [ls] (deg) and local mean
  /// solar time [lmst] (hours).
  ClimateSample sample(double ls, double lmst) {
    final (a, b, f) = _bracket(ls);
    return ClimateSample(
      airTempK: _mix(_hourly(a.airTempK, lmst), _hourly(b.airTempK, lmst), f),
      groundTempK:
          _mix(_hourly(a.groundTempK, lmst), _hourly(b.groundTempK, lmst), f),
      pressurePa:
          _mix(_hourly(a.pressurePa, lmst), _hourly(b.pressurePa, lmst), f),
      windMs: _mix(_hourly(a.windMs, lmst), _hourly(b.windMs, lmst), f),
      solBefore: a.sol,
      solAfter: b.sol,
    );
  }

  /// Minimum and maximum hourly air temperature (K) over the sol at [ls].
  (double, double)? airTempRange(double ls) {
    double? lo, hi;
    for (var h = 0; h < 24; h++) {
      final t = sample(ls, h + 0.5).airTempK;
      if (t == null) continue;
      lo = lo == null ? t : math.min(lo, t);
      hi = hi == null ? t : math.max(hi, t);
    }
    return lo == null ? null : (lo, hi!);
  }

  /// 24 hourly values of a quantity at season [ls] for charting.
  List<double?> diurnal(double ls, double? Function(ClimateSample) pick) =>
      [for (var h = 0; h < 24; h++) pick(sample(ls, h + 0.5))];
}
