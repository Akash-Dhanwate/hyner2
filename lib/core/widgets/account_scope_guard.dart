import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/inventory/presentation/inventory_controller.dart';

/// Hides an in-progress media/document route as soon as its account is left.
class AccountScopeGuard extends ConsumerWidget {
  const AccountScopeGuard({super.key, required this.uid, required this.child});
  final String uid;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(inventoryUidProvider) == uid) return child;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
    return const Scaffold(body: SizedBox.shrink());
  }
}
