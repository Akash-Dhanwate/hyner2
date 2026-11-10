import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../pricing/application/calculator_session.dart';
import '../../pricing/application/estimate_builder.dart';
import '../../pricing/application/workspace.dart';
import '../../pricing/presentation/workspace_quickprice_screen.dart';
import '../domain/sale_checkout_seed.dart';
import 'sale_editor_screen.dart';
import 'sales_controller.dart';

/// Resolves a saved estimate inside the current account before the existing
/// sales editor receives it. A URL cannot supply another account or price list.
class QuickPriceCheckoutScreen extends ConsumerWidget {
  const QuickPriceCheckoutScreen({super.key, required this.estimateId});
  final String estimateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final uid = ref.watch(inventoryUidProvider);
    if (profile == null || uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scope = profile.localOnly ? null : profile.uid;
    return ref
        .watch(pricingWorkspaceProvider(scope))
        .when(
          data: (workspace) => _CheckoutLoader(
            key: ValueKey((uid, workspace.businessId, estimateId)),
            uid: uid,
            estimateId: estimateId,
            workspace: workspace,
          ),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => _CheckoutFailure(
            message: pricingError(error),
            retry: () => ref.invalidate(pricingWorkspaceProvider(scope)),
          ),
        );
  }
}

class _CheckoutLoader extends ConsumerStatefulWidget {
  const _CheckoutLoader({
    super.key,
    required this.uid,
    required this.estimateId,
    required this.workspace,
  });
  final String uid, estimateId;
  final QuickPriceWorkspace workspace;
  @override
  ConsumerState<_CheckoutLoader> createState() => _CheckoutLoaderState();
}

class _CheckoutLoaderState extends ConsumerState<_CheckoutLoader> {
  SaleCheckoutSeed? seed;
  String? error;
  int generation = 0;
  bool get current => mounted && ref.read(inventoryUidProvider) == widget.uid;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final ticket = ++generation;
    if (mounted) {
      setState(() {
        error = null;
        seed = null;
      });
    }
    try {
      final repository = EstimateRepository(widget.workspace);
      final estimate = await repository.load();
      if (!current || ticket != generation) return;
      if (estimate.id != widget.estimateId || estimate.lines.isEmpty) {
        throw StateError(
          'This estimate is no longer the current draft. Open QuickPrice to choose the estimate.',
        );
      }
      try {
        final existing = await ref
            .read(salesRepositoryProvider)
            .get(widget.uid, estimate.operationId);
        if (!current || ticket != generation) return;
        if (estimate.convertedSaleId == null) {
          await repository.save(estimate.markConverted(existing.id));
        }
        if (mounted && current && ticket == generation) {
          context.replace('/sales/${Uri.encodeComponent(existing.id)}');
        }
        return;
      } on AppFailure catch (failure) {
        if (failure.reference != 'sales/not-found') rethrow;
      }
      if (!current || ticket != generation) return;
      if (estimate.convertedSaleId != null) {
        throw StateError(
          'The saved bill is unavailable. Retry loading the bill before creating another one.',
        );
      }
      final initial = estimate.toCheckoutSeed(widget.uid);
      setState(
        () => seed = SaleCheckoutSeed(
          uid: initial.uid,
          operationId: initial.operationId,
          lines: initial.lines,
          onSaved: (saleId) async {
            if (!current) return;
            final latest = await repository.load();
            if (!current ||
                latest.id != estimate.id ||
                latest.revision != estimate.revision) {
              return;
            }
            await repository.save(latest.markConverted(saleId));
          },
        ),
      );
    } catch (e) {
      if (current && ticket == generation) {
        setState(
          () => error = e is AppFailure ? e.displayMessage : pricingError(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return _CheckoutFailure(message: error!, retry: _load);
    if (seed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return SaleEditorScreen(checkout: seed);
  }
}

class _CheckoutFailure extends StatelessWidget {
  const _CheckoutFailure({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QuickPrice checkout')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            FilledButton(onPressed: retry, child: const Text('Retry')),
            TextButton(
              onPressed: () => context.go('/quickprice'),
              child: const Text('Back to estimate'),
            ),
          ],
        ),
      ),
    ),
  );
}
