import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'src/app.dart';
import 'src/state/app_state.dart';
import 'src/state/launch_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // Bundled assets either load or they do not: no automatic retries.
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        launchOptionsProvider.overrideWithValue(LaunchOptions.fromPage()),
      ],
      child: const VivitedApp(),
    ),
  );
}
