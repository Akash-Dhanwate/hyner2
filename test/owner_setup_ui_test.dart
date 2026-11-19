import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';
import 'package:hyner/features/pricing/application/workspace.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/pricing/presentation/pricing_widgets.dart';
import 'package:hyner/main.dart';

import 'calculator_ui_test.dart' show input;
import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ValueField && w.label == label),
  matching: find.byType(TextField),
);
Finder select(String label) =>
    find.byWidgetPredicate((w) => w is SelectField && w.label == label);

Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      260,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

QuickPriceWorkspace ownerWorkspace() {
  final memory = createPreviewWorkspace();
  return QuickPriceWorkspace(
    businessId: memory.businessId,
    values: memory.values,
    repository: memory.repository,
  );
}

void main() {
  testWidgets(
    'door setup needs rates only, saves once and reopens without setup',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = ownerWorkspace();
      final auth = FakeAuth(user: testIdentity);
      final inventory = FakeInventory();
      addTearDown(auth.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dependenciesProvider.overrideWithValue(
              connectedTestDependencies(
                auth,
                FakeProfiles(),
                inventory: inventory,
              ),
            ),
          ],
          child: HynerApp(workspace: Future.value(workspace)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create calculator'));
      await tester.pumpAndSettle();
      expect(find.text('Set up calculator'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Try a real size'), findsNothing);
      expect(field('Height'), findsNothing);
      expect(select('Final money rounding'), findsNothing);
      expect(find.text('Charge tax'), findsNothing);
      await tester.enterText(field('Calculator name'), 'Door prices');
      await tester.enterText(field('Product name'), 'Basic flush door');
      await tester.enterText(field('Selling rate (INR / ft²)'), '150');
      await reveal(tester, find.text('Save and use calculator'));
      await tester.tap(find.text('Save and use calculator'));
      await tester.pumpAndSettle();
      final profile = (await workspace.profiles()).single;
      final published = (await workspace.repository.activeCard(
        profile.id,
        at: DateTime.now(),
      ))!;
      expect(published.card.products.single.name, 'Basic flush door');
      expect(published.card.products.single.rule.tax.percent.toString(), '0');
      expect(published.version, 1);
      expect(find.text('QuickPrice'), findsOneWidget);
      final stockItem = inventory.products(testIdentity.uid).values.single;
      expect(stockItem.name, 'Basic flush door');
      expect(stockItem.quantity, 100);
      expect(stockItem.reorderLevel, 10);
      await tester.enterText(input('height'), '84');
      await tester.enterText(input('width'), '36');
      await tester.pumpAndSettle();
      expect(find.text('₹3,150.00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dependenciesProvider.overrideWithValue(
              connectedTestDependencies(
                auth,
                FakeProfiles(),
                inventory: inventory,
              ),
            ),
          ],
          child: HynerApp(workspace: Future.value(workspace)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Door prices'), findsOneWidget);
      expect(find.text('₹3,150.00'), findsOneWidget);
      expect(find.text('Create calculator'), findsNothing);
      await tester.tap(find.byTooltip('Calculator options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit selling rates'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Selling rate (INR / ft²)'), '200');
      await reveal(tester, find.text('Save and use calculator'));
      await tester.tap(find.text('Save and use calculator'));
      await tester.pumpAndSettle();
      expect((await workspace.profiles()).length, 1);
      expect(find.text('₹4,200.00'), findsOneWidget);
      final editor = (await workspace.values.read(
        'setup_${profile.id}_${published.card.products.single.id}',
      ))!;
      expect((editor['rates'] as List).first['amount'], '200');
      expect(
        (await workspace.repository.readVersion(
          profile.id,
          1,
        )).card.products.single.rule.rateLookup.rates.first.amount.toString(),
        '150',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid selling rate keeps setup editable and cannot publish', (
    tester,
  ) async {
    final workspace = ownerWorkspace();
    final auth = FakeAuth();
    addTearDown(auth.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dependenciesProvider.overrideWithValue(
            connectedTestDependencies(auth, FakeProfiles()),
          ),
        ],
        child: HynerApp(workspace: Future.value(workspace)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create calculator'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Selling rate (INR / ft²)'), '0');
    await reveal(tester, find.text('Save and use calculator'));
    await tester.tap(find.text('Save and use calculator'));
    await tester.pumpAndSettle();
    expect(await workspace.profiles(), isEmpty);
    final outer = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(outer).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.textContaining('greater than zero'), findsWidgets);
  });

  testWidgets('a same-name inventory item is linked without resetting stock', (
    tester,
  ) async {
    final workspace = ownerWorkspace();
    final auth = FakeAuth(user: testIdentity);
    final inventory = FakeInventory();
    addTearDown(auth.close);
    await inventory.create(
      testIdentity.uid,
      ProductDraft(
        sku: 'DOOR-EXISTING',
        name: 'Basic flush door',
        currency: 'INR',
        costMinor: 42000,
        priceMinor: 55000,
        openingStock: 17,
        reorderLevel: 3,
      ),
      'opening-door',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dependenciesProvider.overrideWithValue(
            connectedTestDependencies(
              auth,
              FakeProfiles(),
              inventory: inventory,
            ),
          ),
        ],
        child: HynerApp(workspace: Future.value(workspace)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create calculator'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Product name'), 'Basic flush door');
    await tester.enterText(field('Selling rate (INR / ft²)'), '150');
    await reveal(tester, find.text('Save and use calculator'));
    await tester.tap(find.text('Save and use calculator'));
    await tester.pumpAndSettle();

    final profile = (await workspace.profiles()).single;
    final linked = (await workspace.repository.readDraft(profile.id))
        .card
        .products
        .single;
    expect(linked.inventorySku, 'DOOR-EXISTING');
    expect(inventory.products(testIdentity.uid), hasLength(1));
    final preserved = inventory.products(testIdentity.uid).values.single;
    expect(preserved.quantity, 17);
    expect(preserved.reorderLevel, 10);
    expect(preserved.costMinor, 42000);
    expect(preserved.priceMinor, 15000);
    expect(tester.takeException(), isNull);
  });
}
