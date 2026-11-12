import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/hyner_mark.dart';
import '../../../core/widgets/page_content.dart';
import '../../auth/presentation/session_controller.dart';
import '../../auth/domain/auth_repository.dart';
import '../../../app/bootstrap/app_dependencies.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(sessionProvider.select((state) => state.failure));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  minHeight: (constraints.maxHeight - 56).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                // Minimum height plus spaceBetween anchors the footer without
                // an IntrinsicHeight pre-layout pass or flex in a scroll view.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HynerMark(size: 36),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Hyner',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'Prices, stock and bills.',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Calculate an item, build a bill and keep customer records together.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (failure != null) ...[
                          InlineNotice(failure.displayMessage, isError: true),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (ref.read(dependenciesProvider).auth
                            is DeviceAccess) ...[
                          FilledButton.icon(
                            key: const Key('use-device'),
                            onPressed:
                                ref.watch(sessionProvider).status ==
                                    SessionStatus.signingIn
                                ? null
                                : () => ref
                                      .read(sessionProvider.notifier)
                                      .useDevice(),
                            icon: const Icon(Icons.phone_android_outlined),
                            label: const Text('Use on this device'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (ref.read(dependenciesProvider).auth is DeviceAccess)
                          OutlinedButton(
                            onPressed: () => context.push<void>('/sign-in'),
                            child: const Text('Sign in or create account'),
                          )
                        else
                          FilledButton(
                            onPressed: () => context.push<void>('/sign-in'),
                            child: const Text('Sign in or create account'),
                          ),
                        const SizedBox(height: 18),
                        Text(
                          'Products, bills and rates stay on this device.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push<void>('/quickprice'),
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Open QuickPrice'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
