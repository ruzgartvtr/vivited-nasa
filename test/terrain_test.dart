import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivited/src/data/climate.dart';
import 'package:vivited/src/data/models.dart';
import 'package:vivited/src/data/terrain.dart';
import 'package:vivited/src/science/geodesy.dart';

TerrainGrid loadJezero() {
  final meta = jsonDecode(File('assets/data/jezero_meta.json').readAsStringSync())
      as Map<String, dynamic>;
  final bytes = File('assets/data/jezero_dem.bin').readAsBytesSync();
  return TerrainGrid.fromAsset(ByteData.sublistView(bytes), meta);
}

void main() {
  group('TerrainGrid · synthetic', () {
    test('Horn slope of an inclined plane is exact', () {
      // z = 0.1·x + 0.2·y → slope = atan(√0.05).
      final g = TerrainGrid.synthetic(
        rows: 30,
        cols: 30,
        height: (x, y) => 0.1 * x + 0.2 * y,
      );
      final expected = math.atan(math.sqrt(0.05)) * 180 / math.pi;
      for (final i in [0, 29, g.index(15, 15), g.cellCount - 1]) {
        // The synthetic grid straddles the equator, where cos(lat) differs
        // from 1 by < 1e-8.
        expect(g.slopeDeg[i], closeTo(expected, 1e-3));
        expect(g.gradEast[i], closeTo(0.1, 1e-4));
        expect(g.gradNorth[i], closeTo(0.2, 1e-4));
      }
    });

    test('georeferencing round-trips and bilinear sampling is exact on a plane', () {
      final g = TerrainGrid.synthetic(
        rows: 40,
        cols: 50,
        height: (x, y) => 3 + 0.05 * x - 0.02 * y,
      );
      for (final (r, c) in [(0.0, 0.0), (12.25, 33.5), (39.0, 49.0)]) {
        expect(g.latToRow(g.rowToLat(r)), closeTo(r, 1e-6));
        expect(g.lonToCol(g.colToLon(c)), closeTo(c, 1e-6));
        final z = g.elevationAt(g.rowToLat(r), g.colToLon(c));
        expect(z, closeTo(3 + 0.05 * c * 20 - 0.02 * (39 - r) * 20, 1e-3));
      }
      expect(g.elevationAt(g.north + 1, g.west), isNaN);
      expect(g.cellAt(g.north + 1, g.west), -1);
      expect(g.cellAt(g.rowToLat(7), g.colToLon(9)), g.index(7, 9));
    });

    test('slope histogram sums to one', () {
      final g = TerrainGrid.synthetic(
        rows: 30,
        cols: 30,
        height: (x, y) => 40 * math.sin(x / 90),
      );
      final h = g.slopeHistogram(const [6, 10, 15, 20]);
      expect(h.length, 5);
      expect(h.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });

    test('asset decoder rejects a truncated file', () {
      expect(
        () => TerrainGrid.fromAsset(ByteData(10), {
          'rows': 4, 'cols': 4, 'elevOffsetM': 0, 'elevScaleM': 1,
          'upperLeftX': 0, 'upperLeftY': 0, 'pixelSizeM': 20, 'radiusM': 3396190.0,
        }),
        throwsFormatException,
      );
    });
  });

  group('Jezero CTX DTM (bundled NASA/USGS data)', () {
    final g = loadJezero();

    test('extent and pixel geometry match the USGS label', () {
      expect(g.rows, 1512);
      expect(g.cols, 1596);
      expect(g.west, closeTo(77.16047, 1e-4));
      expect(g.north, closeTo(18.72119, 1e-4));
      expect(g.south, closeTo(18.21103, 1e-4));
      expect(g.cellDy, 20);
      // East–west ground spacing is foreshortened by cos(18.4°).
      expect(g.cellDx(g.rows ~/ 2), closeTo(20 * math.cos(18.466 * math.pi / 180), 0.01));
      // North–south extent agrees with spherical geodesy.
      expect(
        Geodesy.distanceM(g.south, 77.4, g.north, 77.4),
        closeTo(g.rows * 20.0, 1),
      );
    });

    test('elevations agree with Perseverance localization (independent data)', () {
      final j = jsonDecode(File('assets/data/m20_traverse.json').readAsStringSync())
          as Map<String, dynamic>;
      var n = 0;
      var sumSq = 0.0;
      for (final w in j['waypoints'] as List) {
        final z = g.elevationAt((w[1] as num).toDouble(), (w[0] as num).toDouble());
        if (z.isNaN) continue;
        final d = z - (w[3] as num).toDouble();
        sumSq += d * d;
        n++;
      }
      expect(n, greaterThan(600));
      // CTX stereo DTM vs rover elevations: a few metres RMS.
      expect(math.sqrt(sumSq / n), lessThan(4.0));
    });

    test('crater floor is flat, the delta scarp and rim are not', () {
      // Octavia E. Butler Landing: lava plain.
      expect(g.slopeAt(18.44463, 77.45089), lessThan(5));
      expect(g.elevationAt(18.44463, 77.45089), closeTo(-2570, 8));
      final h = g.slopeHistogram(const [6, 10, 15, 20]);
      expect(h[0], greaterThan(0.5)); // most of the map is walkable
      expect(h[4], inInclusiveRange(0.001, 0.2)); // but real no-go ground exists
    });
  });

  group('Bundled catalogues', () {
    test('science targets sit on the map at their recorded elevation', () {
      final g = loadJezero();
      final j = jsonDecode(File('assets/data/science_targets.json').readAsStringSync())
          as Map<String, dynamic>;
      final refs = j['references'] as Map<String, dynamic>;
      final targets = [
        for (final t in j['targets'] as List)
          ScienceTarget.fromJson(t as Map<String, dynamic>, refs),
      ];
      expect(targets.length, greaterThanOrEqualTo(12));
      expect(targets.map((t) => t.id).toSet().length, targets.length);
      for (final t in targets) {
        final z = g.elevationAt(t.position.latitude, t.position.longitude);
        expect(z, closeTo(t.elevationM, 12), reason: t.name);
        expect(t.references, isNotEmpty);
        expect(t.scienceValue, inInclusiveRange(1, 5));
      }
    });

    test('rover traverse parses and stays inside the DTM', () {
      final g = loadJezero();
      final tr = RoverTraverse.fromJson(
        jsonDecode(File('assets/data/m20_traverse.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(tr.path.length, greaterThan(1000));
      expect(tr.totalDistanceM, greaterThan(40000));
      expect(
        tr.path.every((p) => g.containsLatLon(p.latitude, p.longitude)),
        isTrue,
      );
    });

    test('MEDA climatology is physically plausible', () {
      final c = Climatology.fromJson(
        jsonDecode(File('assets/data/meda_climatology.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(c.records.length, greaterThanOrEqualTo(12));
      for (final ls in [0.0, 45.0, 90.0, 180.0, 270.0, 359.0]) {
        final noon = c.sample(ls, 13), night = c.sample(ls, 5);
        expect(noon.airTempK, isNotNull);
        expect(noon.airTempK!, inInclusiveRange(200, 290));
        expect(night.airTempK!, inInclusiveRange(170, 240));
        expect(noon.airTempK!, greaterThan(night.airTempK!));
        expect(noon.pressurePa!, inInclusiveRange(550, 900));
        final range = c.airTempRange(ls)!;
        expect(range.$2 - range.$1, greaterThan(30)); // large diurnal swing
      }
    });

    test('climatology interpolates between bracketing sols and wraps in Ls', () {
      List<double?> flat(double? v) => List.filled(24, v);
      final c = Climatology([
        ClimateRecord(sol: 1, ls: 350, pressurePa: flat(700), airTempK: flat(200), groundTempK: flat(null), windMs: flat(null)),
        ClimateRecord(sol: 2, ls: 10, pressurePa: flat(800), airTempK: flat(220), groundTempK: flat(null), windMs: flat(null)),
      ]);
      expect(c.sample(0, 12).airTempK, closeTo(210, 1e-9));
      expect(c.sample(355, 12).pressurePa, closeTo(725, 1e-9));
      expect(c.sample(10, 3).airTempK, closeTo(220, 1e-9));
      expect(c.sample(0, 12).groundTempK, isNull);
      expect(c.sample(0, 12).solBefore, 1);
      expect(c.sample(0, 12).solAfter, 2);
    });

    test('MOLA global relief: Olympus Mons high, Hellas low, Jezero ≈ −2.5 km', () {
      final bytes = File('assets/data/mola_global.bin').readAsBytesSync();
      final r = GlobalRelief(
        rows: 720,
        cols: 1440,
        data: Int16List.sublistView(bytes),
      );
      expect(r.elevationAt(18.65, -133.8), greaterThan(19000));
      expect(r.elevationAt(-42.4, 70.5), lessThan(-6000));
      expect(r.elevationAt(18.44, 77.45), closeTo(-2550, 250));
    });
  });
}
