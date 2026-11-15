import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'state/app_state.dart';
import 'theme/vivited_theme.dart';
import 'ui/loading_screen.dart';
import 'ui/shell.dart';

class VivitedApp extends ConsumerWidget {
  const VivitedApp({super.key});

  static const title = 'Vivited — Martian Exploration Intelligence System';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: buildVivitedTheme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: data.when(
          skipLoadingOnRefresh: false,
          data: (_) => const AppShell(key: ValueKey('shell')),
          loading: () => const LoadingScreen(key: ValueKey('loading')),
          error: (e, _) => LoadErrorScreen(key: const ValueKey('error'), error: e),
        ),
      ),
    );
  }
}
