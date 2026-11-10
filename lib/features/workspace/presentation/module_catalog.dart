import 'package:flutter/material.dart';

class WorkspaceModule {
  const WorkspaceModule(
    this.name,
    this.path,
    this.icon,
    this.description,
    this.planned, {
    this.available = false,
  });
  final String name;
  final String path;
  final IconData icon;
  final String description;
  final List<String> planned;
  final bool available;
}

const businessModules = [
  WorkspaceModule(
    'QuickPrice',
    '/quickprice',
    Icons.calculate_outlined,
    'Calculate from your products, measurements and published rates.',
    ['Offline calculator', 'Rate cards', 'Instant product switching'],
    available: true,
  ),
  WorkspaceModule(
    'Inventory',
    '/inventory',
    Icons.inventory_2_outlined,
    'A home for every item in your business.',
    ['Product catalogue', 'Stock visibility', 'Low-stock notifications'],
    available: true,
  ),
  WorkspaceModule(
    'Sales',
    '/sales',
    Icons.receipt_long_outlined,
    'Keep everyday sales clearly organised.',
    ['Build a bill', 'Per-bill prices', 'Stock deductions', 'Saved bills'],
    available: true,
  ),
  WorkspaceModule(
    'Purchases',
    '/purchases',
    Icons.shopping_bag_outlined,
    'Keep track of what comes into your business.',
    ['Purchase records', 'Supplier details', 'Purchase returns'],
    available: true,
  ),
  WorkspaceModule(
    'Expenses',
    '/expenses',
    Icons.payments_outlined,
    'Track operating costs alongside purchase records.',
    ['Rent and payroll', 'Utilities and transport', 'Expense history'],
    available: true,
  ),
  WorkspaceModule(
    'Accounting',
    '/accounting',
    Icons.account_balance_outlined,
    'Record tax and operational accounting entries.',
    ['Income and expense ledger', 'Tax entries', 'Finance overview'],
    available: true,
  ),
  WorkspaceModule(
    'Quotations',
    '/quotations',
    Icons.request_quote_outlined,
    'Prepare estimates before a sale is confirmed.',
    ['Customer estimates', 'Tax-aware totals', 'Quotation history'],
    available: true,
  ),
  WorkspaceModule(
    'Purchase orders',
    '/purchase-orders',
    Icons.fact_check_outlined,
    'Plan supplier orders before receiving stock.',
    ['Supplier orders', 'Expected totals', 'Order history'],
    available: true,
  ),
  WorkspaceModule(
    'Customers',
    '/customers',
    Icons.people_outline_rounded,
    'A clearer picture of your customer relationships.',
    ['Customer directory', 'Account history', 'Payment records'],
    available: true,
  ),
  WorkspaceModule(
    'Reports',
    '/reports',
    Icons.bar_chart_rounded,
    'Turn your business activity into useful insights.',
    ['Business summaries', 'Profit and loss', 'Sales insights'],
    available: true,
  ),
  WorkspaceModule(
    'WhatsApp updates',
    '/whatsapp',
    Icons.chat_outlined,
    'Prepare product updates and customer follow-ups.',
    ['Opt-in customer list', 'Manual click-to-chat', 'Payment follow-up queue'],
    available: true,
  ),
];

const accountModules = [
  WorkspaceModule(
    'Settings',
    '/settings',
    Icons.tune_rounded,
    'Make Hyner feel right for you.',
    [],
  ),
  WorkspaceModule(
    'Your profile',
    '/profile',
    Icons.person_outline_rounded,
    'Your account information.',
    [],
  ),
];
