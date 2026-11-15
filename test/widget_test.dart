import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vivited/src/app.dart';
import 'package:vivited/src/data/data_repository.dart';
import 'package:vivited/src/mission/mission_plan.dart';
import 'package:vivited/src/state/app_state.dart';
import 'package:vivited/src/state/launch_options.dart';
import 'package:vivited/src/ui/widgets/primitives.dart';

void main() {
  testWidgets('loading screen carries the Vivited brand and dataset list',
      (tester) async {
    final never = Completer<AppData>();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [appDataProvider.overrideWith((ref) => never.future)],
        child: const VivitedApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Vivited'), findsOneWidget);
    expect(find.text('MARTIAN EXPLORATION INTELLIGENCE SYSTEM'), findsOneWidget);
    for (final s in LoadStage.stages) {
      expect(find.text(s.product), findsOneWidget);
    }
    expect(VivitedApp.title, 'Vivited — Martian Exploration Intelligence System');
  });

  testWidgets('a failed dataset shows the error screen with a retry',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appDataProvider.overrideWith((ref) async {
            attempts++;
            throw DataLoadException(LoadStage.stages[0], 'truncated file');
          }),
        ],
        child: const VivitedApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A dataset did not load'), findsOneWidget);
    expect(find.textContaining('truncated file'), findsOneWidget);
    expect(attempts, 1);
    await tester.tap(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('A dataset did not load'), findsOneWidget);
  });

  testWidgets('go / no-go row names its status in words, not colour alone',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CheckRow(PlanCheck('Oxygen', 'Short by 40 g.', CheckStatus.fail)),
        ),
      ),
    );
    expect(find.text('NO-GO'), findsOneWidget);
    expect(find.text('Short by 40 g.'), findsOneWidget);
  });

  test('launch options parse the page address and ignore unknown names', () {
    final o = LaunchOptions.fromUri(Uri.parse(
      'http://localhost/?workspace=rehearse&view=terrain&preset=seitah'
      '&layers=hazard,walkBack,nonsense&base=relief&ls=250&start=99',
    ));
    expect(o.workspace, Workspace.simulate);
    expect(o.view, StageView.terrain);
    expect(o.presetId, 'route-b'); // seitah alias resolves to Route B
    expect(o.overlays, {MapOverlay.hazard, MapOverlay.walkBack});
    expect(o.basemap, Basemap.relief);
    expect(o.ls, 250);
    expect(o.startLtst, isNull, reason: 'out of range');

    final junk = LaunchOptions.fromUri(Uri.parse('http://localhost/?view=moon&preset=x'));
    expect(junk.isEmpty, isTrue);
    expect(LaunchOptions.fromUri(Uri.parse('http://localhost/')).isEmpty, isTrue);
  });

  test('formatters', () {
    expect(formatMet(3725), '1:02:05');
    expect(formatDuration(42 * 60), '42 min');
    expect(formatDuration(3900), '1 h 05 m');
    expect(formatDistance(950), '950 m');
    expect(formatDistance(2345), '2.35 km');
  });
}
