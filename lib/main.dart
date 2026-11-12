import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap/app_dependencies.dart';
import 'app/bootstrap/bootstrap.dart';
import 'app/hyner_app.dart' as business;
import 'core/notifications/local_notification_service.dart';
import 'core/performance/performance_recorder.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'features/pricing/application/open_workspace.dart';
import 'features/pricing/application/workspace.dart';
import 'features/pricing/presentation/pricing_widgets.dart';
import 'features/pricing/presentation/quickprice_screen.dart';

void main() {
  final startup = PerformanceRecorder.enabled ? (Stopwatch()..start()) : null;
  WidgetsFlutterBinding.ensureInitialized();
  PerformanceRecorder.initialize(startup);
  LocalNotificationService.instance.initialize();
  runApp(const HynerLauncher());
}

/// Paint immediately, with retry on startup failure instead of a frozen splash.
class HynerLauncher extends StatefulWidget {
  const HynerLauncher({super.key, this.dependencies});
  final Future<AppDependencies>? dependencies;
  @override
  State<HynerLauncher> createState() => _HynerLauncherState();
}

class _HynerLauncherState extends State<HynerLauncher> {
  late Future<AppDependencies> dependencies =
      widget.dependencies ?? bootstrap();
  @override
  Widget build(BuildContext context) => FutureBuilder<AppDependencies>(
    future: dependencies,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        PerformanceRecorder.mark(PerformanceMilestone.bootstrapReady);
        return ProviderScope(
          overrides: [dependenciesProvider.overrideWithValue(snapshot.data!)],
          child: const business.HynerApp(),
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: hynerTheme(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Hyner could not open its saved settings. Your data has not been reset.',
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () =>
                                setState(() => dependencies = bootstrap()),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(
                        semanticsLabel: 'Opening Hyner',
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class HynerApp extends StatefulWidget {
  const HynerApp({super.key, this.firebaseSetup, this.workspace});
  final Future<FirebaseSetupStatus>? firebaseSetup;
  final Future<QuickPriceWorkspace>? workspace;
  @override
  State<HynerApp> createState() => _HynerAppState();
}

class _HynerAppState extends State<HynerApp> {
  late Future<QuickPriceWorkspace> workspace =
      widget.workspace ?? openQuickPriceWorkspace();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hyner QuickPrice',
    debugShowCheckedModeBanner: false,
    theme: hynerTheme(Brightness.light),
    darkTheme: hynerTheme(Brightness.dark),
    home: FutureBuilder<QuickPriceWorkspace>(
      future: workspace,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return QuickPriceScreen(
            workspace: snapshot.data!,
            firebaseSetup: widget.firebaseSetup,
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Hyner')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Your saved pricing could not be opened. Your data has not been reset.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(
                              () => workspace = openQuickPriceWorkspace(),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        );
      },
    ),
  );
}
