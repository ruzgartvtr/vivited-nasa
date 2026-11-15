import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

enum TargetKind {
  geology('Geology'),
  astrobiology('Astrobiology'),
  cache('Sample cache'),
  landmark('Landmark');

  const TargetKind(this.label);
  final String label;

  static TargetKind parse(String s) =>
      TargetKind.values.firstWhere((k) => k.name == s, orElse: () => geology);
}

/// A place worth walking to. Positions are Perseverance's own localized
/// positions (see tool/build_targets.py), not hand-placed pins.
class ScienceTarget {
  const ScienceTarget({
    required this.id,
    required this.name,
    required this.kind,
    required this.unit,
    required this.summary,
    required this.scienceValue,
    required this.resources,
    required this.position,
    required this.elevationM,
    required this.sol,
    required this.references,
  });

  factory ScienceTarget.fromJson(
    Map<String, dynamic> j,
    Map<String, dynamic> refs,
  ) =>
      ScienceTarget(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: TargetKind.parse(j['kind'] as String),
        unit: j['unit'] as String,
        summary: j['summary'] as String,
        scienceValue: j['scienceValue'] as int,
        resources: [for (final r in j['resources'] as List) r as String],
        position: LatLng(
          (j['lat'] as num).toDouble(),
          (j['lon'] as num).toDouble(),
        ),
        elevationM: (j['elevM'] as num).toDouble(),
        sol: j['sol'] as int,
        references: [
          for (final r in j['refs'] as List) (refs[r] as String?) ?? '$r',
        ],
      );

  final String id;
  final String name;
  final TargetKind kind;
  final String unit;
  final String summary;

  /// Editorial planning priority 1–5 (Vivited's, not NASA's).
  final int scienceValue;
  final List<String> resources;
  final LatLng position;
  final double elevationM;

  /// Sol on which Perseverance was localized at this position.
  final int sol;
  final List<String> references;

  static const Map<String, String> resourceLabels = {
    'isru-oxygen': 'O₂ from CO₂ demonstrated (MOXIE)',
    'carbonate': 'Carbonate minerals',
    'olivine': 'Olivine',
    'hydrated-minerals': 'Hydrated clays / sulfates',
    'sulfate': 'Sulfates',
    'hydrated-silica': 'Hydrated silica',
    'landing-zone': 'Proven flat, rock-poor ground',
    'vantage': 'Line-of-sight vantage',
  };
}

/// Perseverance's driven path — ground truth that this terrain is
/// trafficable by a wheeled vehicle, and a ready-made reference route.
class RoverTraverse {
  RoverTraverse({
    required this.path,
    required this.pathSols,
    required this.lastSol,
    required this.totalDistanceM,
  });

  factory RoverTraverse.fromJson(Map<String, dynamic> j) {
    final pts = j['path'] as List;
    return RoverTraverse(
      path: [
        for (final p in pts)
          LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
      ],
      pathSols: Int32List.fromList([for (final p in pts) p[2] as int]),
      lastSol: j['lastSol'] as int,
      totalDistanceM: (j['totalDistanceM'] as num).toDouble(),
    );
  }

  final List<LatLng> path;
  final Int32List pathSols;
  final int lastSol;
  final double totalDistanceM;
}

/// MOLA global topography at 4 px/deg for the orbital view.
class GlobalRelief {
  GlobalRelief({required this.rows, required this.cols, required this.data});

  final int rows;
  final int cols;

  /// Metres above the areoid, row-major from 90°N / 180°W.
  final Int16List data;

  /// Elevation (m) at planetocentric [lat], east-positive [lon].
  double elevationAt(double lat, double lon) {
    final l = ((lon + 180.0) % 360.0 + 360.0) % 360.0;
    final c = (l / 360.0 * cols).floor().clamp(0, cols - 1);
    final r = ((90.0 - lat) / 180.0 * rows).floor().clamp(0, rows - 1);
    return data[r * cols + c].toDouble();
  }
}

/// A historic NASA landing site for global context.
class LandingSite {
  const LandingSite(this.name, this.year, this.lat, this.lon);
  final String name;
  final int year;
  final double lat;
  final double lon;

  /// Planetocentric latitude, east-positive longitude (IAU 2000).
  static const List<LandingSite> nasa = [
    LandingSite('Viking 1', 1976, 22.27, -47.95),
    LandingSite('Viking 2', 1976, 47.64, 134.29),
    LandingSite('Pathfinder', 1997, 19.10, -33.25),
    LandingSite('Spirit', 2004, -14.57, 175.47),
    LandingSite('Opportunity', 2004, -1.95, -5.53),
    LandingSite('Phoenix', 2008, 68.22, -125.75),
    LandingSite('Curiosity', 2012, -4.59, 137.44),
    LandingSite('InSight', 2018, 4.50, 135.62),
    LandingSite('Perseverance', 2021, 18.44, 77.45),
  ];
}
