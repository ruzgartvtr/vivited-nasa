import '../science/provenance.dart';

/// Fixed educational mission marks inside the Jezero study area.
///
/// Positions are the real Perseverance-localized science stations listed in
/// [targetId]. The habitat and safety roles themselves are fictional mission
/// infrastructure ([SourceClass.simulation]); the geography and rover
/// observations at those coordinates remain NASA data.
class MissionCheckpoint {
  const MissionCheckpoint({
    required this.code,
    required this.targetId,
    required this.title,
    required this.role,
    required this.summary,
    required this.classification,
  });

  /// Short map label: H0, CP1, CP2, CP3, SH.
  final String code;

  /// Science-target id whose lat/lon is used (never invented).
  final String targetId;
  final String title;
  final String role;
  final String summary;
  final SourceClass classification;

  static const all = [
    MissionCheckpoint(
      code: 'H0',
      targetId: 'threeforks',
      title: 'Habitat H0',
      role: 'Mission start and return',
      summary:
          'Fictional astronaut habitat co-located with the Three Forks sample '
          'depot — flat, rock-poor ground already proven by Perseverance as a '
          'safe staging zone at the fan–floor contact. The habitat itself is '
          'simulated; the location and terrain are NASA observations.',
      classification: SourceClass.simulation,
    ),
    MissionCheckpoint(
      code: 'CP1',
      targetId: 'amalik',
      title: 'CP1 · Terrain Checkpoint',
      role: 'Surface conditions and accessibility',
      summary:
          'Amalik (Cape Nukshak) at the base of the delta scarp. Astronauts '
          'would inspect slopes, bedforms and trafficability where CTX stereo '
          'elevation meets lake-deposited sedimentary rock.',
      classification: SourceClass.interpretation,
    ),
    MissionCheckpoint(
      code: 'CP2',
      targetId: 'wildcat',
      title: 'CP2 · Validation Checkpoint',
      role: 'Check earlier robotic observations',
      summary:
          'Wildcat Ridge / Hogwallow Flats. Perseverance reported strong '
          'organic-associated signals in sulfate-bearing mudstone here. A crew '
          'could compare those robotic measurements with new field context.',
      classification: SourceClass.interpretation,
    ),
    MissionCheckpoint(
      code: 'CP3',
      targetId: 'brightangel',
      title: 'CP3 · Discovery Checkpoint',
      role: 'New geological question',
      summary:
          'Bright Angel / Cheyava Falls in Neretva Vallis. Mudstone with '
          'leopard-spot reaction fronts associated with organic carbon — a '
          'potential biosignature that needs sample return to resolve. A crew '
          'would collect complementary field observations.',
      classification: SourceClass.interpretation,
    ),
    MissionCheckpoint(
      code: 'SH',
      targetId: 'oeb',
      title: 'SH · Safety / Return Point',
      role: 'Return-route planning and staging',
      summary:
          'Octavia E. Butler Landing — Perseverance touchdown and MOXIE site. '
          'Used here as a simulated safety / staging mark on known flat crater-'
          'floor basalt for return-route planning toward Habitat H0.',
      classification: SourceClass.simulation,
    ),
  ];

  static MissionCheckpoint? forTarget(String? id) {
    if (id == null) return null;
    for (final c in all) {
      if (c.targetId == id) return c;
    }
    return null;
  }

  static MissionCheckpoint? byCode(String code) {
    final n = code.toUpperCase();
    for (final c in all) {
      if (c.code == n) return c;
    }
    return null;
  }
}
