import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_workspace.dart';
import 'workspace.dart';

/// Shared local pricing database scope used by QuickPrice and inventory sync.
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
