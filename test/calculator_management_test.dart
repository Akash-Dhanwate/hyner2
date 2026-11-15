import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';
import 'package:hyner/features/pricing/presentation/rate_cards_screen.dart';

void main() {
  testWidgets('calculator can be renamed and safely removed from active list', (
    tester,
  ) async {
    final workspace = createPreviewWorkspace();
    await workspace.repository.createProfile(
      'calculator-one',
      UniversalRateCardDraft(name: 'Door prices', currency: Currency('INR', 2)),
    );

    await tester.pumpWidget(
      MaterialApp(home: RateCardsScreen(workspace: workspace)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calculator options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename calculator'));
    await tester.pumpAndSettle();
    final nameField = find.byKey(const Key('rename-calculator-name'));
    await tester.enterText(nameField, 'PVC doors');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-calculator-name')));
    await tester.pumpAndSettle();

    expect(find.text('PVC doors'), findsOneWidget);
    expect((await workspace.profiles()).single.name, 'PVC doors');

    await tester.tap(find.byTooltip('Calculator options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete calculator'));
    await tester.pumpAndSettle();
    expect(find.text('Delete calculator?'), findsOneWidget);
    expect(
      find.textContaining('retained as archived pricing history'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete calculator').last);
    await tester.pumpAndSettle();

    expect(find.text('PVC doors'), findsNothing);
    expect((await workspace.profiles()).single.status, 'archived');
    expect(
      find.textContaining('No selling rates are configured yet.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
