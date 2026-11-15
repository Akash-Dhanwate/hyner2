import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/widgets/page_content.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  String _query = '';

  static const _tasks = <({String title, String hint, String route})>[
    (
      title: 'Change shop details',
      hint: 'Business name and invoice details',
      route: '/bill-settings',
    ),
    (
      title: 'Change bill appearance',
      hint: 'Templates, logo and bill layout',
      route: '/bill-settings',
    ),
    (
      title: 'Change a product price',
      hint: 'Choose a product, then tap Edit',
      route: '/inventory',
    ),
    (
      title: 'Adjust stock',
      hint: 'Choose a product, then tap Adjust stock',
      route: '/inventory',
    ),
    (
      title: 'Edit calculator rates',
      hint: 'Open QuickPrice, then Calculator options',
      route: '/quickprice',
    ),
    (
      title: 'Rename a calculator',
      hint: 'Open QuickPrice, then Calculator options',
      route: '/quickprice',
    ),
    (
      title: 'Download a bill',
      hint: 'Open Sales history and choose a bill',
      route: '/sales/history',
    ),
    (
      title: 'Record a payment',
      hint: 'Open a bill or Pending payments',
      route: '/sales/remaining',
    ),
    (
      title: 'Change the app theme',
      hint: 'Choose a colour and appearance mode',
      route: '/settings',
    ),
    (
      title: 'Create a backup',
      hint: 'Export business records to a safe location',
      route: '/settings',
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final tasks = _tasks.where(
      (task) =>
          query.isEmpty ||
          '${task.title} ${task.hint}'.toLowerCase().contains(query),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('How do I...?')),
      body: PageContent(
        children: [
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search for a task',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(task.title),
              subtitle: Text(task.hint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openWorkspacePage(GoRouter.of(context), task.route),
            ),
          if (tasks.isEmpty) const Text('No matching tasks.'),
        ],
      ),
    );
  }
}
