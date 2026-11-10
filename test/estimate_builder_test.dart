import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/pricing_database.dart' show PricingDatabase;
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/application/estimate_builder.dart';
import 'package:hyner/features/pricing/application/product_setup.dart';
import 'package:hyner/features/pricing/application/workspace.dart';
import 'package:hyner/features/pricing/data/device_workspace.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart'
    show PricingCategory;
import 'package:hyner/features/pricing/domain/serialization.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';

import 'support/setup_fixture.dart' as f;

void main() {
  late CalculatorSession session;
  setUp(() => session = CalculatorSession(clock: () => f.now));
  tearDown(() => session.dispose());

  EstimateLine capture({
    String businessId = 'shop',
    String kind = 'area',
    String name = 'Flush door',
    String rate = '150',
    String height = '7',
    String width = '3',
    String quantity = '1',
    Currency? currency,
  }) {
    session.select(
      f
          .setup(kind, name: name, rate: rate)
          .compile(businessId, currency ?? f.currency),
    );
    if (kind == 'area') {
      session.change('height', 'text', height);
      session.change('width', 'text', width);
    }
    session.changeQuantity(quantity);
    return EstimateLine.capture(session: session, profileId: 'doors');
  }

  test('six rows keep varieties, dimensions, quantities and repeated products independent', () {
    final basic = f
        .setup('area', name: 'Basic door', rate: '100')
        .compile('shop', f.currency);
    final premium = f
        .setup('area', name: 'Premium door', rate: '200')
        .compile('shop', f.currency);
    final rules = [
      canonicalJson(basic.toJson()),
      canonicalJson(premium.toJson()),
    ];
    var estimate = QuickPriceEstimate.empty('shop');
    final rows = [
      (basic, '7', '3', '1', 210000),
      (premium, '7', '3', '2', 840000),
      (basic, '6', '2', '3', 360000),
      (premium, '8', '4', '1', 640000),
      (basic, '7', '3', '1', 210000),
      (premium, '6.5', '2.5', '4', 1300000),
    ];
    for (final (product, height, width, quantity, total) in rows) {
      session.select(product);
      session.change('height', 'text', height);
      session.change('width', 'text', width);
      session.changeQuantity(quantity);
      final line = EstimateLine.capture(session: session, profileId: 'doors');
      expect(line.pricing.totalMinor, total);
      estimate = estimate.append(line);
    }
    expect(estimate.lines.length, 6);
    expect(estimate.lines.map((line) => line.id).toSet().length, 6);
    expect(estimate.totalMinor, BigInt.from(3560000));
    expect(estimate.currency!.code, 'INR');
    expect(canonicalJson(basic.toJson()), rules[0]);
    expect(canonicalJson(premium.toJson()), rules[1]);
    final seed = estimate.toCheckoutSeed('owner');
    expect(seed.operationId, estimate.operationId);
    expect(seed.lines.map((line) => line.sku).toSet().length, 6);
    for (final line in seed.lines) {
      expect(line.stockTracked, isFalse);
      expect(line.unitCostMinor, 0);
      expect(line.sku, matches(r'^QP_[0-9A-F]{32}$'));
      expect(line.sku.length, lessThanOrEqualTo(40));
    }
    expect(
      seed.lines.fold(0, (sum, line) => sum + line.totalMinor),
      estimate.totalMinor.toInt(),
    );
    expect(estimate.toCheckoutSeed('owner').operationId, seed.operationId);
  });

  test(
    'snapshot survives a later publication and editing uses the captured rule',
    () async {
      final workspace = createPreviewWorkspace();
      final product = f
          .setup('area', rate: '100')
          .compile(workspace.businessId, f.currency);
      UniversalRateCardDraft card(UniversalProduct value) =>
          UniversalRateCardDraft(
            name: 'Doors',
            currency: f.currency,
            categories: [PricingCategory(id: value.categoryId, name: 'Doors')],
            products: [value],
          );
      await workspace.repository.createProfile('doors', card(product));
      await workspace.values.approve(product.rule.tax);
      final published = await workspace.repository.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: f.now,
      );
      session.select(published.card.products.single);
      session.change('height', 'text', '7');
      session.change('width', 'text', '3');
      final line = EstimateLine.capture(session: session, profileId: 'doors');
      final snapshot = canonicalJson(line.toJson());
      final changedJson = jsonObject(canonicalJson(product.toJson()));
      ((changedJson['rule'] as Map)['rates'] as List).first['amount'] = '900';
      await workspace.repository.saveDraft(
        'doors',
        card(UniversalProduct.fromJson(changedJson)),
        expectedRevision: 2,
      );
      await workspace.repository.publish(
        'doors',
        expectedRevision: 3,
        effectiveAt: f.now,
      );
      expect(canonicalJson(line.toJson()), snapshot);
      expect(line.pricing.totalMinor, 210000);
      final edit = CalculatorSession(clock: () => f.now)
        ..select(line.product)
        ..restore(line.calculatorState);
      addTearDown(edit.dispose);
      expect(edit.result!.amounts.totalMinor, BigInt.from(210000));
      expect(line.product.rule.version, 1);
    },
  );

  test('capture recomputes and rejects invalid edits rather than using a stale result', () {
    capture();
    session.entries['height']!['text'] = 'bad';
    expect(
      () => EstimateLine.capture(session: session, profileId: 'doors'),
      throwsStateError,
    );
    expect(
      () => EstimateLine.capture(session: session, profileId: ''),
      throwsArgumentError,
    );
  });

  test('fractional unit amounts round deterministically but exact line totals remain authoritative', () {
    final first = capture(kind: 'perUnit', rate: '0.335', quantity: '3');
    expect(first.pricing.totalMinor, 101);
    expect(first.pricing.unitPriceMinor, 34);
    expect(first.toSaleLine().totalMinor, 101);
    expect(first.toSaleLine().unitPriceMinor * 3, 102);
    final second = capture(kind: 'perUnit', rate: '0.335', quantity: '3');
    expect(second.pricing.totalMinor, first.pricing.totalMinor);
    final estimate = QuickPriceEstimate.empty('shop')
        .append(first)
        .append(second);
    expect(estimate.totalMinor, BigInt.from(202));
    expect(estimate.publicText(), contains('Unit amount (rounded): ₹0.34'));
    expect(estimate.publicText(), contains('Grand total: ₹2.02'));
  });

  test(
    'base-rate override is snapshotted without changing the stored product',
    () {
      final original = f.setup('area').compile('shop', f.currency);
      final before = canonicalJson(original.toJson());
      session.select(original);
      session.change('height', 'text', '7');
      session.change('width', 'text', '3');
      session.setBaseRateOverride('100.125');
      final line = EstimateLine.capture(session: session, profileId: 'doors');
      expect(line.pricing.totalMinor, 210263);
      expect(
        line.product.rule.rateLookup.rates.single.amount,
        Exact.parse('100.125'),
      );
      expect(canonicalJson(original.toJson()), before);
      final restored = EstimateLine.fromJson(
        jsonObject(canonicalJson(line.toJson())),
      );
      expect(restored.pricing.snapshotJson, line.pricing.snapshotJson);
      expect(restored.calculatorState['baseRateOverride'], '100.125');
    },
  );

  test('exact retained measurements survive a wider snapshot precision and restore', () {
    capture(height: '7.123456');
    final restricted = f.setup('area');
    for (final field in restricted.rows('fields')) {
      field['unit'] = 'm';
      field['permitted'] = ['m'];
      field['precision'] = '3';
    }
    session.select(restricted.compile('shop', f.currency));
    final total = session.result!.amounts.totalMinor;
    final line = EstimateLine.capture(session: session, profileId: 'doors');
    final restored = EstimateLine.fromJson(
      jsonObject(canonicalJson(line.toJson())),
    );
    expect(restored.pricing.result.amounts.totalMinor, total);
    final edit = CalculatorSession(clock: () => f.now)
      ..select(restored.product)
      ..restore(restored.calculatorState);
    addTearDown(edit.dispose);
    expect(edit.result!.amounts.totalMinor, total);
  });

  test(
    'switching to a product without length fields still captures correctly',
    () {
      capture();
      final line = capture(kind: 'perUnit', rate: '20');
      expect(line.pricing.totalMinor, 2000);
      expect(line.calculatorState['linkedUnit'], isNull);
    },
  );

  test('replace, duplicate, remove and reorder return immutable independent revisions', () {
    final first = capture();
    final second = capture(name: 'Premium', rate: '200');
    final original = QuickPriceEstimate.empty('shop')
        .append(first)
        .append(second);
    final replacement = capture(height: '6', quantity: '2');
    final edited = original.replace(first.id, replacement);
    expect(edited.lines.first.id, first.id);
    expect(edited.lines.first.toSaleLine().sku, first.toSaleLine().sku);
    expect(original.lines.first.pricing.quantity, 1);
    expect(edited.lines.first.pricing.quantity, 2);
    final duplicated = edited.duplicate(first.id);
    expect(duplicated.lines[1].id, isNot(first.id));
    expect(
      duplicated.lines[1].pricing.snapshotJson,
      edited.lines.first.pricing.snapshotJson,
    );
    final reordered = duplicated.reorder(0, 3);
    expect(reordered.lines.last.id, first.id);
    final removed = reordered.remove(first.id);
    expect(removed.lines.length, 2);
    expect(original.lines.length, 2);
    expect(removed.revision, original.revision + 4);
    expect(removed.id, original.id);
    expect(removed.createdAt, original.createdAt);
    expect(removed.updatedAt.isBefore(original.updatedAt), isFalse);
    expect(() => original.lines.clear(), throwsUnsupportedError);
    expect(
      () => first.calculatorState['quantity'] = '100',
      throwsUnsupportedError,
    );
    expect(
      () => (first.calculatorState['entries'] as Map).clear(),
      throwsUnsupportedError,
    );
    expect(() => first.parameters.clear(), throwsUnsupportedError);
    expect(() => original.remove('missing'), throwsArgumentError);
    expect(() => original.reorder(-1, 2), throwsArgumentError);
    expect(() => original.reorder(0, 3), throwsArgumentError);
  });

  test(
    'converted estimates persist their identity and prohibit every edit',
    () {
      final line = capture();
      final estimate = QuickPriceEstimate.empty('shop').append(line);
      final converted = estimate.markConverted('sale-123');
      expect(converted.convertedSaleId, 'sale-123');
      expect(converted.operationId, estimate.operationId);
      expect(converted.markConverted('sale-123'), same(converted));
      expect(() => converted.append(line), throwsStateError);
      expect(() => converted.replace(line.id, line), throwsStateError);
      expect(() => converted.remove(line.id), throwsStateError);
      expect(() => converted.duplicate(line.id), throwsStateError);
      expect(() => converted.reorder(0, 0), throwsStateError);
      expect(() => converted.markConverted('another-sale'), throwsStateError);
      expect(() => converted.toCheckoutSeed('owner'), throwsStateError);
      expect(
        QuickPriceEstimate.empty('shop').operationId,
        isNot(estimate.operationId),
      );
      expect(
        () => QuickPriceEstimate.empty('shop').toCheckoutSeed('owner'),
        throwsStateError,
      );
    },
  );

  test('business, currency, duplicate IDs, money and row count limits are enforced', () {
    final line = capture();
    final estimate = QuickPriceEstimate.empty('shop').append(line);
    expect(() => estimate.append(line), throwsArgumentError);
    expect(
      () => estimate.append(capture(businessId: 'other')),
      throwsArgumentError,
    );
    expect(
      () => estimate.append(capture(currency: Currency('USD', 2))),
      throwsArgumentError,
    );
    expect(() => capture(currency: Currency('JPY', 0)), throwsA(anything));
    final large = capture(kind: 'perUnit', rate: '6000000000');
    expect(
      () => QuickPriceEstimate.empty('shop').append(large).duplicate(large.id),
      throwsArgumentError,
    );
    var full = QuickPriceEstimate.empty('shop')
        .append(capture(kind: 'perUnit', rate: '0'));
    for (var i = 1; i < 100; i++) {
      full = full.duplicate(full.lines.last.id);
    }
    expect(full.lines.length, 100);
    expect(() => full.duplicate(full.lines.last.id), throwsArgumentError);
  });

  test('public specifications include dimensions, choices, attributes, billing, extras and tax without private values', () {
    final draft = f.setup('area', name: 'Customer door', rate: '100');
    draft.data['taxBehavior'] = 'exclusive';
    draft.data['taxPercent'] = '18';
    draft.data['discountPercent'] = '10';
    draft.data['minimum'] = '25';
    draft.rows('fields').first['billIncrement'] = '1';
    draft.rows('fields').addAll([
      inputDraft('finish', 'Finish', 'number')..addAll({
        'type': 'choice',
        'choices': 'Matte,Gloss',
        'default': 'Matte',
      }),
      inputDraft('supplier_cost', 'Supplier cost', 'kg')
        ..['default'] = '812.345',
      inputDraft('internal_notes', 'Internal notes', 'number')..addAll({
        'type': 'choice',
        'choices': 'Confidential',
        'default': 'Confidential',
      }),
      inputDraft('ratio', 'Ratio', 'number')..['default'] = '0.123',
    ]);
    draft
        .rows('extras')
        .add(
          ProductSetup.componentDraft()
            ..addAll({'name': 'Delivery', 'amount': '25', 'type': 'perOrder'}),
        );
    final base = draft.compile('shop', f.currency);
    final product = UniversalProduct(
      categoryId: base.categoryId,
      name: base.name,
      rule: base.rule,
      attributes: {
        'Material': 'Plywood',
        'private_cost_notes': 'Secret ledger',
      },
    );
    session.select(product);
    session.change('height', 'text', '6.5');
    session.change('width', 'text', '3');
    final line = EstimateLine.capture(session: session, profileId: 'doors');
    final specs = {
      for (final parameter in line.parameters) parameter.name: parameter.value,
    };
    expect(specs['Height'], '6.5 ft');
    expect(specs['Height billed'], '7 ft');
    expect(specs['Finish'], 'Matte');
    expect(specs['Material'], 'Plywood');
    expect(specs['Measured'], '21 ft²');
    expect(specs['Billed'], '25 ft²');
    expect(specs['Extras'], 'Delivery');
    expect(specs['Discount'], isNotNull);
    expect(specs['Tax'], contains('18% exclusive'));
    final estimate = QuickPriceEstimate.empty('shop').append(line);
    final text = estimate.publicText();
    expect(text, contains('Customer door'));
    expect(text, contains('Quantity: 1'));
    expect(
      text,
      contains('Grand total: ${moneyText(estimate.totalMinor, f.currency)}'),
    );
    expect(text, contains('Excluding tax: '));
    expect(
      text,
      contains(
        '\nTax: ${moneyText(BigInt.from(line.pricing.taxMinor), f.currency)}\nGrand total: ',
      ),
    );
    for (final forbidden in [
      '812.345',
      'Confidential',
      'Secret ledger',
      'Ratio',
      'supplier_cost',
      'internal_notes',
      'ruleVersion',
      'businessId',
      'rates',
      draft.id,
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('exempt zero-tax quotes omit tax specifications and redundant share footers', () {
    final line = capture();
    expect(
      line.parameters.any((parameter) => parameter.name == 'Tax'),
      isFalse,
    );
    final estimate = QuickPriceEstimate.empty('shop').append(line);
    final text = estimate.publicText();
    expect(text, isNot(contains('Tax:')));
    expect(text, isNot(contains('Excluding tax:')));
    expect(text, contains('Grand total: ₹3,150.00'));
    final restored = QuickPriceEstimate.fromJson(
      jsonObject(canonicalJson(estimate.toJson())),
      businessId: 'shop',
    );
    expect(restored.publicText(), text);
  });

  test(
    'nonexempt zero tax retains its explicit percentage and line amount',
    () {
      final draft = f.setup('perUnit');
      draft.data['taxBehavior'] = 'exclusive';
      draft.data['taxPercent'] = '0';
      session.select(draft.compile('shop', f.currency));
      final line = EstimateLine.capture(session: session, profileId: 'doors');
      expect(
        line.parameters
            .singleWhere((parameter) => parameter.name == 'Tax')
            .value,
        '0% exclusive (₹0.00)',
      );
      final text = QuickPriceEstimate.empty('shop').append(line).publicText();
      expect(text, contains('Tax: 0% exclusive (₹0.00)'));
      expect(text, isNot(contains('Excluding tax:')));
      expect(text, isNot(contains('\nTax: ₹0.00\nGrand total:')));
    },
  );

  test('matching input and attribute specifications deduplicate while differing variants retain both values', () {
    final draft = f.setup('area');
    draft
        .rows('fields')
        .add(
          inputDraft('finish', 'Finish', 'number')..addAll({
            'type': 'choice',
            'choices': 'Matte,Gloss',
            'default': 'Matte',
          }),
        );
    final base = draft.compile('shop', f.currency);
    EstimateLine variant(String finish) {
      session.select(
        UniversalProduct(
          categoryId: base.categoryId,
          name: base.name,
          rule: base.rule,
          attributes: {
            'finish': finish,
            'Height': '7 ft',
            'Wood': 'Oak',
            'Grade': 'A',
          },
        ),
      );
      session.change('height', 'text', '7');
      session.change('width', 'text', '3');
      return EstimateLine.capture(session: session, profileId: 'doors');
    }

    final matching = variant('Matte');
    expect(matching.parameters.map((parameter) => parameter.name).toList(), [
      'Height',
      'Width',
      'Finish',
      'Grade',
      'Wood',
    ]);
    expect(
      matching.parameters
          .singleWhere((parameter) => parameter.name == 'Finish')
          .value,
      'Matte',
    );
    final differing = variant('Gloss');
    final specs = {
      for (final parameter in differing.parameters)
        parameter.name: parameter.value,
    };
    expect(specs['Finish'], 'Matte');
    expect(specs['Variant finish'], 'Gloss');
    expect(
      differing.parameters
          .where((parameter) => parameter.name == 'Height')
          .length,
      1,
    );
    final restored = EstimateLine.fromJson(
      jsonObject(canonicalJson(differing.toJson())),
    );
    expect(
      restored.parameters.map((parameter) => parameter.toMap()).toList(),
      differing.parameters.map((parameter) => parameter.toMap()).toList(),
    );
  });

  test(
    'oversized customer specifications fail clearly instead of being truncated',
    () {
      final draft = f.setup('perUnit');
      for (var i = 0; i < 21; i++) {
        draft
            .rows('fields')
            .add(
              inputDraft('option_$i', 'Option $i', 'number')..addAll({
                'type': 'choice',
                'choices': 'Yes,No',
                'default': 'Yes',
              }),
            );
      }
      session.select(draft.compile('shop', f.currency));
      expect(
        () => EstimateLine.capture(session: session, profileId: 'doors'),
        throwsArgumentError,
      );
      final oversized = f.setup('perUnit');
      oversized
          .rows('fields')
          .add(
            inputDraft('finish', 'F' * 61, 'number')..addAll({
              'type': 'choice',
              'choices': 'Yes,No',
              'default': 'Yes',
            }),
          );
      session.select(oversized.compile('shop', f.currency));
      expect(
        () => EstimateLine.capture(session: session, profileId: 'doors'),
        throwsArgumentError,
      );
    },
  );

  test(
    'JSON round trip verifies snapshots, state and derived specifications',
    () {
      final estimate = QuickPriceEstimate.empty('shop')
          .append(capture(quantity: '3'));
      final json = jsonObject(canonicalJson(estimate.toJson()));
      final restored = QuickPriceEstimate.fromJson(json, businessId: 'shop');
      expect(
        canonicalJson(restored.toJson()),
        canonicalJson(estimate.toJson()),
      );
      expect(restored.publicText(), estimate.publicText());
      expect(
        () => QuickPriceEstimate.fromJson(json, businessId: 'other'),
        throwsFormatException,
      );
      void tamper(void Function(Map<String, dynamic>) change) {
        final changed = jsonObject(canonicalJson(json));
        change(changed);
        expect(
          () => QuickPriceEstimate.fromJson(changed, businessId: 'shop'),
          throwsA(anything),
        );
      }

      tamper((map) => map['schemaVersion'] = 99);
      tamper((map) => map['revision'] = -1);
      tamper((map) => map['updatedAt'] = '2000-01-01T00:00:00Z');
      tamper((map) => map['id'] = 'bad');
      tamper((map) => map['privateNotes'] = 'Injected');
      tamper(
        (map) =>
            ((map['lines'] as List).first['parameters'] as List)
                    .first['value'] =
                'Injected cost',
      );
      tamper(
        (map) =>
            (map['lines'] as List).first['calculatorState']['quantity'] = '9',
      );
      tamper(
        (map) =>
            (map['lines'] as List).first['pricing']['amounts']['totalMinor'] =
                '1',
      );
      tamper(
        (map) =>
            (map['lines'] as List)
                    .first['product']['rule']['currency']['code'] =
                'USD',
      );
      tamper(
        (map) =>
            (map['lines'] as List)
                    .first['calculatorState']['entries']['height']['text'] =
                '9',
      );
    },
  );

  test('memory workspace reopens one active estimate and retains converted records until a new estimate', () async {
    final workspace = createPreviewWorkspace();
    var repository = EstimateRepository(workspace);
    final fresh = await repository.load();
    expect(fresh.lines, isEmpty);
    expect(fresh.currency, isNull);
    final estimate = fresh.append(capture(businessId: workspace.businessId));
    final snapshot = canonicalJson(estimate.toJson());
    await repository.save(estimate);
    final reopened = QuickPriceWorkspace(
      businessId: workspace.businessId,
      repository: workspace.repository,
      values: workspace.values,
    );
    repository = EstimateRepository(reopened);
    expect(canonicalJson((await repository.load()).toJson()), snapshot);
    final converted = estimate.markConverted('saved-bill');
    await repository.save(converted);
    repository = EstimateRepository(reopened);
    expect((await repository.load()).convertedSaleId, 'saved-bill');
    await expectLater(repository.save(estimate), throwsStateError);
    final next = QuickPriceEstimate.empty(workspace.businessId);
    await repository.save(next);
    expect((await repository.load()).id, next.id);
    expect((await repository.load()).lines, isEmpty);
  });

  test(
    'malformed persisted values are reported and preserved, including on save',
    () async {
      final workspace = createPreviewWorkspace();
      final repository = EstimateRepository(workspace);
      final malformed = {
        'schemaVersion': 999,
        'businessId': workspace.businessId,
      };
      await workspace.values.write('estimate', malformed);
      await expectLater(repository.load(), throwsFormatException);
      expect(await workspace.values.read('estimate'), malformed);
      await expectLater(
        repository.save(QuickPriceEstimate.empty(workspace.businessId)),
        throwsFormatException,
      );
      expect(await workspace.values.read('estimate'), malformed);
    },
  );

  test('serialized saves preserve order, reject foreign/stale records, and recover after write failure', () async {
    final source = createPreviewWorkspace();
    final values = _FailOnceValues();
    final workspace = QuickPriceWorkspace(
      businessId: source.businessId,
      repository: source.repository,
      values: values,
    );
    final repository = EstimateRepository(workspace);
    final first = QuickPriceEstimate.empty(workspace.businessId)
        .append(capture(businessId: workspace.businessId));
    final second = first.duplicate(first.lines.single.id);
    values.failNext = true;
    final failed = repository.save(first);
    final successful = repository.save(second);
    await expectLater(failed, throwsStateError);
    await successful;
    expect((await repository.load()).revision, second.revision);
    await expectLater(repository.save(first), throwsStateError);
    expect(
      () => repository.save(QuickPriceEstimate.empty('other')),
      throwsArgumentError,
    );
    expect((await repository.load()).businessId, workspace.businessId);
    expect(
      () => validateWorkspaceValue({'tooLarge': 'x' * (1024 * 1024)}),
      throwsArgumentError,
    );
  });

  test('SQLite workspace restart preserves the full quote and business isolation', () async {
    final directory = await Directory.systemTemp.createTemp('hyner-estimate-');
    final file = File('${directory.path}/prices.sqlite');
    QuickPriceWorkspace? workspace;
    try {
      var db = PricingDatabase(NativeDatabase(file));
      workspace = await openDeviceWorkspace(db);
      final business = workspace.businessId;
      final estimate = QuickPriceEstimate.empty(business)
          .append(capture(businessId: business));
      await EstimateRepository(workspace).save(estimate);
      await workspace.close();
      workspace = null;
      db = PricingDatabase(NativeDatabase(file));
      workspace = await openDeviceWorkspace(db);
      final restored = await EstimateRepository(workspace).load();
      expect(workspace.businessId, business);
      expect(
        canonicalJson(restored.toJson()),
        canonicalJson(estimate.toJson()),
      );
      final foreign = DeviceWorkspaceValues(db, 'foreign-business');
      expect(await foreign.read('estimate'), isNull);
      // A device database has one workspace singleton. Use a real second
      // workspace to exercise wrong-business records without violating its FK.
      final foreignWorkspace = await openDeviceWorkspace(
        PricingDatabase(NativeDatabase.memory()),
      );
      try {
        expect(foreignWorkspace.businessId, isNot(business));
        expect(
          (await EstimateRepository(foreignWorkspace).load()).lines,
          isEmpty,
        );
        await foreignWorkspace.values.write('estimate', estimate.toJson());
        await expectLater(
          EstimateRepository(foreignWorkspace).load(),
          throwsFormatException,
        );
        expect(
          (await foreignWorkspace.values.read('estimate'))!['id'],
          estimate.id,
        );
      } finally {
        await foreignWorkspace.close();
      }
      expect((await EstimateRepository(workspace).load()).id, estimate.id);
    } finally {
      await workspace?.close();
      await directory.delete(recursive: true);
    }
  });
}

class _FailOnceValues extends PreviewValues {
  bool failNext = false;
  @override
  Future<void> write(String key, Map<String, dynamic>? value) async {
    if (failNext) {
      failNext = false;
      throw StateError('Simulated disk failure');
    }
    await super.write(key, value);
  }
}
