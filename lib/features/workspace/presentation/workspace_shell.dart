import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/hyner_mark.dart';
import '../../auth/presentation/session_controller.dart';
import 'module_catalog.dart';

class WorkspaceShell extends ConsumerWidget {
  const WorkspaceShell({
    super.key,
    required this.location,
    required this.child,
    this.showAppBar = true,
  });
  final String location;
  final Widget child;
  final bool showAppBar;

  int get _selected {
    if (location == '/dashboard') return 0;
    if (location.startsWith('/quickprice')) return 1;
    if (location.startsWith('/sales')) return 2;
    if (location.startsWith('/inventory')) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final billEditor = location == '/sales';
    final showNavigation = !billEditor;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              leading: billEditor
                  ? IconButton(
                      tooltip: 'Back',
                      onPressed: () {
                        final router = GoRouter.of(context);
                        if (router.canPop()) router.pop();
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  : null,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HynerMark(size: 28),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Hyner',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                  ),
                ],
              ),
              actions: [
                if (billEditor)
                  IconButton(
                    tooltip: 'Saved bills',
                    onPressed: () => openWorkspacePage(
                      GoRouter.of(context),
                      '/sales/history',
                    ),
                    icon: const Icon(Icons.history_rounded),
                  ),
                IconButton(
                  tooltip: 'QuickPrice',
                  onPressed: () =>
                      openWorkspacePage(GoRouter.of(context), '/quickprice'),
                  icon: const Icon(Icons.calculate_outlined),
                ),
                if (profile != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      tooltip: 'Your profile',
                      onPressed: () =>
                          openWorkspacePage(GoRouter.of(context), '/profile'),
                      icon: AccountAvatar(profile: profile, radius: 17),
                    ),
                  ),
              ],
            )
          : null,
      drawer: wide || !showNavigation
          ? null
          : Drawer(
              child: SafeArea(
                child: _NavigationList(location: location, closeDrawer: true),
              ),
            ),
      body: Row(
        children: [
          if (wide && showNavigation)
            SizedBox(
              width: 224,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: _NavigationList(location: location),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: wide || !showNavigation
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: (index) {
                  if (index == 4) {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (sheetContext) => FractionallySizedBox(
                        heightFactor: .75,
                        child: _NavigationList(location: location, sheet: true),
                      ),
                    );
                  } else {
                    openWorkspacePage(
                      GoRouter.of(context),
                      [
                        '/dashboard',
                        '/quickprice',
                        '/sales',
                        '/inventory',
                      ][index],
                    );
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calculate_outlined),
                    selectedIcon: Icon(Icons.calculate_rounded),
                    label: 'Price',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Bill',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2_rounded),
                    label: 'Stock',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'More',
                  ),
                ],
              ),
            ),
    );
  }
}

class _NavigationList extends StatelessWidget {
  const _NavigationList({
    required this.location,
    this.closeDrawer = false,
    this.sheet = false,
  });
  final String location;
  final bool closeDrawer;
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    void navigate(String path) {
      final router = GoRouter.of(context);
      if (closeDrawer || sheet) Navigator.of(context).pop();
      openWorkspacePage(router, path);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Workspace', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        if (!sheet) ...[
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            selected: location == '/dashboard',
            onTap: () => navigate('/dashboard'),
          ),
          for (final entry in const [
            ('Price', '/quickprice', Icons.calculate_outlined),
            ('Bill', '/sales', Icons.receipt_long_outlined),
            ('Stock', '/inventory', Icons.inventory_2_outlined),
          ])
            ListTile(
              leading: Icon(entry.$3),
              title: Text(entry.$1),
              selected:
                  location == entry.$2 || location.startsWith('${entry.$2}/'),
              onTap: () => navigate(entry.$2),
            ),
        ],
        for (final group in const {
          'Business': [
            '/customers',
            '/purchases',
            '/expenses',
            '/quotations',
            '/purchase-orders',
          ],
          'Insights': ['/accounting'],
          'Communication': ['/whatsapp'],
        }.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              group.key,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (group.key == 'Business')
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.receipt_long_outlined, size: 22),
              title: const Text('Bill history'),
              selected: location.startsWith('/sales/history'),
              onTap: () => navigate('/sales/history'),
            ),
          for (final module in businessModules.where(
            (module) =>
                group.value.contains(module.path) &&
                !['/inventory', '/sales', '/reports'].contains(module.path),
          ))
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              selected:
                  module.path == location ||
                  location.startsWith('${module.path}/'),
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: .5),
              leading: Icon(module.icon, size: 22),
              title: Text(module.name),
              onTap: () => navigate(module.path),
            ),
          if (group.key == 'Insights') ...[
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.bar_chart_rounded, size: 22),
              title: const Text('Reports'),
              selected: location == '/reports',
              onTap: () => navigate('/reports'),
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.pending_actions_outlined, size: 22),
              title: const Text('Pending payments'),
              selected: location == '/sales/remaining',
              onTap: () => navigate('/sales/remaining'),
            ),
          ],
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Preferences',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: const Icon(Icons.help_outline_rounded, size: 22),
          title: const Text('How do I...?'),
          selected: location == '/help',
          onTap: () => navigate('/help'),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: const Icon(Icons.directions_walk_outlined, size: 22),
          title: const Text('Take a tour'),
          onTap: () => navigate('/getting-started'),
        ),
        for (final module in accountModules)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(module.icon, size: 22),
            title: Text(module.name),
            onTap: () => navigate(module.path),
          ),
        const SizedBox(height: 28),
        Text(
          'Hyner · Saved on this device',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
