import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/accounting/presentation/accounting_screen.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/customers/presentation/customers_controller.dart';
import 'package:hyner/features/expenses/domain/expense_repository.dart';
import 'package:hyner/features/expenses/domain/operating_expense.dart';
import 'package:hyner/features/expenses/presentation/expenses_controller.dart';
import 'package:hyner/features/expenses/presentation/expenses_screen.dart';
import 'package:hyner/features/inventory/presentation/inventory_controller.dart';
import 'package:hyner/features/purchase_orders/presentation/purchase_orders_screen.dart';
import 'package:hyner/features/quotations/presentation/quotations_screen.dart';
import 'package:hyner/features/sales/presentation/sales_controller.dart';
import 'package:hyner/features/whatsapp/presentation/whatsapp_screen.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/core/storage/business_database_provider.dart';

final _accountProvider = NotifierProvider<_Account, String?>(_Account.new);

class _Account extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? uid) => state = uid;
}

// Only the storage boundary is faked: tests inspect the payloads supplied by UI.
class _Database extends Fake implements Database {
  final tables = <String, List<Map<String, Object?>>>{};
  Object? readError, writeError;
  Completer<void>? pendingWrite;
  int writes = 0;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (readError != null) throw readError!;
    return List.of(tables[table] ?? []);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (readError != null) throw readError!;
    if (!sql.contains('FROM quotations')) throw UnimplementedError(sql);
    return List.of(tables['quotations'] ?? []);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
    if (writeError != null) throw writeError!;
    tables.putIfAbsent(table, () => []).add(Map.of(values));
    return writes;
  }
}

class _Factory extends Fake implements DatabaseFactory {
  final databases = <String, _Database>{};

  _Database forUid(String uid) {
    final key = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return databases.putIfAbsent(
      '/ui-tests/hyner_register_$key.db',
      _Database.new,
    );
  }

  @override
  Future<String> getDatabasesPath() async => '/ui-tests';

  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async => databases.putIfAbsent(path, _Database.new);
}

class _Expenses extends Fake implements ExpenseRepository {
  final created = <(String, OperatingExpenseDraft)>[];
  final deleted = <(String, String)>[];
  Completer<void>? pending;
  Object? failure;

  @override
  String newId() => 'expense-${created.length}';

  @override
  Future<List<OperatingExpense>> list(String uid, {String? currency}) async =>
      [];

  @override
  Future<OperatingExpense> create(
    String uid,
    String id,
    OperatingExpenseDraft draft,
  ) async {
    created.add((uid, draft));
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    return OperatingExpense(
      id: id,
      category: draft.category,
      description: draft.description,
      currency: draft.currency,
      amountMinor: draft.amountMinor,
      occurredAt: draft.occurredAt,
    );
  }

  @override
  Future<void> delete(String uid, String id) async {
    deleted.add((uid, id));
    if (failure != null) throw failure!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Factory factory;
  late ProviderContainer container;
  late String uid;
  var sequence = 0;

  setUpAll(() {
    factory = _Factory();
  });
  setUp(() {
    uid = 'business-ui-${++sequence}';
    container = ProviderContainer(
      overrides: [
        businessDatabaseProvider.overrideWithValue(
          LocalBusinessDatabase(factory: factory, directory: '/ui-tests'),
        ),
        inventoryUidProvider.overrideWith((ref) => ref.watch(_accountProvider)),
      ],
    );
    container.read(_accountProvider.notifier).select(uid);
  });
  tearDown(() => container.dispose());

  Future<void> mount(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: screen)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  const modules = [
    (
      screen: QuotationsScreen(),
      table: 'quotations',
      add: 'New quotation',
      name: 'Customer name',
      amount: 'Subtotal (INR)',
      empty: 'No quotations yet.',
    ),
    (
      screen: PurchaseOrdersScreen(),
      table: 'purchase_orders',
      add: 'New purchase order',
      name: 'Supplier name',
      amount: 'Expected total (INR)',
      empty: 'No purchase orders yet.',
    ),
    (
      screen: AccountingScreen(),
      table: 'accounting_entries',
      add: 'Add accounting entry',
      name: 'Description',
      amount: 'Amount (INR)',
      empty: 'No manual accounting entries recorded yet.',
    ),
  ];

  Future<void> fill(WidgetTester tester, int index) async {
    final module = modules[index];
    await enter(tester, module.name, 'Test entry');
    if (index < 2) await enter(tester, 'Items or scope', 'Consultation');
    await enter(tester, module.amount, '12.50');
    if (index == 0) await enter(tester, 'Tax rate (%)', '18');
    if (index == 2) await enter(tester, 'Tax (INR)', '0.50');
  }

  for (var i = 0; i < modules.length; i++) {
    final module = modules[i];
    testWidgets(
      '${module.table}: read error stops spinner and retry recovers',
      (tester) async {
        final db = factory.forUid(uid)..readError = StateError('read failed');
        await mount(tester, module.screen);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.textContaining('could not be loaded'), findsOneWidget);
        db.readError = null;
        await tap(tester, 'Try again');
        expect(find.text(module.empty), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${module.table}: decimal amounts persist once despite rapid Save taps',
      (tester) async {
        final db = factory.forUid(uid)..pendingWrite = Completer<void>();
        await mount(tester, module.screen);
        await tap(tester, module.add);
        await fill(tester, i);
        final save = find.widgetWithText(FilledButton, 'Save');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(db.writes, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, module.add),
              )
              .onPressed,
          isNull,
        );
        db.pendingWrite!.complete();
        await tester.pumpAndSettle();
        final row = db.tables[module.table]!.single;
        expect(
          row[i == 0
              ? 'subtotalMinor'
              : i == 1
              ? 'totalMinor'
              : 'amountMinor'],
          1250,
        );
        if (i == 0) {
          expect(row['taxRateBasisPoints'], 1800);
          expect(row['taxMinor'], 225);
          expect(row['totalMinor'], 1475);
        }
        if (i == 2) expect(row['taxMinor'], 50);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${module.table}: write failure is shown and action unlocks', (
      tester,
    ) async {
      final db = factory.forUid(uid)
        ..writeError = const AppFailure(
          FailureKind.permission,
          'Storage is read only.',
        );
      await mount(tester, module.screen);
      await tap(tester, module.add);
      await fill(tester, i);
      await tap(tester, 'Save');
      expect(find.text('Storage is read only.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, module.add))
            .onPressed,
        isNotNull,
      );
      expect(db.tables[module.table], isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '${module.table}: account switch cancels an open draft and replaces rows',
      (tester) async {
        final oldDb = factory.forUid(uid);
        await mount(tester, module.screen);
        await tap(tester, module.add);
        await fill(tester, i);
        final nextUid = '$uid-next';
        container.read(_accountProvider.notifier).select(nextUid);
        await tester.pumpAndSettle();
        await tap(tester, 'Save');
        expect(oldDb.writes, 0);
        expect(factory.forUid(nextUid).writes, 0);
        expect(find.text(module.empty), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${module.table}: invalid decimal shows feedback without closing dialog',
      (tester) async {
        await mount(tester, module.screen);
        await tap(tester, module.add);
        await fill(tester, i);
        await enter(tester, module.amount, '12.345');
        await tap(tester, 'Save');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('up to 2 decimal places'), findsOneWidget);
        expect(factory.forUid(uid).writes, 0);
      },
    );
  }

  test(
    'quotation tax rounds deterministically half up, including maximum values',
    () {
      expect(quotationTaxMinor(1, 4999), 0);
      expect(quotationTaxMinor(1, 5000), 1);
      expect(quotationTaxMinor(3, 5000), 2);
      expect(quotationTaxMinor(1250, 1800), 225);
      expect(quotationTaxMinor(999999999999, 9999), 999899999999);
      expect(quotationTaxMinor(999999999999, 10000), 999999999999);
    },
  );

  testWidgets('expense draft stays with its original account', (tester) async {
    final repository = _Expenses();
    container.dispose();
    container = ProviderContainer(
      overrides: [
        businessDatabaseProvider.overrideWithValue(
          LocalBusinessDatabase(factory: factory, directory: '/ui-tests'),
        ),
        inventoryUidProvider.overrideWith((ref) => ref.watch(_accountProvider)),
        expenseRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.read(_accountProvider.notifier).select(uid);
    await mount(tester, const ExpensesScreen());
    await tap(tester, 'Record expense');
    await enter(tester, 'Description', 'Rent');
    await enter(tester, 'Amount (INR)', '12.50');
    container.read(_accountProvider.notifier).select('$uid-next');
    await tester.pumpAndSettle();
    await tap(tester, 'Save expense');
    expect(repository.created, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expense pending save rejects repeated actions and failure unlocks',
    (tester) async {
      final repository = _Expenses()
        ..pending = Completer<void>()
        ..failure = const AppFailure(
          FailureKind.permission,
          'Expense write failed.',
        );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          inventoryUidProvider.overrideWith(
            (ref) => ref.watch(_accountProvider),
          ),
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.read(_accountProvider.notifier).select(uid);
      await mount(tester, const ExpensesScreen());
      await tap(tester, 'Record expense');
      await enter(tester, 'Description', 'Rent');
      await enter(tester, 'Amount (INR)', '12.50');
      await tap(tester, 'Save expense');
      expect(repository.created.single.$1, uid);
      expect(repository.created.single.$2.amountMinor, 1250);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Record expense'),
            )
            .onPressed,
        isNull,
      );
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Expense write failed.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Record expense'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  Customer customer(String id) => Customer(
    id: id,
    name: id,
    phone: '919876543210',
    notes: '',
    whatsappOptIn: true,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  void configureWhatsApp() {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        businessDatabaseProvider.overrideWithValue(
          LocalBusinessDatabase(factory: factory, directory: '/ui-tests'),
        ),
        inventoryUidProvider.overrideWith((ref) => ref.watch(_accountProvider)),
        customersProvider.overrideWith(
          (ref) async => ref.watch(inventoryUidProvider) == uid
              ? [customer('Alice'), customer('Bob')]
              : [],
        ),
        whatsAppProductsProvider.overrideWith((ref) async => []),
        scheduledFollowUpsProvider.overrideWith((ref) async => []),
      ],
    );
    container.read(_accountProvider.notifier).select(uid);
  }

  const channel = MethodChannel('hyner/whatsapp');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('WhatsApp missing native channel is recoverable', (tester) async {
    configureWhatsApp();
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException('Not registered'),
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await mount(tester, const WhatsAppScreen());
    await enter(
      tester,
      'Message (optional with a product selected)',
      'New stock',
    );
    await tap(tester, 'Open WhatsApp for 2 selected');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(
      find.text('WhatsApp chat is available in the Android app.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Open WhatsApp for 2 selected'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'WhatsApp in-flight callback cannot restore a previous account queue',
    (tester) async {
      configureWhatsApp();
      final pending = Completer<void>();
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        await pending.future;
        throw PlatformException(
          code: 'unavailable',
          message: 'Old account error',
        );
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await mount(tester, const WhatsAppScreen());
      await enter(
        tester,
        'Message (optional with a product selected)',
        'New stock',
      );
      await tap(tester, 'Open WhatsApp for 2 selected');
      expect(calls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open WhatsApp for 2 selected'),
            )
            .onPressed,
        isNull,
      );
      container.read(_accountProvider.notifier).select('$uid-next');
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Old account error'), findsNothing);
      expect(find.textContaining('Open next:'), findsNothing);
      expect(find.text('Open WhatsApp for 0 selected'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(
                TextField,
                'Message (optional with a product selected)',
              ),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('WhatsApp error after disposal does not call setState', (
    tester,
  ) async {
    configureWhatsApp();
    final pending = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      await pending.future;
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await mount(tester, const WhatsAppScreen());
    await enter(
      tester,
      'Message (optional with a product selected)',
      'New stock',
    );
    await tap(tester, 'Open WhatsApp for 2 selected');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
