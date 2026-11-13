import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap/app_dependencies.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class HynerApp extends ConsumerWidget {
  const HynerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Hyner',
    debugShowCheckedModeBanner: false,
    theme: HynerTheme.build(
      Brightness.light,
      preset: ref.watch(themePresetProvider),
    ),
    darkTheme: HynerTheme.build(
      Brightness.dark,
      preset: ref.watch(themePresetProvider),
    ),
    themeMode: ref.watch(themeControllerProvider),
    themeAnimationDuration:
        (MediaQuery.maybeOf(context)?.disableAnimations ??
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    routerConfig: ref.watch(routerProvider),
  );
}
