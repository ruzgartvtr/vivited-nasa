import 'package:material_ui/material_ui.dart';

import '../theme/vivited_theme.dart';

/// Honest source classification for every number and mark shown in Vivited.
///
/// Measurements from verified NASA products are [nasaData]. Derived conclusions
/// and planning models are [interpretation]. Fictional mission infrastructure
/// and editable educational assumptions are [simulation].
enum SourceClass {
  nasaData(
    'NASA DATA',
    'Measurement, imagery, or observation from a verified NASA dataset.',
    VColors.ice,
  ),
  interpretation(
    'SCIENTIFIC INTERPRETATION',
    'Conclusion or model derived from available observations — not a NASA product.',
    VColors.sulfur,
  ),
  simulation(
    'SIMULATION',
    'Fictional mission infrastructure, editable assumption, or hypothetical scenario.',
    VColors.oxide,
  );

  const SourceClass(this.label, this.caption, this.color);
  final String label;
  final String caption;
  final Color color;
}
