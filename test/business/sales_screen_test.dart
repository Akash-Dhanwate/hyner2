import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/bill_document_repository.dart';
import 'package:hyner/features/sales/presentation/sales_controller.dart';
import 'package:hyner/features/sales/data/bill_pdf_actions.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/inventory/domain/pricing_formula.dart';
import 'package:hyner/features/customers/presentation/customers_controller.dart';

import 'support/fakes.dart';
import 'support/inventory_fakes.dart';
import 'support/sales_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late FakeInventory inventory;
  late FakeSales sales;
  late ProviderContainer container;
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    ThemeMode mode = ThemeMode.light,
    BillDocumentRepository? documents,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    auth = FakeAuth(user: testIdentity);
    profiles = FakeProfiles();
    inventory = FakeInventory();
    sales = FakeSales(inventory);
    inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
      quantity: 5,
      priceMinor: 1550,
    );
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(
            auth,
            profiles,
            inventory: inventory,
            sales: sales,
            billDocuments: documents,
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HynerApp()),
    );
    await tester.pumpAndSettle();
    await container.read(themeControllerProvider.notifier).select(mode);
    container.read(routerProvider).go('/sales/history');
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: scroll,
        maxScrolls: 80,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> startBill(
    WidgetTester tester, {
    bool customerDetails = true,
  }) async {
    await tap(tester, find.byKey(const Key('new-sale')));
    await tap(tester, find.byKey(const Key('add-sale-product')));
    await tap(tester, find.byKey(const Key('pick-TEST-1')));
    if (customerDetails) {
      final name = find.byKey(const Key('sale-customer-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Asha Buyer');
      final phone = find.byKey(const Key('sale-customer-phone'));
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '9876543210');
      await tester.pumpAndSettle();
    }
  }

  Future<void> quantity(WidgetTester tester, String text) async {
    final field = find.byKey(const Key('sale-quantity-TEST-1'));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  testWidgets('Sales opens the bill builder without querying saved history', (
    tester,
  ) async {
    await mount(tester);
    sales.requestedUids.clear();
    container.read(routerProvider).go('/sales');
    await tester.pumpAndSettle();
    expect(find.text('Build a bill'), findsOneWidget);
    expect(find.text('No products added yet.'), findsOneWidget);
    expect(sales.requestedUids, isEmpty);
  });

  testWidgets(
    'empty Advance and removing the last product keep the form safe',
    (tester) async {
      await mount(tester);
      container.read(routerProvider).go('/sales');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Advance'));
      expect(find.byKey(const Key('sale-advance-amount')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-sale')))
            .onPressed,
        isNull,
      );
      await tap(tester, find.byKey(const Key('add-sale-product')));
      await tap(tester, find.byKey(const Key('pick-TEST-1')));
      await tap(tester, find.byTooltip('Remove TEST-1'));
      expect(find.text('No products added yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'products precede customer checkout and name/mobile are required',
    (tester) async {
      await mount(tester);
      await startBill(tester, customerDetails: false);
      expect(
        tester.getTopLeft(find.byKey(const Key('add-sale-product'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('sale-customer-name'))).dy,
        ),
      );
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(find.text('Enter the customer name.'), findsOneWidget);
      expect(find.text('Enter a valid mobile number.'), findsOneWidget);
      expect(sales.writes, 0);
      final name = find.byKey(const Key('sale-customer-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Asha Buyer');
      final phone = find.byKey(const Key('sale-customer-phone'));
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '123');
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(sales.writes, 0);
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '+91 98765 43210');
      final address = find.byKey(const Key('sale-customer-address'));
      await tester.ensureVisible(address);
      await tester.enterText(address, '42 Market Road');
      await tap(tester, find.byKey(const Key('save-sale')));
      final saved = sales.sales(testIdentity.uid)['sale1']!.draft;
      expect(saved.customerName, 'Asha Buyer');
      expect(saved.customerPhone, '+91 98765 43210');
      expect(saved.customerAddress, '42 Market Road');
      expect(find.text('42 Market Road'), findsOneWidget);
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('WhatsApp PDF'),
        220,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('WhatsApp PDF'), findsOneWidget);
      expect(find.text('Save PDF'), findsOneWidget);
      expect(sales.writes, 1);
    },
  );

  testWidgets('existing customer selection snapshots address at checkout', (
    tester,
  ) async {
    await mount(tester);
    final customers =
        container.read(dependenciesProvider).customers as FakeCustomers;
    await customers.save(
      testIdentity.uid,
      const CustomerDraft(
        name: 'Existing Buyer',
        phone: '',
        address: '7 Old Street',
      ),
      id: 'existing',
    );
    container.invalidate(customersProvider);
    await startBill(tester, customerDetails: false);
    final picker = find.byType(DropdownButtonFormField<String>);
    await tap(tester, picker);
    await tap(tester, find.text('Existing Buyer').last);
    expect(find.byKey(const Key('sale-customer-name')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('sale-customer-name')))
          .controller!
          .text,
      'Existing Buyer',
    );
    await tester.enterText(
      find.byKey(const Key('sale-customer-phone')),
      '9876543210',
    );
    await tap(tester, find.byKey(const Key('save-sale')));
    final saved = sales.sales(testIdentity.uid)['sale1']!.draft;
    expect(saved.customerId, 'existing');
    expect(saved.customerAddress, '7 Old Street');
    expect(saved.customerPhone, '9876543210');
    expect(sales.writes, 1);
  });

  testWidgets(
    'creates a sale, calculates total, deducts stock and opens its saved bill',
    (tester) async {
      await mount(tester);
      expect(find.text('No sales yet'), findsOneWidget);
      await startBill(tester);
      await quantity(tester, '2');
      expect(find.text('INR 31.00'), findsOneWidget);
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(container.read(routerProvider).state.uri.path, '/sales/sale1');
      expect(find.text('SAVED SALE'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('2 × INR 15.50'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('2 × INR 15.50'), findsOneWidget);
      expect(sales.writes, 1);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.quantity, 3);
      container.read(routerProvider).go('/sales/history');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sale-sale1')), findsOneWidget);
    },
  );
  testWidgets(
    'bill price defaults to inventory, can reset, and saves a discount only on the bill',
    (tester) async {
      await mount(tester);
      await startBill(tester);
      final price = find.byKey(const Key('sale-price-TEST-1'));
      expect(tester.widget<TextFormField>(price).controller!.text, '15.50');
      await tester.ensureVisible(price);
      await tester.enterText(price, '12.00');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Use inventory price'));
      expect(tester.widget<TextFormField>(price).controller!.text, '15.50');
      await tester.ensureVisible(price);
      await tester.enterText(price, '12.00');
      await tester.pumpAndSettle();
      await quantity(tester, '2');
      expect(find.text('INR 24.00'), findsOneWidget);
      await tap(tester, find.byKey(const Key('save-sale')));
      await tester.scrollUntilVisible(
        find.text('2 × INR 12.00'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('2 × INR 12.00'), findsOneWidget);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.priceMinor, 1550);
      expect(sales.sales(testIdentity.uid)['sale1']!.draft.totalMinor, 2400);
    },
  );
  testWidgets('negative and fractional-cent prices cannot save a bill', (
    tester,
  ) async {
    await mount(tester);
    await startBill(tester);
    final price = find.byKey(const Key('sale-price-TEST-1'));
    for (final invalid in ['-1', '1.234', '']) {
      await tester.ensureVisible(price);
      await tester.enterText(price, invalid);
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(sales.writes, 0);
    }
  });

  testWidgets('PDF actions on a saved bill never save or deduct stock again', (
    tester,
  ) async {
    await mount(tester);
    await startBill(tester);
    await tap(tester, find.byKey(const Key('save-sale')));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(BillPdfActions.channel, (call) async {
      calls.add(call);
      return call.method == 'savePdf' ? 'content://documents/bill.pdf' : null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(BillPdfActions.channel, null);
    });
    await tap(tester, find.text('WhatsApp PDF'));
    await tap(tester, find.text('Save PDF'));
    await tap(tester, find.text('Save PDF'));
    debugDefaultTargetPlatformOverride = null;
    expect(calls.map((call) => call.method), [
      'shareWhatsApp',
      'savePdf',
      'savePdf',
    ]);
    expect(sales.writes, 1);
    expect(inventory.products(testIdentity.uid)['TEST-1']!.quantity, 4);
  });

  testWidgets(
    'WhatsApp defaults to all and manages saved preferences from one page',
    (tester) async {
      await mount(tester);
      final customers =
          container.read(dependenciesProvider).customers as FakeCustomers;
      final a = await customers.save(
        testIdentity.uid,
        const CustomerDraft(name: 'Alice', phone: '9876543210'),
      );
      await customers.save(
        testIdentity.uid,
        const CustomerDraft(name: 'Bob', phone: '9123456780'),
      );
      container.read(routerProvider).go('/whatsapp');
      await tester.pumpAndSettle();
      final aliceSwitch = find.widgetWithText(SwitchListTile, 'Alice');
      await tap(tester, aliceSwitch);
      expect(
        (await customers.list(testIdentity.uid))
            .firstWhere((customer) => customer.id == a.id)
            .whatsappOptIn,
        isFalse,
      );
      await tap(tester, find.text('Enable updates for all customers'));
      expect(
        (await customers.list(testIdentity.uid))
            .every((customer) => customer.whatsappOptIn),
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.text('Open WhatsApp for 2 selected'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Open WhatsApp for 2 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fixed-price product skips measurements and payment appears before bill copies',
    (tester) async {
      await mount(tester);
      await startBill(tester);
      expect(find.text('Calculate Test product price'), findsNothing);
      expect(find.text('Edit measurements'), findsNothing);
      await tap(tester, find.byKey(const Key('save-sale')));
      final payment = find.byKey(const Key('record-sale-payment'));
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(payment, 150, scrollable: scroll);
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scroll).position;
      final paymentOffset = position.pixels + tester.getTopLeft(payment).dy;
      await tester.scrollUntilVisible(
        find.text('Bill copies'),
        150,
        scrollable: scroll,
      );
      final copiesOffset =
          position.pixels + tester.getTopLeft(find.text('Bill copies')).dy;
      expect(paymentOffset, lessThan(copiesOffset));
      expect(
        find.textContaining('requested QR amount is not treated as paid'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom height pricing asks only configured inputs and cancellation removes the item',
    (tester) async {
      await mount(tester);
      inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
        quantity: 5,
        pricingFormula: const PricingFormula(
          expression: 'height * rate',
          inputs: [
            PricingInput(name: 'height', label: 'Height', unit: 'in'),
            PricingInput(name: 'rate', label: 'Rate'),
          ],
        ),
      );
      await startBill(tester, customerDetails: false);
      expect(find.widgetWithText(TextField, 'Height'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Rate'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Width'), findsNothing);
      await tap(tester, find.text('Cancel'));
      expect(find.byKey(const Key('sale-price-TEST-1')), findsNothing);
      expect(find.text('No products added yet.'), findsOneWidget);
      expect(sales.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bill open and payment refresh use archive metadata; bytes are loaded only for export',
    (tester) async {
      final documents = _ArchiveReadCounter();
      await mount(tester, documents: documents);
      await startBill(tester);
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(documents.ensureCalls, 1);
      expect(documents.byteReads, 0);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        BillPdfActions.channel,
        (_) async => 'content://saved',
      );
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(BillPdfActions.channel, null);
      });
      await tap(tester, find.text('More document options'));
      await tap(tester, find.text('Save duplicate PDF'));
      debugDefaultTargetPlatformOverride = null;
      expect(documents.byteReads, 1);
      await sales.recordPayment(testIdentity.uid, 'sale1', 1550);
      container.invalidate(saleProvider('sale1'));
      await tester.pumpAndSettle();
      expect(
        documents.ensureCalls,
        3,
      ); // Open, explicit export, refreshed paid state.
      expect(documents.byteReads, 1);
      expect(sales.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'damaged duplicate keeps the rebuilt export fallback without replacing the archive',
    (tester) async {
      final documents = _ArchiveReadCounter(broken: true);
      await mount(tester, documents: documents);
      await startBill(tester);
      await tap(tester, find.byKey(const Key('save-sale')));
      Uint8List? exported;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(BillPdfActions.channel, (call) async {
        exported = (call.arguments as Map)['bytes'] as Uint8List;
        return 'content://rebuilt';
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(BillPdfActions.channel, null);
      });
      await tap(tester, find.text('More document options'));
      await tap(tester, find.text('Save duplicate PDF'));
      debugDefaultTargetPlatformOverride = null;
      expect(exported, isNotNull);
      expect(ascii.decode(exported!.take(5).toList()), '%PDF-');
      expect(documents.byteReads, 1);
      expect(documents.saved, 0);
      expect(sales.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calculated dimensions and decimal price are saved on the bill', (
    tester,
  ) async {
    await mount(tester);
    inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
      quantity: 5,
      pricingFormula: defaultComponentPricingFormula,
    );
    await startBill(tester, customerDetails: false);
    expect(find.text('Calculate Test product price'), findsOneWidget);
    for (final field in {
      'Length': '84.25',
      'Width': '36',
      'Rate': '150.05',
    }.entries) {
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == field.key,
        ),
        field.value,
      );
    }
    await tap(tester, find.text('Apply price'));
    for (final entry in {
      'sale-customer-name': 'Asha Buyer',
      'sale-customer-phone': '9876543210',
    }.entries) {
      final field = find.byKey(Key(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await quantity(tester, '2');
    await tap(tester, find.byKey(const Key('save-sale')));
    final line = sales.sales(testIdentity.uid)['sale1']!.draft.lines.single;
    expect(line.unitPriceMinor, 316043);
    expect(line.totalMinor, 632086);
    expect(line.parameters.map((p) => p.toMap()), [
      {'name': 'Length', 'value': '84.25 in'},
      {'name': 'Width', 'value': '36 in'},
    ]);
    await tester.scrollUntilVisible(
      find.text('Length · 84.25 in'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Length · 84.25 in'), findsOneWidget);
  });

  testWidgets('a bill can add and save more than five different products', (
    tester,
  ) async {
    await mount(tester);
    for (var i = 2; i <= 6; i++) {
      inventory.products(testIdentity.uid)['TEST-$i'] = inventoryFixture(
        sku: 'TEST-$i',
        quantity: 5,
        priceMinor: 1550,
      );
    }
    await startBill(tester);
    for (var i = 2; i <= 6; i++) {
      await tap(tester, find.byKey(const Key('add-sale-product')));
      await tap(tester, find.byKey(Key('pick-TEST-$i')));
    }
    expect(find.text('Add product (6 added)'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('add-sale-product')))
          .onPressed,
      isNotNull,
    );
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(sales.sales(testIdentity.uid)['sale1']!.draft.lines.length, 6);
    expect(sales.sales(testIdentity.uid)['sale1']!.draft.totalMinor, 9300);
    expect(sales.writes, 1);
  });

  testWidgets('rejects overselling before calling the repository', (
    tester,
  ) async {
    await mount(tester);
    await startBill(tester);
    await quantity(tester, '6');
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(find.text('Only 5 units available.'), findsOneWidget);
    expect(sales.writes, 0);
  });
  testWidgets(
    'server stock and product identity changes fail visibly without creating a sale',
    (tester) async {
      await mount(tester);
      await startBill(tester);
      inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
        quantity: 0,
        priceMinor: 1550,
      );
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(find.text('Insufficient available stock.'), findsOneWidget);
      expect(sales.writes, 0);
      inventory.products(testIdentity.uid)['TEST-1'] = inventoryFixture(
        quantity: 5,
        priceMinor: 2000,
        name: 'Renamed product',
      );
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(
        find.text('Product changed. Remove it and add it again.'),
        findsOneWidget,
      );
      expect(sales.writes, 0);
    },
  );
  testWidgets(
    'lost response freezes bill and retry uses same ID without a second deduction',
    (tester) async {
      await mount(tester);
      await startBill(tester);
      await quantity(tester, '2');
      sales.failAfterCommit = true;
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(find.text('Connection interrupted'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('sale-quantity-TEST-1')),
            )
            .enabled,
        isFalse,
      );
      expect(sales.writes, 1);
      expect(inventory.products(testIdentity.uid)['TEST-1']!.quantity, 3);
      await tap(tester, find.byKey(const Key('save-sale')));
      expect(sales.ids, 1);
      expect(sales.writes, 1);
      expect(container.read(routerProvider).state.uri.path, '/sales/sale1');
    },
  );
  testWidgets('save stays disabled while a write is pending', (tester) async {
    await mount(tester);
    await startBill(tester);
    sales.pendingWrite = Completer<void>();
    final save = find.byKey(const Key('save-sale'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(sales.ids, 1);
    sales.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(sales.writes, 1);
  });
  testWidgets('back asks before discarding and empty bill cannot be saved', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.byKey(const Key('new-sale')));
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('save-sale'))).onPressed,
      isNull,
    );
    await tap(tester, find.byKey(const Key('add-sale-product')));
    await tap(tester, find.byKey(const Key('pick-TEST-1')));
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Discard this bill?'), findsOneWidget);
    await tap(tester, find.text('Stay'));
    expect(container.read(routerProvider).state.uri.path, '/sales');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Leave'));
    expect(container.read(routerProvider).state.uri.path, '/sales/history');
  });
  testWidgets(
    'product picker prevents duplicate and out-of-stock selection and supports search',
    (tester) async {
      await mount(tester);
      inventory.products(testIdentity.uid)['ZERO'] = inventoryFixture(
        sku: 'ZERO',
        name: 'Zero stock',
        quantity: 0,
      );
      await startBill(tester);
      await tap(tester, find.byKey(const Key('add-sale-product')));
      expect(
        tester.widget<ListTile>(find.byKey(const Key('pick-TEST-1'))).enabled,
        isFalse,
      );
      expect(
        tester.widget<ListTile>(find.byKey(const Key('pick-ZERO'))).enabled,
        isFalse,
      );
      await tester.enterText(
        find.byKey(const Key('sale-product-search')),
        'zero',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pick-TEST-1')), findsNothing);
      expect(find.text('Zero stock'), findsOneWidget);
    },
  );
  testWidgets('switching accounts clears an unsaved bill', (tester) async {
    await mount(tester);
    await startBill(tester);
    profiles.result = UserProfile(
      uid: 'bob',
      email: 'bob@example.test',
      createdAt: DateTime.utc(2026),
      lastLoginAt: DateTime.utc(2026),
    );
    auth.changeAccount(
      const AccountIdentity(uid: 'bob', email: 'bob@example.test'),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/sales/new');
    await tester.pumpAndSettle();
    expect(find.text('Test product'), findsNothing);
    expect(find.text('No products added yet.'), findsOneWidget);
    expect(sales.writes, 0);
  });
  testWidgets(
    'sales errors offer retry and never show a successful empty list',
    (tester) async {
      await mount(tester);
      sales.failure = const AppFailure(
        FailureKind.permission,
        'Publish sales rules',
      );
      await tap(tester, find.byTooltip('Refresh sales'));
      expect(find.text('Publish sales rules'), findsOneWidget);
      expect(find.text('No sales yet'), findsNothing);
      sales.failure = null;
      await tap(tester, find.text('Try again'));
      expect(find.text('No sales yet'), findsOneWidget);
    },
  );
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'sales list, picker, bill and detail fit 320px with large text in ${mode.name}',
      (tester) async {
        await mount(tester, size: const Size(320, 568), scale: 1.6, mode: mode);
        expect(tester.takeException(), isNull);
        await startBill(tester);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        sales.sales(testIdentity.uid)['saved'] = Sale(
          id: 'saved',
          createdAt: DateTime.utc(2026),
          draft: SaleDraft(
            currency: 'INR',
            lines: [SaleLine.fromProduct(inventoryFixture(), 2)],
          ),
        );
        container.read(routerProvider).go('/sales/saved');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _ArchiveReadCounter implements BillDocumentRepository {
  _ArchiveReadCounter({this.broken = false});
  final bool broken;
  int byteReads = 0, ensureCalls = 0, saved = 0;
  final bytes = Uint8List.fromList(
    utf8.encode('%PDF-1.7\narchived duplicate\n%%EOF'),
  );
  @override
  Future<bool> hasDuplicate(String uid, String saleId) async => true;
  @override
  Future<void> ensureDuplicate(
    String uid,
    String saleId,
    Future<Uint8List> Function() generate,
  ) async {
    ensureCalls++;
  }

  @override
  Future<Uint8List?> duplicate(String uid, String saleId) async {
    byteReads++;
    if (broken) throw const FormatException('Corrupt fixture archive');
    return bytes;
  }

  @override
  Future<void> saveDuplicate(String uid, String saleId, Uint8List bytes) async {
    saved++;
  }
}
