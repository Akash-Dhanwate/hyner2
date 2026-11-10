import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/main.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';

void main() {
  testWidgets('fresh workspace offers setup without inventing rates', (
    tester,
  ) async {
    await tester.pumpWidget(
      HynerApp(workspace: Future.value(createPreviewWorkspace())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create calculator'), findsOneWidget);
    expect(find.textContaining('No selling rates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
