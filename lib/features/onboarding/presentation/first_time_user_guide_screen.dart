import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/storage/business_database_provider.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/widgets/ui_primitives.dart';
import '../data/onboarding_preferences.dart';

final onboardingPreferencesProvider = Provider<OnboardingPreferences>(
  (ref) => OnboardingPreferences(),
);

/// Existing workspaces are not classified as new just because this guide is new.
final firstTimeGuideProvider = FutureProvider.family<bool, String>((
  ref,
  uid,
) async {
  final preferences = ref.read(onboardingPreferencesProvider);
  if (await preferences.isComplete(uid)) return false;
  final db = await ref.read(businessDatabaseProvider).databaseFor(uid);
  for (final table in const [
    'products',
    'sales',
    'customers',
    'settings',
    'purchases',
    'operating_expenses',
    'quotations',
  ]) {
    if ((await db.rawQuery('SELECT 1 FROM "$table" LIMIT 1')).isNotEmpty) {
      return false;
    }
  }
  return true;
});

class FirstTimeUserGuidePrompt extends ConsumerWidget {
  const FirstTimeUserGuidePrompt({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(firstTimeGuideProvider(uid))
      .maybeWhen(
        data: (show) => show
            ? HynerSurface(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Hyner',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Set up your shop and start managing your business.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton(
                            onPressed: () =>
                                context.push<void>('/getting-started'),
                            child: const Text('Get started'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(onboardingPreferencesProvider)
                                  .setComplete(uid);
                              ref.invalidate(firstTimeGuideProvider(uid));
                            },
                            child: const Text('Explore on my own'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
        orElse: () => const SizedBox.shrink(),
      );
}

class FirstTimeUserGuideScreen extends ConsumerWidget {
  const FirstTimeUserGuideScreen({super.key, required this.uid});
  final String uid;

  static const _steps =
      <({String id, String title, String detail, String route})>[
        (
          id: 'business',
          title: 'Shop details',
          detail: 'Add your shop details for invoices.',
          route: '/bill-settings',
        ),
        (
          id: 'product',
          title: 'First product',
          detail: 'Add a stocked product.',
          route: '/inventory/add',
        ),
        (
          id: 'bill',
          title: 'First bill',
          detail: 'Create a bill when you are ready.',
          route: '/sales',
        ),
        (
          id: 'backup',
          title: 'Keep a backup',
          detail: 'Business records stay on this device. Google sign-in does not sync them.',
          route: '/settings',
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Get started')),
    body: PageContent(
      children: [
        Text(
          'Welcome to Hyner',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Set up the basics. You can skip any step and come back later.',
        ),
        const SizedBox(height: 20),
        for (final step in _steps) ...[
          _GuideStep(uid: uid, step: step),
          const Divider(height: 1),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await ref.read(onboardingPreferencesProvider).setComplete(uid);
            ref.invalidate(firstTimeGuideProvider(uid));
            if (context.mounted) context.pop();
          },
          child: const Text('Finish setup'),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(onboardingPreferencesProvider).setComplete(uid);
            ref.invalidate(firstTimeGuideProvider(uid));
            if (context.mounted) context.pop();
          },
          child: const Text('Skip for now'),
        ),
      ],
    ),
  );
}

class _GuideStep extends ConsumerStatefulWidget {
  const _GuideStep({required this.uid, required this.step});
  final String uid;
  final ({String id, String title, String detail, String route}) step;

  @override
  ConsumerState<_GuideStep> createState() => _GuideStepState();
}

class _GuideStepState extends ConsumerState<_GuideStep> {
  late Future<bool> _loaded;
  bool? _complete;

  @override
  void initState() {
    super.initState();
    _loaded = ref
        .read(onboardingPreferencesProvider)
        .isStepComplete(widget.uid, widget.step.id);
  }

  Future<void> _setComplete(bool value) async {
    setState(() => _complete = value);
    try {
      await ref
          .read(onboardingPreferencesProvider)
          .setStepComplete(widget.uid, widget.step.id, value);
    } catch (_) {
      if (mounted) setState(() => _complete = null);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _loaded,
    builder: (context, snapshot) {
      final complete = _complete ?? snapshot.data ?? false;
      return Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(widget.step.title),
            subtitle: Text(widget.step.detail),
            onTap: () =>
                openWorkspacePage(GoRouter.of(context), widget.step.route),
            trailing: Checkbox(
              value: complete,
              onChanged: (value) => _setComplete(value ?? false),
            ),
          ),
          if (widget.step.id == 'product' || widget.step.id == 'bill')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    openWorkspacePage(GoRouter.of(context), '/quickprice'),
                icon: const Icon(Icons.calculate_outlined),
                label: Text(
                  widget.step.id == 'product'
                      ? 'Set up pricing'
                      : 'Calculate a price',
                ),
              ),
            ),
        ],
      );
    },
  );
}
