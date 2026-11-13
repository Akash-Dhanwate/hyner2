import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/session_controller.dart';
import '../../auth/domain/auth_repository.dart';
import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../sales/presentation/sales_controller.dart';
import '../application/estimate_builder.dart';
import '../application/open_workspace.dart';
import '../application/workspace.dart';
import 'quickprice_screen.dart';

final pricingWorkspaceProvider =
    FutureProvider.family<QuickPriceWorkspace, String?>((ref, uid) async {
      final workspace = await openQuickPriceWorkspace(accountUid: uid);
      if (!ref.mounted) {
        await workspace.close();
        throw StateError('Workspace closed');
      }
      ref.onDispose(() => unawaited(workspace.close()));
      return workspace;
    });

/// Device pricing from earlier APKs stays available. Account pricing uses its
/// own local scope and never grants cloud business membership.
class WorkspaceQuickPriceScreen extends ConsumerWidget {
  const WorkspaceQuickPriceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final uid = profile == null || profile.localOnly ? null : profile.uid;
    final provider = pricingWorkspaceProvider(uid);
    return ref
        .watch(provider)
        .when(
          data: (workspace) => _ScopedPricingNavigator(
            key: ValueKey(uid),
            workspace: workspace,
            onCheckout: (estimate) => _continueToSales(context, ref, estimate),
            onQuotation: (estimate) async {
              await _continueToSales(context, ref, estimate, quotation: true);
            },
            onQuotationHistory: () => context.push<void>('/quotations'),
            onExit: () {
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
              } else {
                router.go(profile == null ? '/welcome' : '/dashboard');
              }
            },
          ),
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('QuickPrice')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('QuickPrice')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your saved rates could not be opened. Your data has not been reset.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(provider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}

Future<String?> _continueToSales(
  BuildContext context,
  WidgetRef ref,
  QuickPriceEstimate estimate, {
  bool quotation = false,
}) async {
  var profile = ref.read(sessionProvider).profile;
  if (profile == null) {
    if (ref.read(dependenciesProvider).auth is! DeviceAccess) {
      throw StateError(
        'Open Home and choose your business workspace before creating a bill.',
      );
    }
    final useDevice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          quotation
              ? 'Create a quotation on this device?'
              : 'Create a bill on this device?',
        ),
        content: const Text(
          'The document will be saved in your local business workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use on this device'),
          ),
        ],
      ),
    );
    if (useDevice != true || !context.mounted) return null;
    if (ref.read(sessionProvider).profile != null) {
      throw StateError('The account changed. Reopen the estimate to continue.');
    }
    final ready = Completer<void>();
    final subscription = ref.listenManual(sessionProvider, (previous, next) {
      if (ready.isCompleted) return;
      if (next.status == SessionStatus.signedIn &&
          next.profile?.localOnly == true) {
        ready.complete();
      }
      if (next.status == SessionStatus.profileError ||
          next.status == SessionStatus.signedOut) {
        ready.completeError(
          StateError(
            next.failure?.message ?? 'The local workspace could not be opened.',
          ),
        );
      }
    });
    try {
      await Future.wait<void>([
        ref.read(sessionProvider.notifier).useDevice(),
        ready.future.timeout(const Duration(seconds: 15)),
      ]);
    } finally {
      subscription.close();
    }
    if (!context.mounted) return null;
    profile = ref.read(sessionProvider).profile;
  }
  if (profile == null) {
    throw StateError('Open your business workspace to create a bill.');
  }
  final uid = profile.uid;
  final workspace = await ref.read(
    pricingWorkspaceProvider(profile.localOnly ? null : uid).future,
  );
  if (!context.mounted || ref.read(inventoryUidProvider) != uid) return null;
  if (workspace.businessId != estimate.businessId) {
    throw StateError('This estimate belongs to a different workspace.');
  }
  // A declarative go('/quickprice') may remove an imperative route without
  // completing its push future. Observe returning/disposal as well so the
  // estimate never remains busy after leaving checkout.
  final router = GoRouter.of(context);
  final returned = Completer<void>();
  var leftPricing = false;
  void checkNavigation() {
    if (returned.isCompleted) return;
    final path = router.routeInformationProvider.value.uri.path;
    if (path != '/quickprice') leftPricing = true;
    if (!context.mounted || (leftPricing && path == '/quickprice')) {
      returned.complete();
    }
  }

  void changed() {
    checkNavigation();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkNavigation());
  }

  router.routeInformationProvider.addListener(changed);
  try {
    await Future.any<void>([
      context.push<void>(
        '${quotation ? '/quotations' : '/sales'}/quickprice/${Uri.encodeComponent(estimate.id)}',
      ),
      returned.future,
    ]);
  } finally {
    router.routeInformationProvider.removeListener(changed);
    if (!returned.isCompleted) returned.complete();
  }
  if (!context.mounted || ref.read(inventoryUidProvider) != uid) return null;
  if (quotation) return null;
  try {
    return (await ref
            .read(salesRepositoryProvider)
            .get(uid, estimate.operationId))
        .id;
  } on AppFailure catch (failure) {
    if (failure.reference == 'sales/not-found') return null;
    rethrow;
  }
}

/// Own every pricing page/dialog so a scope change removes the entire stack.
class _ScopedPricingNavigator extends StatefulWidget {
  const _ScopedPricingNavigator({
    super.key,
    required this.workspace,
    required this.onExit,
    required this.onCheckout,
    required this.onQuotation,
    required this.onQuotationHistory,
  });
  final QuickPriceWorkspace workspace;
  final VoidCallback onExit;
  final Future<String?> Function(QuickPriceEstimate estimate) onCheckout;
  final Future<void> Function(QuickPriceEstimate estimate) onQuotation;
  final VoidCallback onQuotationHistory;
  @override
  State<_ScopedPricingNavigator> createState() =>
      _ScopedPricingNavigatorState();
}

class _ScopedPricingNavigatorState extends State<_ScopedPricingNavigator> {
  final navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) => navigator.currentState!.pop(result),
    child: Navigator(
      key: navigator,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => QuickPriceScreen(
          workspace: widget.workspace,
          onExit: widget.onExit,
          onCheckout: widget.onCheckout,
          onQuotation: widget.onQuotation,
          onQuotationHistory: widget.onQuotationHistory,
        ),
      ),
    ),
  );
}
