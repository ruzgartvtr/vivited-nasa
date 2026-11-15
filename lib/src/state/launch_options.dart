import 'app_state.dart';

/// Initial interface state read from the page address, so a view can be
/// bookmarked or shared:
///
/// `?workspace=plan&view=terrain&preset=seitah&layers=hazard,walkBack&base=relief&ls=250&start=15.5`
///
/// Unknown names are ignored.
class LaunchOptions {
  const LaunchOptions({
    this.workspace,
    this.view,
    this.basemap,
    this.overlays = const {},
    this.presetId,
    this.ls,
    this.startLtst,
  });

  final Workspace? workspace;
  final StageView? view;
  final Basemap? basemap;
  final Set<MapOverlay> overlays;
  final String? presetId;

  /// Season (areocentric solar longitude, deg) and egress time (LTST hours).
  final double? ls;
  final double? startLtst;

  bool get isEmpty =>
      workspace == null &&
      view == null &&
      basemap == null &&
      overlays.isEmpty &&
      presetId == null &&
      ls == null &&
      startLtst == null;

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    final n = name.toLowerCase();
    for (final v in values) {
      if (v.name.toLowerCase() == n) return v;
    }
    return null;
  }

  static double? _number(String? text, double min, double max) {
    final v = double.tryParse(text ?? '');
    return v == null || v.isNaN || v < min || v > max ? null : v;
  }

  factory LaunchOptions.fromUri(Uri uri) {
    final q = uri.queryParameters;
    final ws = q['workspace'] == 'rehearse' ? 'simulate' : q['workspace'];
    final preset = q['preset'];
    return LaunchOptions(
      workspace: _byName(Workspace.values, ws),
      view: _byName(StageView.values, q['view']),
      basemap: _byName(Basemap.values, q['base']),
      overlays: {
        for (final name in (q['layers'] ?? '').split(','))
          ?_byName(MapOverlay.values, name.trim()),
      },
      presetId: EvaPreset.byId(preset)?.id,
      ls: _number(q['ls'], 0, 360),
      startLtst: _number(q['start'], 5, 17),
    );
  }

  static LaunchOptions fromPage() {
    try {
      return LaunchOptions.fromUri(Uri.base);
    } catch (_) {
      return const LaunchOptions();
    }
  }
}
