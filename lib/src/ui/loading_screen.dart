import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/data_repository.dart';
import '../state/app_state.dart';
import '../theme/vivited_theme.dart';
import 'widgets/glyphs.dart';
import 'widgets/primitives.dart';

/// Start-up screen: names each NASA dataset as it is decoded.
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    return Scaffold(
      backgroundColor: VColors.ink,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ValueListenableBuilder<LoadProgress>(
              valueListenable: repo.progress,
              builder: (context, p, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: p.fraction),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) =>
                        VivitedMark(size: 56, progress: v.clamp(0.04, 1)),
                  ),
                  const SizedBox(height: 26),
                  Text('Vivited', style: VType.display(64)),
                  const SizedBox(height: 4),
                  Text(
                    'MARTIAN EXPLORATION INTELLIGENCE SYSTEM',
                    style: VType.label(color: VColors.dust),
                  ),
                  const SizedBox(height: 34),
                  for (var i = 0; i < LoadStage.stages.length; i++)
                    _StageRow(
                      stage: LoadStage.stages[i],
                      done: i < p.completed,
                      active: i == p.completed,
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'Reading measured data. Nothing here is simulated terrain.',
                    style: VType.body(12, color: VColors.ash),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.done, required this.active});
  final LoadStage stage;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? VColors.bone
        : active
            ? VColors.oxide
            : VColors.ash;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: done ? VColors.bone : Colors.transparent,
                border: Border.all(color: color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.mission.toUpperCase(), style: VType.label(color: color, size: 9)),
                Text(
                  stage.product,
                  style: VType.body(13, color: done || active ? VColors.bone : VColors.ash),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when a bundled dataset fails to load or decode.
class LoadErrorScreen extends ConsumerWidget {
  const LoadErrorScreen({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    return Scaffold(
      backgroundColor: VColors.ink,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('VIVITED · START-UP HALTED', style: VType.label(color: VColors.alarm)),
                const SizedBox(height: 12),
                Text('A dataset did not load', style: VType.display(40)),
                const SizedBox(height: 12),
                Text(
                  e is DataLoadException
                      ? '${e.stage.mission} — ${e.stage.product} could not be '
                          'read. Vivited will not substitute placeholder data, '
                          'so the app stops here.'
                      : 'Vivited could not start.',
                  style: VType.body(14, color: VColors.dust),
                ),
                const SizedBox(height: 12),
                Text(
                  e is DataLoadException ? '${e.cause}' : '$e',
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: VType.data(11, color: VColors.ash),
                ),
                const SizedBox(height: 22),
                VButton(
                  label: 'Try again',
                  icon: Icons.refresh,
                  primary: true,
                  onPressed: () => ref.invalidate(appDataProvider),
                ),
                const SizedBox(height: 14),
                Text(
                  'If this persists, reload the page; a partial download of '
                  'the app bundle is the usual cause.',
                  style: VType.body(12, color: VColors.ash),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
