import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/inventory/presentation/inventory_controller.dart';
import 'package:hyner/features/inventory/presentation/stock_adjustment_dialog.dart';

import 'support/inventory_fakes.dart';

final _accountProvider = NotifierProvider<_Account, String?>(_Account.new);

class _Account extends Notifier<String?> {
  @override
  String? build() => 'owner';
  void select(String? uid) => state = uid;
}

void main() {
  testWidgets(
    'an open stock-adjustment form is dismissed after an account switch without writing',
    (tester) async {
      final inventory = FakeInventory();
      final container = ProviderContainer(
        overrides: [
          inventoryUidProvider.overrideWith(
            (ref) => ref.watch(_accountProvider),
          ),
          inventoryRepositoryProvider.overrideWithValue(inventory),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => StockAdjustmentDialog(
                      uid: 'owner',
                      product: inventoryFixture(),
                    ),
                  ),
                  child: const Text('Adjust'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Adjust'));
      await tester.pumpAndSettle();
      expect(find.text('Adjust stock'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('adjustment-units')), '2');
      container.read(_accountProvider.notifier).select('other');
      await tester.pumpAndSettle();
      expect(find.text('Adjust stock'), findsNothing);
      expect(inventory.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
