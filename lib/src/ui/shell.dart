import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../science/mars_time.dart';
import '../state/app_state.dart';
import '../state/demo_guide.dart';
import '../theme/vivited_theme.dart';
import 'panels/atlas_panel.dart';
import 'panels/plan_panel.dart';
import 'panels/simulate_panel.dart';
import 'panels/sources_panel.dart';
import 'stage/stage.dart';
import 'widgets/demo_overlay.dart';
import 'widgets/glyphs.dart';
import 'widgets/primitives.dart';

const _icons = {
  Workspace.atlas: Icons.map_outlined,
  Workspace.plan: Icons.route_outlined,
  Workspace.simulate: Icons.play_circle_outline,
  Workspace.sources: Icons.menu_book_outlined,
};

Widget _panelFor(Workspace w) => switch (w) {
      Workspace.atlas => const AtlasPanel(),
      Workspace.plan => const PlanPanel(),
      Workspace.simulate => const SimulatePanel(),
      Workspace.sources => const SourcesPanel(),
    };

/// Responsive application frame.
///
/// * ≥ 1100 px: rail, 420 px panel, stage.
/// * 720–1100 px: rail, 340 px panel, stage.
/// * < 720 px: stage on top, panel sheet below, bottom navigation.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(uiProvider.select((u) => u.workspace));
    return Scaffold(
      backgroundColor: VColors.ink,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 720) return _PhoneLayout(workspace: workspace);
            final panelWidth = c.maxWidth >= 1100 ? 420.0 : 340.0;
            return Stack(
              children: [
                Row(
                  children: [
                    _Rail(workspace: workspace),
                    const Hairline(vertical: true),
                    SizedBox(
                      width: panelWidth,
                      child: ColoredBox(
                        color: VColors.basalt,
                        child: _PanelScroll(workspace: workspace),
                      ),
                    ),
                    const Hairline(vertical: true),
                    const Expanded(child: Stage()),
                  ],
                ),
                const Positioned(
                  right: 12,
                  bottom: 12,
                  width: 360,
                  child: DemoOverlay(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PanelScroll extends StatelessWidget {
  const _PanelScroll({required this.workspace, this.controller, this.top = 26});
  final Workspace workspace;
  final ScrollController? controller;
  final double top;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        child: Scrollbar(
          key: ValueKey(workspace),
          controller: controller,
          child: SingleChildScrollView(
            controller: controller,
            primary: controller == null,
            padding: EdgeInsets.fromLTRB(24, top, 24, 40),
            child: _panelFor(workspace),
          ),
        ),
      );
}

class _Rail extends ConsumerWidget {
  const _Rail({required this.workspace});
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = ref.watch(plannerProvider.select((p) => p.params.ls));
    return Container(
      width: 76,
      color: VColors.ink,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Tooltip(
            message: 'Vivited — Martian Exploration Intelligence System',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => ref.read(uiProvider.notifier).setView(StageView.orbit),
                child: const VivitedMark(size: 30),
              ),
            ),
          ),
          const SizedBox(height: 22),
          for (final w in Workspace.values)
            _RailItem(
              workspace: w,
              active: w == workspace,
              onTap: () => ref.read(uiProvider.notifier).setWorkspace(w),
            ),
          const Spacer(),
          Tooltip(
            message: 'Start the ~3-minute guided demonstration',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => ref.read(demoProvider.notifier).start(),
                child: Column(
                  children: [
                    Icon(
                      Icons.play_lesson_outlined,
                      size: 18,
                      color: ref.watch(demoProvider).active
                          ? VColors.oxide
                          : VColors.ash,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DEMO',
                      style: VType.label(
                        size: 8,
                        color: ref.watch(demoProvider).active
                            ? VColors.oxide
                            : VColors.ash,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'JEZERO · LS ${ls.round()}° · ${MarsTime.seasonName(ls).toUpperCase()}',
              style: VType.label(size: 8.5, color: VColors.ash),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({required this.workspace, required this.active, required this.onTap});
  final Workspace workspace;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    final color = widget.active
        ? VColors.bone
        : _hover
            ? VColors.dust
            : VColors.ash;
    return Tooltip(
      message: w.hint,
      child: Semantics(
        button: true,
        selected: widget.active,
        label: w.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: SizedBox(
              height: 66,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 2,
                    height: widget.active ? 34 : 0,
                    color: VColors.oxide,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icons[w], size: 19, color: color),
                        const SizedBox(height: 6),
                        Text(w.label.toUpperCase(), style: VType.label(size: 8, color: color)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneLayout extends ConsumerStatefulWidget {
  const _PhoneLayout({required this.workspace});
  final Workspace workspace;

  @override
  ConsumerState<_PhoneLayout> createState() => _PhoneLayoutState();
}

class _PhoneLayoutState extends ConsumerState<_PhoneLayout> {
  final _sheet = DraggableScrollableController();
  static const _min = 0.12, _mid = 0.46, _max = 0.92;

  void _snap(double size) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      size,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Placing points needs the map: get the sheet out of the way.
    ref.listen(uiProvider.select((u) => u.pickMode), (_, next) {
      if (next != PickMode.inspect) _snap(_min);
    });
    // The globe gets the whole screen; arriving at the site opens the sheet.
    ref.listen(uiProvider.select((u) => u.view), (prev, next) {
      if (next == StageView.orbit) {
        _snap(_min);
      } else if (prev == StageView.orbit) {
        _snap(_mid);
      }
    });
    final startsInOrbit = ref.read(uiProvider).view == StageView.orbit;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: c.maxHeight * (1 - _min) + 1,
                  child: const Stage(compact: true),
                ),
                const Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: DemoOverlay(),
                ),
                DraggableScrollableSheet(
                  controller: _sheet,
                  initialChildSize: startsInOrbit ? _min : _mid,
                  minChildSize: _min,
                  maxChildSize: _max,
                  snap: true,
                  snapSizes: const [_mid],
                  snapAnimationDuration: const Duration(milliseconds: 220),
                  builder: (context, scroll) => Container(
                    decoration: const BoxDecoration(
                      color: VColors.basalt,
                      border: Border(top: BorderSide(color: VColors.ruleStrong)),
                    ),
                    child: Stack(
                      children: [
                        _PanelScroll(
                          workspace: widget.workspace,
                          controller: scroll,
                          top: 34,
                        ),
                        // Grab handle.
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: 22,
                              color: VColors.basalt,
                              alignment: Alignment.center,
                              child: Container(width: 34, height: 2, color: VColors.ash),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Hairline(),
        Container(
          color: VColors.ink,
          height: 58,
          child: Row(
            children: [
              for (final w in Workspace.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: w == widget.workspace,
                    label: w.label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        ref.read(uiProvider.notifier).setWorkspace(w);
                        if (_sheet.isAttached && _sheet.size < _mid - 0.02) _snap(_mid);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _icons[w],
                            size: 19,
                            color: w == widget.workspace ? VColors.oxide : VColors.ash,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            w.label.toUpperCase(),
                            style: VType.label(
                              size: 8.5,
                              color: w == widget.workspace ? VColors.bone : VColors.ash,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
