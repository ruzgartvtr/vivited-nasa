import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/demo_guide.dart';
import '../../theme/vivited_theme.dart';
import 'primitives.dart';

/// Floating guided-demonstration bar for jury walkthroughs.
class DemoOverlay extends ConsumerWidget {
  const DemoOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    if (!demo.active) return const SizedBox.shrink();
    final step = demo.step;
    final ctl = ref.read(demoProvider.notifier);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: VColors.basalt.withValues(alpha: 0.97),
          border: Border.all(color: VColors.oxide),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'DEMO ${step.index} / ${DemoGuide.steps.length}',
                  style: VType.label(color: VColors.oxide, size: 9),
                ),
                const Spacer(),
                Tooltip(
                  message: 'End demonstration',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: ctl.stop,
                      child: const Icon(Icons.close, size: 16, color: VColors.dust),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(step.title, style: VType.body(15, weight: 600)),
            const SizedBox(height: 6),
            Text(
              step.narration,
              style: VType.body(12.5, color: VColors.dust, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                VButton(
                  label: 'Back',
                  dense: true,
                  onPressed: demo.isFirst ? null : ctl.previous,
                ),
                const SizedBox(width: 8),
                VButton(
                  label: demo.isLast ? 'Finish' : 'Next',
                  dense: true,
                  primary: true,
                  onPressed: ctl.next,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
