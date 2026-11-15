import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vivited/src/app.dart';
import 'package:vivited/src/data/data_repository.dart';
import 'package:vivited/src/state/app_state.dart';

/// End-to-end smoke test of the real application on the real bundled data:
/// load → orbit → map → plan → rehearse → sources, at three window sizes.
void main() {
  late AppData data;

  Future<void> settle(WidgetTester tester, [int ms = 1200]) async {
    // Route planning runs on real timers; let them fire, then pump frames.
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  void noErrors(WidgetTester tester) {
    final e = tester.takeException();
    if (e is FlutterError) {
      fail(e.diagnostics.map((d) => d.toStringDeep()).take(12).join());
    }
    expect(e, isNull);
  }

  Future<ProviderContainer> boot(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        // A fresh pathfinder per test: searches are serialised on a lock
        // that must not outlive a test's fake-async zone.
        appDataProvider.overrideWith(
          (ref) async => AppData(
            terrain: data.terrain,
            terrainMeta: data.terrainMeta,
            traverse: data.traverse,
            targets: data.targets,
            climate: data.climate,
            relief: data.relief,
            ortho: data.ortho,
            themisImage: data.themisImage,
            themis: data.themis,
            globe: data.globe,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VivitedApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    return container;
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Lay text out in the real typefaces rather than the test placeholder.
    for (final (family, files) in [
      ('InstrumentSerif', ['InstrumentSerif-Regular.ttf', 'InstrumentSerif-Italic.ttf']),
      ('SchibstedGrotesk', ['SchibstedGrotesk.ttf']),
      ('IBMPlexMono', ['IBMPlexMono-Regular.ttf', 'IBMPlexMono-Medium.ttf']),
    ]) {
      final loader = FontLoader(family);
      for (final f in files) {
        final bytes = File('assets/fonts/$f').readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
    data = await DataRepository().load();
  });

  test('bundled datasets load and decode', () {
    expect(data.targets.length, 15);
    expect(data.terrain.rows, 1512);
    expect(data.ortho.width, greaterThan(1000));
  });

  for (final (name, size) in [
    ('desktop', const Size(1440, 900)),
    ('tablet', const Size(900, 1100)),
    ('phone', const Size(390, 844)),
  ]) {
    testWidgets('full flow on $name (${size.width.round()}×${size.height.round()})',
        (tester) async {
      final container = await boot(tester, size);
      noErrors(tester);
      expect(find.text('ENTER THE SITE'), findsOneWidget);
      expect(container.read(uiProvider).view, StageView.orbit);

      await tester.tap(find.text('ENTER THE SITE'), kind: PointerDeviceKind.mouse);
      await settle(tester);
      noErrors(tester);
      expect(container.read(uiProvider).view, StageView.map);

      // Plan: the default preset is routed over the real terrain.
      container.read(uiProvider.notifier).setWorkspace(Workspace.plan);
      await settle(tester, 2500);
      noErrors(tester);
      final planner = container.read(plannerProvider);
      printOnFailure('planner: computing=${planner.computing} error=${planner.error} stops=${planner.stops.length}');
      expect(planner.error, isNull);
      expect(planner.plan, isNotNull);
      expect(planner.plan!.routeFound, isTrue);
      expect(find.text('Plan the walk'), findsOneWidget);

      // Every analysis layer renders.
      for (final o in MapOverlay.values) {
        container.read(uiProvider.notifier).toggleOverlay(o);
      }
      container.read(uiProvider.notifier).setBasemap(Basemap.relief);
      await settle(tester, 2500);
      noErrors(tester);

      // Terrain view.
      container.read(uiProvider.notifier).setView(StageView.terrain);
      await settle(tester, 600);
      noErrors(tester);
      container.read(uiProvider.notifier).setView(StageView.map);

      // Rehearse: the clock advances the crew along the route.
      container.read(uiProvider.notifier).setWorkspace(Workspace.simulate);
      await settle(tester, 300);
      noErrors(tester);
      final sim = container.read(simProvider.notifier);
      sim.seek(planner.plan!.durationS / 2);
      await tester.pump(const Duration(milliseconds: 100));
      noErrors(tester);
      final st = container.read(evaStateProvider)!;
      expect(st.distM, greaterThan(0));
      expect(st.distM, lessThan(planner.plan!.distanceM));

      // A plan the checks refuse.
      container.read(plannerProvider.notifier).loadPreset(
            EvaPreset.byId('rim')!,
          );
      await settle(tester, 4000);
      noErrors(tester);
      expect(container.read(plannerProvider).computing, isFalse);

      container.read(uiProvider.notifier).setWorkspace(Workspace.sources);
      await settle(tester, 300);
      noErrors(tester);
      expect(find.text('Sources and limits'), findsOneWidget);

      // Unmount cleanly (cancels timers).
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
