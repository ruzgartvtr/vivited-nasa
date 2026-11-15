import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../routing/pathfinder.dart';
import 'climate.dart';
import 'models.dart';
import 'terrain.dart';

/// A step of the start-up sequence, shown on the loading screen.
class LoadStage {
  const LoadStage(this.mission, this.product);
  final String mission;
  final String product;

  static const stages = [
    LoadStage('MRO · CTX', 'Stereo terrain model, 20 m'),
    LoadStage('MRO · CTX', 'Orthomosaic, 12 m'),
    LoadStage('Odyssey · THEMIS', 'Night-time infrared mosaic'),
    LoadStage('Mars 2020', 'Rover traverse and science stations'),
    LoadStage('Mars 2020 · MEDA', 'Surface weather, one Mars year'),
    LoadStage('MGS · MOLA  /  Viking', 'Global topography and colour mosaic'),
  ];
}

class LoadProgress {
  const LoadProgress(this.completed);
  final int completed;
  int get total => LoadStage.stages.length;
  double get fraction => completed / total;
  LoadStage? get current =>
      completed < total ? LoadStage.stages[completed] : null;
}

/// Decoded 8-bit single-band raster with bounds equal to the terrain grid.
class GrayRaster {
  GrayRaster(this.width, this.height, this.data);
  final int width;
  final int height;
  final Uint8List data;

  /// Value at fractional position (u east 0–1, v south 0–1); nearest pixel.
  int at(double u, double v) {
    final x = (u * width).floor().clamp(0, width - 1);
    final y = (v * height).floor().clamp(0, height - 1);
    return data[y * width + x];
  }
}

/// Everything the application needs, decoded and ready.
class AppData {
  AppData({
    required this.terrain,
    required this.terrainMeta,
    required this.traverse,
    required this.targets,
    required this.climate,
    required this.relief,
    required this.ortho,
    required this.themisImage,
    required this.themis,
    required this.globe,
  }) : pathfinder = GridPathfinder(terrain);

  final TerrainGrid terrain;
  final Map<String, dynamic> terrainMeta;
  final RoverTraverse traverse;
  final List<ScienceTarget> targets;
  final Climatology climate;
  final GlobalRelief relief;
  final ui.Image ortho;
  final ui.Image themisImage;
  final GrayRaster themis;
  final ui.Image globe;
  final GridPathfinder pathfinder;

  ScienceTarget? target(String? id) {
    for (final t in targets) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// THEMIS night-IR mosaic DN (0–255) at a coordinate; −1 off the map.
  int themisAt(double lat, double lon) {
    if (!terrain.containsLatLon(lat, lon)) return -1;
    final u = (lon - terrain.west) / (terrain.east - terrain.west);
    final v = (terrain.north - lat) / (terrain.north - terrain.south);
    return themis.at(u, v);
  }
}

class DataLoadException implements Exception {
  DataLoadException(this.stage, this.cause);
  final LoadStage stage;
  final Object cause;
  @override
  String toString() => '${stage.mission} — ${stage.product}: $cause';
}

/// Loads and decodes the bundled NASA datasets.
class DataRepository {
  DataRepository({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  final AssetBundle bundle;
  final ValueNotifier<LoadProgress> progress =
      ValueNotifier(const LoadProgress(0));

  Future<Map<String, dynamic>> _json(String path) async =>
      jsonDecode(await bundle.loadString(path, cache: false))
          as Map<String, dynamic>;

  Future<ui.Image> _image(String path) async {
    final data = await bundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<T> _stage<T>(int index, Future<T> Function() body) async {
    try {
      final v = await body();
      progress.value = LoadProgress(index + 1);
      // Let the loading screen paint between heavy synchronous decodes.
      await Future<void>.delayed(const Duration(milliseconds: 16));
      return v;
    } catch (e) {
      throw DataLoadException(LoadStage.stages[index], e);
    }
  }

  Future<AppData> load() async {
    progress.value = const LoadProgress(0);

    late final Map<String, dynamic> meta;
    final terrain = await _stage(0, () async {
      meta = await _json('assets/data/jezero_meta.json');
      final bytes = await bundle.load('assets/data/jezero_dem.bin');
      final grid = TerrainGrid.fromAsset(bytes, meta);
      grid.slopeDeg; // derive gradients once, up front
      return grid;
    });

    final ortho =
        await _stage(1, () => _image('assets/images/jezero_ctx_ortho.jpg'));

    late final GrayRaster themis;
    final themisImage = await _stage(2, () async {
      final img = await _image('assets/images/jezero_themis_night.png');
      final rgba = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final n = img.width * img.height;
      final gray = Uint8List(n);
      for (var i = 0; i < n; i++) {
        gray[i] = rgba!.getUint8(i * 4);
      }
      themis = GrayRaster(img.width, img.height, gray);
      return img;
    });

    late final List<ScienceTarget> targets;
    final traverse = await _stage(3, () async {
      final t = await _json('assets/data/science_targets.json');
      final refs = t['references'] as Map<String, dynamic>;
      targets = [
        for (final j in t['targets'] as List)
          ScienceTarget.fromJson(j as Map<String, dynamic>, refs),
      ];
      return RoverTraverse.fromJson(
        await _json('assets/data/m20_traverse.json'),
      );
    });

    final climate = await _stage(
      4,
      () async => Climatology.fromJson(
        await _json('assets/data/meda_climatology.json'),
      ),
    );

    late final ui.Image globe;
    final relief = await _stage(5, () async {
      final m = await _json('assets/data/mola_global.json');
      final b = await bundle.load('assets/data/mola_global.bin');
      final rows = m['rows'] as int, cols = m['cols'] as int;
      final data = Int16List(rows * cols);
      for (var i = 0; i < data.length; i++) {
        data[i] = b.getInt16(i * 2, Endian.little);
      }
      globe = await _image('assets/images/mars_global_viking.jpg');
      return GlobalRelief(rows: rows, cols: cols, data: data);
    });

    return AppData(
      terrain: terrain,
      terrainMeta: meta,
      traverse: traverse,
      targets: targets,
      climate: climate,
      relief: relief,
      ortho: ortho,
      themisImage: themisImage,
      themis: themis,
      globe: globe,
    );
  }
}
