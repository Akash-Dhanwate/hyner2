import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/hyner_mark.dart';
import '../../auth/presentation/session_controller.dart';
import 'module_catalog.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.location,
    required this.child,
    this.showAppBar = true,
  });
  final String location;
  final Widget child;
  final bool showAppBar;

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  bool _railCollapsed = false;

  int get _selected {
    if (widget.location == '/dashboard') return 0;
    if (widget.location.startsWith('/quickprice')) return 1;
    if (widget.location.startsWith('/sales')) return 2;
    if (widget.location.startsWith('/inventory')) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider).profile;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final billEditor = widget.location == '/sales';
    const showNavigation = true;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              leading: billEditor
                  ? IconButton(
                      tooltip: 'Back',
                      onPressed: () {
                        final router = GoRouter.of(context);
                        if (router.canPop()) {
                          router.pop();
                        } else {
                          openWorkspacePage(router, '/dashboard');
                        }
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
                child: _NavigationList(
                  location: widget.location,
                  closeDrawer: true,
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide && showNavigation)
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: _railCollapsed ? 84 : 248,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(
                    right: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _NavigationList(
                        location: widget.location,
                        compact: _railCollapsed,
                      ),
                    ),
                    IconButton(
                      tooltip: _railCollapsed
                          ? 'Expand navigation'
                          : 'Collapse navigation',
                      onPressed: () =>
                          setState(() => _railCollapsed = !_railCollapsed),
                      icon: Icon(
                        _railCollapsed
                            ? Icons.keyboard_double_arrow_right_rounded
                            : Icons.keyboard_double_arrow_left_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          Expanded(child: widget.child),
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
                        child: _NavigationList(
                          location: widget.location,
                          sheet: true,
                        ),
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
    this.compact = false,
  });
  final String location;
  final bool closeDrawer;
  final bool sheet;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void navigate(String path) {
      final router = GoRouter.of(context);
      if (closeDrawer || sheet) Navigator.of(context).pop();
      openWorkspacePage(router, path);
    }

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 20,
        vertical: 20,
      ),
      children: [
        if (!compact) ...[
          Text('Workspace', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
        ],
        if (!sheet) ...[
          _NavigationTile(
            icon: Icons.home_outlined,
            label: 'Home',
            compact: compact,
            selected: location == '/dashboard',
            onTap: () => navigate('/dashboard'),
          ),
          for (final entry in const [
            ('Price', '/quickprice', Icons.calculate_outlined),
            ('Bill', '/sales', Icons.receipt_long_outlined),
            ('Stock', '/inventory', Icons.inventory_2_outlined),
          ])
            _NavigationTile(
              icon: entry.$3,
              label: entry.$1,
              compact: compact,
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
          if (!compact)
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
            _NavigationTile(
              icon: Icons.receipt_long_outlined,
              label: 'Bill history',
              compact: compact,
              selected: location.startsWith('/sales/history'),
              onTap: () => navigate('/sales/history'),
            ),
          for (final module in businessModules.where(
            (module) =>
                group.value.contains(module.path) &&
                !['/inventory', '/sales', '/reports'].contains(module.path),
          ))
            _NavigationTile(
              icon: module.icon,
              label: module.name,
              compact: compact,
              selected:
                  module.path == location ||
                  location.startsWith('${module.path}/'),
              onTap: () => navigate(module.path),
            ),
          if (group.key == 'Insights') ...[
            _NavigationTile(
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              compact: compact,
              selected: location == '/reports',
              onTap: () => navigate('/reports'),
            ),
            _NavigationTile(
              icon: Icons.pending_actions_outlined,
              label: 'Pending payments',
              compact: compact,
              selected: location == '/sales/remaining',
              onTap: () => navigate('/sales/remaining'),
            ),
          ],
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(),
        ),
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Preferences',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        _NavigationTile(
          icon: Icons.help_outline_rounded,
          label: 'How do I...?',
          compact: compact,
          selected: location == '/help',
          onTap: () => navigate('/help'),
        ),
        _NavigationTile(
          icon: Icons.directions_walk_outlined,
          label: 'Take a tour',
          compact: compact,
          onTap: () => navigate('/getting-started'),
        ),
        for (final module in accountModules)
          _NavigationTile(
            icon: module.icon,
            label: module.name,
            compact: compact,
            onTap: () => navigate(module.path),
          ),
        if (!compact) ...[
          const SizedBox(height: 28),
          Text(
            'Hyner · Saved on this device',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = ListTile(
      dense: true,
      minTileHeight: 52,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12),
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: .72),
      leading: Icon(icon, size: 22),
      title: compact ? null : Text(label),
      onTap: onTap,
    );
    final materialTile = Material(type: MaterialType.transparency, child: tile);
    return compact
        ? Tooltip(message: label, child: materialTile)
        : materialTile;
  }
}
