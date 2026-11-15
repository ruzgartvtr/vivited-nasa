import 'dart:math' as math;

import 'mars_constants.dart';

/// Spherical geodesy on the Mars reference sphere (R = 3 396 190 m).
class Geodesy {
  const Geodesy._();

  static const double _deg = math.pi / 180.0;

  /// Great-circle distance in metres (haversine).
  static double distanceM(double lat1, double lon1, double lat2, double lon2) {
    final p1 = lat1 * _deg, p2 = lat2 * _deg;
    final dp = p2 - p1, dl = (lon2 - lon1) * _deg;
    final a = math.pow(math.sin(dp / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * marsRadiusM * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// Initial bearing from point 1 to point 2, degrees clockwise from north.
  static double bearingDeg(double lat1, double lon1, double lat2, double lon2) {
    final p1 = lat1 * _deg, p2 = lat2 * _deg, dl = (lon2 - lon1) * _deg;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dl);
    final b = math.atan2(y, x) / _deg;
    return b < 0 ? b + 360 : b;
  }

  /// Metres per degree of latitude.
  static double get metersPerDegLat => marsRadiusM * _deg;

  /// Metres per degree of longitude at [lat].
  static double metersPerDegLon(double lat) =>
      marsRadiusM * _deg * math.cos(lat * _deg);

  static String compass(double bearing) {
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return names[((bearing % 360) / 45).round() % 8];
  }

  static String formatLat(double lat) =>
      '${lat.abs().toStringAsFixed(4)}°${lat >= 0 ? 'N' : 'S'}';

  static String formatLon(double lon) => '${lon.toStringAsFixed(4)}°E';
}
