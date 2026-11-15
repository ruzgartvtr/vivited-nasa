import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../science/provenance.dart';
import '../../state/app_state.dart';
import '../../theme/vivited_theme.dart';
import '../widgets/primitives.dart';
import 'atlas_panel.dart';

class _Dataset {
  const _Dataset(this.mission, this.product, this.use, this.url, this.note);
  final String mission;
  final String product;
  final String use;
  final String url;
  final String note;
}

const _datasets = [
  _Dataset(
    'Mars Reconnaissance Orbiter · CTX',
    'Mars 2020 Terrain Relative Navigation CTX DTM mosaic, 20 m',
    'Elevation, slope, hazard classes, routing, shadows, 3D terrain',
    'https://asc-pds-services.s3.us-west-2.amazonaws.com/mosaic/mars2020_trn/CTX/JEZ_ctx_B_soc_008_DTM_MOLAtopography_DeltaGeoid_20m_Eqc_latTs0_lon0.lbl',
    'USGS Astrogeology (Fergason et al., 2020). Bundled at native 20 m '
        'posting, quantised to 5 cm.',
  ),
  _Dataset(
    'Mars Reconnaissance Orbiter · CTX',
    'Mars 2020 TRN CTX orthomosaic, 6 m',
    'Base imagery, 3D terrain drape',
    'https://asc-pds-services.s3.us-west-2.amazonaws.com/mosaic/mars2020_trn/CTX/JEZ_ctx_B_soc_008_orthoMosaic_6m_Eqc_latTs0_lon0.lbl',
    'Resampled to 12 m and JPEG-compressed for the browser.',
  ),
  _Dataset(
    'Mars Odyssey · THEMIS',
    'Night-time infrared global mosaic, 100 m',
    'Night infrared layer: relative thermal inertia',
    'https://trek.nasa.gov/mars/',
    'From NASA Mars Trek tiles. Values are normalised mosaic brightness, '
        'not kelvin — read it as warmer or cooler at night, nothing more.',
  ),
  _Dataset(
    'Mars 2020 Perseverance',
    'Rover traverse and waypoints',
    'Rover track, station positions, DTM validation',
    'https://mars.nasa.gov/mmgis-maps/M20/Layers/json/M20_waypoints.json',
    'NASA/JPL "Where is Perseverance" localisation data.',
  ),
  _Dataset(
    'Mars 2020 · MEDA',
    'Calibrated pressure, air and ground temperature, wind (PDS4)',
    'Diurnal weather curves and EVA conditions',
    'https://pds-atmospheres.nmsu.edu/PDS/data/PDS4/Mars2020/mars2020_meda/',
    'Rodriguez-Manfredi et al. (2021). 23 sols spanning one Mars year, '
        'averaged per local hour. No gap filling: the wind sensor was '
        'damaged in early 2022, so later sols show "no data".',
  ),
  _Dataset(
    'Mars Science Laboratory · RAD',
    'Surface dose-equivalent rate, Gale crater',
    'EVA radiation dose',
    'https://doi.org/10.1126/science.1244797',
    'Hassler et al. (2014): 0.64 ± 0.12 mSv/day galactic cosmic rays, '
        '2012–13. Measured at Gale, not Jezero, and varies with the solar '
        'cycle; solar particle events are not modelled.',
  ),
  _Dataset(
    'Mars Global Surveyor · MOLA',
    'MEGDR gridded topography, 16 px/degree',
    'Globe elevations, independent check of the CTX DTM',
    'https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg016/',
    'Smith et al. (2001).',
  ),
  _Dataset(
    'Viking Orbiter',
    'MDIM 2.1 colourised global mosaic',
    'Globe and regional context tiles',
    'https://trek.nasa.gov/mars/',
    'Regional tiles stream from NASA Mars Trek and need a connection; '
        'everything else is bundled and works offline.',
  ),
];

const _methods = [
  (
    'Mars time and Sun position',
    'Allison & McEwen (2000), Planet. Space Sci. 48, 215 — the NASA GISS '
        'Mars24 algorithm. Verified in the test suite against the published '
        'worked example.',
  ),
  (
    'Walking speed on slopes',
    'Marquez (2008), MIT PhD thesis: piecewise speed-versus-slope fitted '
        'to Apollo lunar traverses, as implemented in the NASA-funded '
        'SEXTANT/pextant planner. Scaled by an editable pace factor.',
  ),
  (
    'Metabolic cost',
    'Santee et al. (2001), Aviat. Space Environ. Med. 72, 562: suited '
        'locomotion on level, uphill and downhill ground at reduced gravity. '
        'Oxygen from 20.1 kJ per litre O₂.',
  ),
  (
    'Routes',
    'A* and Dijkstra search on the 20 m grid, eight-connected, written in '
        'Dart. Edge cost is modelled time, energy, or slope-penalised time. '
        'Cells steeper than the slope limit are closed.',
  ),
  (
    'Walk-back time',
    'Dijkstra field of fastest return time to the airlock from every cell '
        'within 2.5 hours, after the walk-back constraint used for Apollo '
        'J-mission traverses.',
  ),
  (
    'Solar exposure and shadows',
    'Shadows are ray-marched across the DTM towards the Mars24 Sun '
        'position. Solar exposure is cosine-weighted hours of direct sun on '
        'each cell\'s own slope; it ignores shadows cast by distant terrain '
        'and atmospheric dust.',
  ),
];

const _limits = [
  'A 20 m terrain model cannot see boulders, sand ripples or ledges smaller '
      'than about 60 m. A route marked nominal is a candidate for detailed '
      'survey, not a cleared path.',
  'The walking and metabolic models come from Apollo lunar data and '
      'treadmill studies. No one has walked on Mars; expect large errors.',
  'Suit mass, oxygen load, reserve and pace are planning assumptions the '
      'user can change. They are not specifications of any flight suit.',
  'Science-value ratings of stations are Vivited\'s editorial judgement '
      'based on the cited literature, not a NASA ranking.',
  'Weather is a climatology of past sols. It is not a forecast, and dust '
      'storms are not represented.',
];

class SourcesPanel extends ConsumerWidget {
  const SourcesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataProvider);
    final v = (data.terrainMeta['validation'] as Map?) ?? const {};
    final rover = (v['ctx_minus_rover_elev_m'] as Map?) ?? const {};
    final mola = (v['ctx_minus_mola_m'] as Map?) ?? const {};
    String n(Object? x, [int d = 1]) =>
        x is num ? x.toStringAsFixed(d) : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelHeader(
          kicker: 'Life support + sources',
          title: 'Sources and limits',
          subtitle: 'Every number in Vivited is either a NASA measurement or '
              'computed from one by a published method. This page says which, '
              'and where each stops being trustworthy.',
        ),
        const SectionHeader('00', 'How to read the labels'),
        for (final k in SourceClass.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProvenanceChip(k),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(k.caption, style: VType.body(12, color: VColors.dust)),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            'Vivited is an educational simulation for the NASA Space Apps '
            'Challenge. It is not a NASA-certified operational astronaut '
            'safety system.',
            style: VType.body(12, color: VColors.sulfur),
          ),
        ),
        const SectionHeader('01', 'Measurements'),
        for (final d in _datasets) _DatasetRow(d),
        const SectionHeader('02', 'Checks on the terrain model'),
        KeyValue(
          'Against rover elevations',
          '${n(rover['rms'])} m RMS',
          note: 'n=${rover['n'] ?? '—'}',
        ),
        KeyValue('  mean difference', '${n(rover['mean'])} m'),
        KeyValue('  95 % within', '${n(rover['p95_abs'])} m'),
        KeyValue(
          'Against MOLA 16 px/°',
          '${n(mola['rms'])} m RMS',
          note: 'n=${mola['n'] ?? '—'}',
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'The rover comparison confirms georeferencing of the bundled '
            'grid. The MOLA figure mostly reflects MOLA\'s 3.7 km cells '
            'averaging over crater-wall relief.',
            style: VType.body(11.5, color: VColors.ash),
          ),
        ),
        const SectionHeader('03', 'Methods'),
        for (final m in _methods)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.$1, style: VType.body(13, weight: 600)),
                const SizedBox(height: 2),
                Text(m.$2, style: VType.body(12, color: VColors.dust)),
              ],
            ),
          ),
        const SectionHeader('04', 'What this cannot tell you'),
        for (var i = 0; i < _limits.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}', style: VType.data(11, color: VColors.sulfur)),
                ),
                Expanded(
                  child: Text(_limits[i], style: VType.body(12.5, color: VColors.dust)),
                ),
              ],
            ),
          ),
        const SectionHeader('05', 'Station literature'),
        for (final r in {for (final t in data.targets) ...t.references})
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(r, style: VType.body(11.5, color: VColors.dust)),
          ),
        const SectionHeader('06', 'Colophon'),
        Text(
          'Vivited — Martian Exploration Intelligence System. Built in '
          'Flutter and Dart for the NASA Space Apps Challenge 2026, '
          '"Interplanetary Survival Guide: Martian Map". Set in Instrument '
          'Serif, Schibsted Grotesk and IBM Plex Mono (SIL Open Font '
          'License). NASA and USGS data are in the public domain; Vivited is '
          'not endorsed by NASA.',
          style: VType.body(12, color: VColors.dust),
        ),
      ],
    );
  }
}

class _DatasetRow extends StatelessWidget {
  const _DatasetRow(this.d);
  final _Dataset d;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.mission.toUpperCase(),
                    style: VType.label(color: VColors.ice, size: 9),
                  ),
                ),
                const ProvenanceChip(SourceClass.nasaData, compact: true),
              ],
            ),
            const SizedBox(height: 3),
            Text(d.product, style: VType.body(13.5, weight: 500)),
            const SizedBox(height: 2),
            Text('Used for: ${d.use}', style: VType.body(12, color: VColors.dust)),
            Text(d.note, style: VType.body(12, color: VColors.ash)),
            const SizedBox(height: 3),
            Tooltip(
              message: 'Copy link',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: d.url));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text('Link copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    d.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VType.data(10, color: VColors.oxide),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
