import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/customers/presentation/customer_detail_screen.dart';
import 'package:hyner/features/customers/presentation/customers_controller.dart';
import 'package:hyner/features/customers/presentation/customers_screen.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/inventory/presentation/inventory_controller.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/presentation/sales_controller.dart';

import 'support/fakes.dart';
import 'support/inventory_fakes.dart';
import 'support/sales_fakes.dart';

void main() {
  late Customer customer;
  late Customer otherCustomer;
  late FakeCustomers customers;
  late FakeSales sales;
  late GoRouter router;

  setUp(() {
    customer = Customer(
      id: 'directory-primary-ABC123',
      name: 'Asha Buyer',
      phone: '+91 (98765) 43210',
      notes: '',
      createdAt: DateTime(2026, 11, 9),
      updatedAt: DateTime(2026, 11, 10),
    );
    otherCustomer = Customer(
      id: 'directory-secondary-XYZ789',
      name: 'Nikhil Shah',
      phone: '9123456780',
      notes: '',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
    customers = FakeCustomers();
    customers.accounts[testIdentity.uid] = [customer, otherCustomer];
    // The inventory is deliberately empty: history must use saved bill details.
    sales = FakeSales(FakeInventory());
    sales.sales(testIdentity.uid).addAll({
      'inr-new': Sale(
        id: 'inr-new',
        createdAt: DateTime(2026, 11, 8),
        paymentStatus: PaymentStatus.partial,
        paidMinor: 10000,
        draft: SaleDraft(
          currency: 'INR',
          customerId: customer.id,
          customerName: customer.name,
          lines: [
            SaleLine(
              sku: 'FABRIC',
              name: 'Woven fabric',
              unitPriceMinor: 12500,
              quantity: 2,
              parameters: const [
                ProductParameter(name: 'Length', value: '2.5 m'),
                ProductParameter(name: 'Width', value: '44 in'),
                ProductParameter(
                  name: 'Custom finish and handling instructions',
                  value: 'Brushed satin finish with reinforced stitched edges',
                ),
              ],
            ),
            SaleLine(
              sku: 'TRIM',
              name: 'Cotton trim',
              unitPriceMinor: 2500,
              quantity: 1,
              parameters: const [
                ProductParameter(name: 'Colour', value: 'Indigo'),
              ],
            ),
          ],
        ),
      ),
      'inr-old': Sale(
        id: 'inr-old',
        createdAt: DateTime(2026, 11, 7),
        paymentStatus: PaymentStatus.paid,
        paidMinor: 5000,
        draft: SaleDraft(
          currency: 'INR',
          customerId: customer.id,
          customerName: customer.name,
          lines: [
            SaleLine(
              sku: 'FABRIC',
              name: 'Original fabric name',
              unitPriceMinor: 5000,
              quantity: 1,
              parameters: const [
                ProductParameter(name: 'Length', value: '3 m'),
                ProductParameter(name: 'Width', value: '42 in'),
              ],
            ),
          ],
        ),
      ),
      'usd': Sale(
        id: 'usd',
        createdAt: DateTime(2026, 11, 6),
        draft: SaleDraft(
          currency: 'USD',
          customerId: customer.id,
          customerName: customer.name,
          lines: [
            SaleLine(
              sku: 'BUCKLE',
              name: 'Brass buckle',
              unitPriceMinor: 900,
              quantity: 3,
              parameters: const [
                ProductParameter(name: 'Finish', value: 'Antique brass'),
              ],
            ),
          ],
        ),
      ),
      'other-customer': Sale(
        id: 'other-customer',
        createdAt: DateTime(2026, 11, 9),
        draft: SaleDraft(
          currency: 'INR',
          customerId: otherCustomer.id,
          customerName: otherCustomer.name,
          lines: [
            SaleLine(
              sku: 'PRIVATE',
              name: 'Unrelated private product',
              unitPriceMinor: 99900,
              quantity: 99,
            ),
          ],
        ),
      ),
    });
    sales.sales('another-account')['inr-new'] = sales.sales(
      testIdentity.uid,
    )['other-customer']!;
  });

  Future<void> mount(
    WidgetTester tester, {
    bool detail = false,
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        inventoryUidProvider.overrideWithValue(testIdentity.uid),
        customerRepositoryProvider.overrideWithValue(customers),
        salesRepositoryProvider.overrideWithValue(sales),
      ],
    );
    router = GoRouter(
      initialLocation: detail ? '/customers/${customer.id}' : '/customers',
      routes: [
        GoRoute(
          path: '/customers',
          builder: (_, _) => const Scaffold(body: CustomersScreen()),
        ),
        GoRoute(
          path: '/customers/:id',
          builder: (_, state) => Scaffold(
            body: CustomerDetailScreen(id: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/sales/:id',
          builder: (_, state) => Scaffold(
            body: Text('Opened bill: ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(useMaterial3: true, brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        150,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
        maxScrolls: 60,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target, findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> search(WidgetTester tester, String query) async {
    final field = find.byKey(const Key('customer-search'));
    await reveal(tester, field);
    await tester.enterText(field, query);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  final searchCases = [
    ('name, ignoring case and extra spaces', '  ASHA   buyer  '),
    ('normalized phone', '9876543210'),
    ('formatted phone', '+91 98765 43210'),
    // This prefix is absent from the generated reference; it tests the raw ID.
    ('stable customer ID', 'directory-primary'),
    ('added date', '09/11/2026'),
  ];
  for (final (label, query) in searchCases) {
    testWidgets(
      'customer directory filters by $label at 320px with large text',
      (tester) async {
        await mount(tester, size: const Size(320, 568), textScale: 1.6);
        await search(tester, query);
        await reveal(tester, find.byKey(ValueKey('customer-${customer.id}')));
        expect(find.text(customer.name), findsOneWidget);
        expect(
          find.textContaining('Customer ID: ${customer.reference}'),
          findsOneWidget,
        );
        expect(find.textContaining('Reference:'), findsNothing);
        expect(find.text(otherCustomer.name), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
      },
    );
  }

  testWidgets(
    'readable customer ID search, no matches and clearing the filter',
    (tester) async {
      await mount(tester);
      await search(tester, customer.reference.toLowerCase());
      await reveal(tester, find.byKey(ValueKey('customer-${customer.id}')));
      expect(find.text(otherCustomer.name), findsNothing);

      await search(tester, 'nobody matches this');
      await reveal(tester, find.text('No customers match your search.'));
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('No customers saved yet.'), findsNothing);

      final clear = find.byTooltip('Clear customer search');
      await reveal(tester, clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('customer-search')))
            .controller!
            .text,
        isEmpty,
      );
      await reveal(tester, find.text(customer.name));
      await reveal(tester, find.text(otherCustomer.name));
    },
  );

  testWidgets(
    'detail shows identity, added date and separate currency totals',
    (tester) async {
      await mount(tester, detail: true);
      expect(find.text('Customer ID: ${customer.id}'), findsNothing);
      expect(find.textContaining('Reference:'), findsNothing);
      for (final text in [
        'Customer ID: ${customer.reference}',
        'Added: 09/11/2026',
        '3 bills · 7 units',
        'Total billed: INR 325.00',
        'Paid: INR 150.00 · Due: INR 175.00',
        'Total billed: USD 27.00',
        'Paid: USD 0.00 · Due: USD 27.00',
      ]) {
        await reveal(tester, find.text(text));
      }
      expect(find.text('Unrelated private product · 99 units'), findsNothing);
      expect(
        find.byKey(const Key('customer-bill-other-customer')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'each bill keeps its saved product names and parameter snapshot',
    (tester) async {
      await mount(tester, detail: true);
      final recent = find.byKey(const Key('customer-bill-inr-new'));
      await reveal(tester, recent);
      for (final text in [
        'Woven fabric · 2 units',
        'Length: 2.5 m',
        'Width: 44 in',
        'Cotton trim · 1 units',
        'Colour: Indigo',
        'Part paid · INR 175.00 due',
      ]) {
        await reveal(
          tester,
          find.descendant(of: recent, matching: find.text(text)),
        );
      }

      final older = find.byKey(const Key('customer-bill-inr-old'));
      await reveal(tester, older);
      for (final text in [
        'Original fabric name · 1 units',
        'Length: 3 m',
        'Width: 42 in',
        'Paid',
      ]) {
        await reveal(
          tester,
          find.descendant(of: older, matching: find.text(text)),
        );
      }
      expect(
        find.descendant(of: older, matching: find.text('Length: 2.5 m')),
        findsNothing,
      );
      final link = find.descendant(of: older, matching: find.text('View bill'));
      await reveal(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/sales/inr-old');
      expect(find.text('Opened bill: inr-old'), findsOneWidget);
      expect(sales.writes, 0);
    },
  );

  testWidgets('customer with no bills has a zero summary and empty history', (
    tester,
  ) async {
    sales.sales(testIdentity.uid).clear();
    await mount(tester, detail: true);
    await reveal(tester, find.text('0 bills · 0 units'));
    await reveal(
      tester,
      find.text('No bills are linked to this customer yet.'),
    );
    expect(find.text('View bill'), findsNothing);
    expect(find.textContaining('Total billed:'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'directory and bill specs fit 320px at 1.6x text in ${brightness.name}',
      (tester) async {
        await mount(
          tester,
          size: const Size(320, 568),
          textScale: 1.6,
          brightness: brightness,
        );
        await search(tester, '9876543210');
        final row = find.byKey(ValueKey('customer-${customer.id}'));
        await reveal(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/customers/${customer.id}');
        expect(tester.takeException(), isNull);

        for (final text in [
          'Customer ID: ${customer.reference}',
          'Added: 09/11/2026',
          '3 bills · 7 units',
          'Total billed: INR 325.00',
          'Paid: INR 150.00 · Due: INR 175.00',
          'Total billed: USD 27.00',
          'Woven fabric · 2 units',
          'Length: 2.5 m',
          'Custom finish and handling instructions: '
              'Brushed satin finish with reinforced stitched edges',
          'Cotton trim · 1 units',
          'Colour: Indigo',
          'Original fabric name · 1 units',
          'Width: 42 in',
          'Brass buckle · 3 units',
          'Finish: Antique brass',
          'Pending · USD 27.00 due',
        ]) {
          await reveal(tester, find.text(text));
        }
        final dollarBill = find.byKey(const Key('customer-bill-usd'));
        final link = find.descendant(
          of: dollarBill,
          matching: find.text('View bill'),
        );
        await reveal(tester, link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/sales/usd');
        expect(find.text('Opened bill: usd'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
