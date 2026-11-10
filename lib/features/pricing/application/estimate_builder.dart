import '../../inventory/domain/product.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_checkout_seed.dart';
import '../../sales/domain/sale_price_snapshot.dart';
import '../domain/exact.dart';
import '../domain/pricing_models.dart' show TaxBehavior, validateId;
import '../domain/serialization.dart';
import '../domain/universal/rate_card.dart';
import '../domain/universal/universal_pricing.dart';
import 'calculator_session.dart';
import 'product_setup.dart' show unitShort;
import 'workspace.dart';

/// One independent, replayable custom quote. No inventory identity is implied.
final class EstimateLine {
  EstimateLine._({
    required this.id,
    required this.profileId,
    required UniversalProduct product,
    required Map<String, dynamic> calculatorState,
    required List<ProductParameter> parameters,
    required this.pricing,
  }) : _productJson = canonicalJson(product.toJson()),
       _calculatorJson = canonicalJson(calculatorState),
       parameters = List.unmodifiable(parameters);

  factory EstimateLine.capture({
    required CalculatorSession session,
    required String profileId,
  }) {
    validateId(profileId);
    session.recalculate();
    final result = session.result;
    if (result == null || session.product == null) {
      throw StateError(
        session.error ?? 'Complete the calculation before adding it.',
      );
    }
    final pricing = SalePriceSnapshot.fromResult(result);
    final product = session.product!.withRule(pricing.result.rule);
    final state = jsonObject(canonicalJson(session.toJson()));
    // A retained exact source may require a wider calculation precision than
    // the original editor. Save its projection at the snapshot's precision.
    _projectSources(product, state);
    final restored = _restore(product, state, pricing);
    try {
      final line = EstimateLine._(
        id: newPricingId(),
        profileId: profileId,
        product: product,
        calculatorState: restored.toJson(),
        parameters: _publicParameters(product, pricing),
        pricing: pricing,
      );
      line.toSaleLine().validate();
      return line;
    } finally {
      restored.dispose();
    }
  }

  final String id, profileId;
  final String _productJson, _calculatorJson;
  final List<ProductParameter> parameters;
  final SalePriceSnapshot pricing;

  // Return detached models so editing a row cannot mutate its saved quote.
  UniversalProduct get product =>
      UniversalProduct.fromJson(jsonObject(_productJson));
  Map<String, dynamic> get calculatorState =>
      _freezeMap(jsonObject(_calculatorJson));

  SaleLine toSaleLine() => SaleLine(
    sku: 'QP_${id.toUpperCase()}',
    name: product.name,
    unitPriceMinor: pricing.unitPriceMinor,
    quantity: pricing.quantity,
    parameters: parameters,
    pricing: pricing,
  );

  EstimateLine _withId(String value) => EstimateLine._(
    id: value,
    profileId: profileId,
    product: product,
    calculatorState: calculatorState,
    parameters: parameters,
    pricing: SalePriceSnapshot.fromJson(pricing.toJson()),
  );

  Map<String, dynamic> toJson() {
    pricing.validate();
    return {
      'id': id,
      'profileId': profileId,
      'product': jsonObject(_productJson),
      'calculatorState': jsonObject(_calculatorJson),
      'parameters': [for (final parameter in parameters) parameter.toMap()],
      'pricing': pricing.toJson(),
    };
  }

  factory EstimateLine.fromJson(Map<String, dynamic> json) {
    try {
      validateWorkspaceValue(json);
      _keys(json, {
        'id',
        'profileId',
        'product',
        'calculatorState',
        'parameters',
        'pricing',
      });
      final id = json['id'] as String;
      _estimateId(id);
      final profileId = json['profileId'] as String;
      validateId(profileId);
      final pricing = SalePriceSnapshot.fromJson(
        json['pricing'] as Map<String, dynamic>,
      );
      final product = UniversalProduct.fromJson(
        json['product'] as Map<String, dynamic>,
      );
      if (canonicalJson(product.rule.toJson()) !=
          canonicalJson(pricing.result.rule.toJson())) {
        throw const FormatException('Product and saved pricing rule differ.');
      }
      final state = json['calculatorState'] as Map<String, dynamic>;
      final restored = _restore(product, state, pricing);
      restored.dispose();
      final rawParameters = json['parameters'] as List;
      if (rawParameters.length > 20) {
        throw const FormatException('Too many specifications.');
      }
      final parameters = rawParameters.map((p) {
        final map = p as Map<String, dynamic>;
        _keys(map, {'name', 'value'});
        return ProductParameter.fromMap(map);
      }).toList();
      final expected = _publicParameters(product, pricing);
      if (canonicalJson(parameters.map((p) => p.toMap()).toList()) !=
          canonicalJson(expected.map((p) => p.toMap()).toList())) {
        throw const FormatException(
          'Specifications do not match the saved calculation.',
        );
      }
      final line = EstimateLine._(
        id: id,
        profileId: profileId,
        product: product,
        calculatorState: state,
        parameters: expected,
        pricing: pricing,
      );
      line.toSaleLine().validate();
      return line;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'This estimate line is invalid. Recalculate the item.',
      );
    }
  }
}

/// One active estimate per business, preserved after conversion until replaced
/// explicitly with [QuickPriceEstimate.empty]. Saved bills remain independent.
final class QuickPriceEstimate {
  QuickPriceEstimate._({
    required this.id,
    required this.businessId,
    required List<EstimateLine> lines,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.convertedSaleId,
  }) : lines = List.unmodifiable(lines) {
    _validate();
  }

  factory QuickPriceEstimate.empty(String businessId) {
    final now = DateTime.now().toUtc();
    return QuickPriceEstimate._(
      id: newPricingId(),
      businessId: businessId,
      lines: [],
      revision: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id, businessId;
  final List<EstimateLine> lines;
  final int revision;
  final DateTime createdAt, updatedAt;
  final String? convertedSaleId;
  Currency? get currency =>
      lines.isEmpty ? null : lines.first.pricing.result.rule.currency;
  BigInt get totalMinor => lines.fold(
    BigInt.zero,
    (sum, line) => sum + line.pricing.result.amounts.totalMinor,
  );
  String get operationId => 'qp_$id';

  void _validate() {
    _estimateId(id);
    validateId(businessId);
    if (revision < 0 ||
        revision > 2147483647 ||
        updatedAt.isBefore(createdAt) ||
        lines.length > 100 ||
        lines.map((line) => line.id).toSet().length != lines.length) {
      throw ArgumentError(
        'An estimate supports up to 100 independent items and a valid revision.',
      );
    }
    if (convertedSaleId != null) validateId(convertedSaleId!);
    final expectedCurrency = currency;
    for (final line in lines) {
      _estimateId(line.id);
      final rule = line.pricing.result.rule;
      if (rule.businessId != businessId) {
        throw ArgumentError('This item belongs to another business.');
      }
      if (rule.currency.code != expectedCurrency!.code ||
          rule.currency.minorDigits != 2 ||
          !inventoryCurrencies.contains(rule.currency.code)) {
        throw ArgumentError(
          'Use one supported bill currency with two decimal places.',
        );
      }
    }
    if (totalMinor < BigInt.zero || totalMinor > BigInt.from(maxMoneyMinor)) {
      throw ArgumentError('The estimate exceeds the supported bill total.');
    }
  }

  void _editable() {
    if (convertedSaleId != null) {
      throw StateError(
        'This estimate is already a bill. Start a new estimate.',
      );
    }
  }

  int _index(String lineId) {
    final index = lines.indexWhere((line) => line.id == lineId);
    if (index < 0) throw ArgumentError('The estimate item was not found.');
    return index;
  }

  QuickPriceEstimate _change(List<EstimateLine> next, {String? saleId}) {
    _editable();
    final now = DateTime.now().toUtc();
    return QuickPriceEstimate._(
      id: id,
      businessId: businessId,
      lines: next,
      revision: revision + 1,
      createdAt: createdAt,
      updatedAt: now.isBefore(updatedAt) ? updatedAt : now,
      convertedSaleId: saleId,
    );
  }

  QuickPriceEstimate append(EstimateLine line) => _change([...lines, line]);

  QuickPriceEstimate replace(String lineId, EstimateLine line) {
    _editable();
    final next = [...lines];
    next[_index(lineId)] = line._withId(lineId);
    return _change(next);
  }

  QuickPriceEstimate remove(String lineId) {
    _editable();
    final next = [...lines]..removeAt(_index(lineId));
    return _change(next);
  }

  QuickPriceEstimate duplicate(String lineId) {
    _editable();
    final index = _index(lineId);
    final next = [...lines]
      ..insert(index + 1, lines[index]._withId(newPricingId()));
    return _change(next);
  }

  /// Uses Flutter's ReorderableListView insertion-index convention (0..length).
  QuickPriceEstimate reorder(int oldIndex, int newIndex) {
    _editable();
    if (oldIndex < 0 ||
        oldIndex >= lines.length ||
        newIndex < 0 ||
        newIndex > lines.length) {
      throw ArgumentError('Choose a valid estimate item position.');
    }
    final next = [...lines];
    final line = next.removeAt(oldIndex);
    next.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, line);
    return _change(next);
  }

  QuickPriceEstimate markConverted(String saleId) {
    validateId(saleId);
    if (convertedSaleId == saleId) return this;
    if (lines.isEmpty) throw StateError('Add an item before creating a bill.');
    return _change(lines, saleId: saleId);
  }

  SaleCheckoutSeed toCheckoutSeed(String uid) {
    _editable();
    if (lines.isEmpty) {
      throw StateError('Add an item before continuing to checkout.');
    }
    _validate();
    final saleLines = lines.map((line) => line.toSaleLine()).toList();
    for (final line in saleLines) {
      line.validate();
    }
    return SaleCheckoutSeed(
      uid: uid,
      operationId: operationId,
      lines: saleLines,
    );
  }

  String publicText() {
    _validate();
    final value = currency;
    final text = <String>['Price estimate'];
    if (value == null) return text.join('\n');
    var net = BigInt.zero;
    var tax = BigInt.zero;
    for (final entry in lines.indexed) {
      final line = entry.$2;
      line.pricing.validate();
      final pricing = line.pricing;
      text.add('${entry.$1 + 1}. ${line.product.name}');
      text.addAll(line.parameters.map((p) => '${p.name}: ${p.value}'));
      text.add('Quantity: ${pricing.quantity}');
      text.add(
        'Unit amount${pricing.totalMinor % pricing.quantity != 0 ? ' (rounded)' : ''}: ${moneyText(BigInt.from(pricing.unitPriceMinor), value)}',
      );
      text.add(
        'Line amount: ${moneyText(BigInt.from(pricing.totalMinor), value)}',
      );
      net += BigInt.from(pricing.netMinor);
      tax += BigInt.from(pricing.taxMinor);
    }
    text.addAll([
      if (tax != BigInt.zero) 'Excluding tax: ${moneyText(net, value)}',
      if (tax != BigInt.zero) 'Tax: ${moneyText(tax, value)}',
      'Grand total: ${moneyText(totalMinor, value)}',
    ]);
    return text.join('\n');
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'businessId': businessId,
    'lines': lines.map((line) => line.toJson()).toList(),
    'revision': revision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'convertedSaleId': convertedSaleId,
  };

  factory QuickPriceEstimate.fromJson(
    Map<String, dynamic> json, {
    required String businessId,
  }) {
    try {
      validateWorkspaceValue(json);
      _keys(json, {
        'schemaVersion',
        'id',
        'businessId',
        'lines',
        'revision',
        'createdAt',
        'updatedAt',
        'convertedSaleId',
      });
      if (json['schemaVersion'] != 1 || json['businessId'] != businessId) {
        throw const FormatException(
          'This estimate has an unsupported format or belongs to another business.',
        );
      }
      final savedLines = json['lines'] as List;
      if (savedLines.length > 100) {
        throw const FormatException('An estimate supports up to 100 items.');
      }
      return QuickPriceEstimate._(
        id: json['id'] as String,
        businessId: businessId,
        lines: savedLines
            .map((line) => EstimateLine.fromJson(line as Map<String, dynamic>))
            .toList(),
        revision: json['revision'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        convertedSaleId: json['convertedSaleId'] as String?,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'The saved estimate could not be verified. It has not been discarded.',
      );
    }
  }
}

final class EstimateRepository {
  EstimateRepository(this.workspace) : _writer = DraftWriter(workspace.values);
  final QuickPriceWorkspace workspace;
  final DraftWriter _writer;
  Future<void> _tail = Future.value();

  Future<QuickPriceEstimate> load() async {
    await _tail;
    final json = await workspace.values.read('estimate');
    return json == null
        ? QuickPriceEstimate.empty(workspace.businessId)
        : QuickPriceEstimate.fromJson(json, businessId: workspace.businessId);
  }

  Future<void> save(QuickPriceEstimate estimate) {
    if (estimate.businessId != workspace.businessId) {
      throw ArgumentError('This estimate belongs to another business.');
    }
    final snapshot = estimate.toJson();
    validateWorkspaceValue(snapshot);
    QuickPriceEstimate.fromJson(snapshot, businessId: workspace.businessId);
    final next = _tail.then((_) async {
      final previousJson = await workspace.values.read('estimate');
      if (previousJson != null) {
        final previous = QuickPriceEstimate.fromJson(
          previousJson,
          businessId: workspace.businessId,
        );
        if (previous.id == estimate.id) {
          final same = canonicalJson(previousJson) == canonicalJson(snapshot);
          if (previous.convertedSaleId != null && !same) {
            throw StateError(
              'This estimate is already a bill. Start a new estimate.',
            );
          }
          if (previous.revision > estimate.revision ||
              previous.revision == estimate.revision && !same) {
            throw StateError('The estimate changed. Reload it before saving.');
          }
        }
      }
      await _writer.write('estimate', snapshot);
    });
    _tail = next.catchError((Object _) {});
    return next;
  }
}

void _estimateId(String id) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) {
    throw const FormatException('Invalid estimate item identity.');
  }
}

void _keys(Map<String, dynamic> map, Set<String> keys) {
  if (map.length != keys.length || !keys.every(map.containsKey)) {
    throw const FormatException('Invalid saved estimate fields.');
  }
}

Map<String, dynamic> _freezeMap(Map<String, dynamic> map) => Map.unmodifiable(
  map.map(
    (key, value) => MapEntry(
      key,
      value is Map<String, dynamic>
          ? _freezeMap(value)
          : value is List
          ? List.unmodifiable(value)
          : value,
    ),
  ),
);

CalculatorSession _restore(
  UniversalProduct product,
  Map<String, dynamic> state,
  SalePriceSnapshot pricing,
) {
  _keys(state, {
    'schemaVersion',
    'productId',
    'businessId',
    'ruleVersion',
    'quantity',
    'useSameUnit',
    'linkedUnit',
    'baseRateOverride',
    'entries',
  });
  final session = CalculatorSession(clock: () => pricing.result.calculatedAt);
  try {
    session.select(product);
    session.restore(jsonObject(canonicalJson(state)));
    final replay = session.result;
    if (replay == null ||
        canonicalJson(session.toJson()) != canonicalJson(state) ||
        canonicalJson(replay.toJson()) != pricing.snapshotJson) {
      throw const FormatException(
        'Calculator inputs do not match the saved price.',
      );
    }
    return session;
  } catch (_) {
    session.dispose();
    rethrow;
  }
}

void _projectSources(UniversalProduct product, Map<String, dynamic> state) {
  final lengths = product.rule.schema.fields
      .where(
        (field) =>
            field.isNumeric && field.dimension == MeasureDimension.length,
      )
      .toList();
  if (lengths.isEmpty ||
      !CalculatorSession.lengthUnits.any(
        (unit) =>
            unit == state['linkedUnit'] &&
            lengths.every((field) => field.permittedUnits.contains(unit)),
      )) {
    state['linkedUnit'] = null;
  }
  final entries = state['entries'] as Map<String, dynamic>;
  for (final field in product.rule.schema.fields.where((f) => f.isNumeric)) {
    final entry = entries[field.id] as Map<String, dynamic>;
    final source = entry['source'];
    if (source is! Map) continue;
    var sourceValue = Exact.parse(source['text'] as String);
    var sourceUnit = source['unit'] as String;
    if (sourceUnit == 'ft_in') {
      sourceValue =
          sourceValue * Exact.integer(12) +
          Exact.parse(
            (source['inches'] as String).isEmpty
                ? '0'
                : source['inches'] as String,
          );
      sourceUnit = 'in';
    }
    final unit = entry['unit'] as String;
    final converted = product.rule.schema.units.registry.convert(
      sourceValue,
      sourceUnit,
      unit == 'ft_in' ? 'in' : unit,
    );
    if (unit == 'ft_in') {
      final feet = converted / Exact.integer(12);
      var whole = feet.numerator ~/ feet.denominator;
      var inches = decimalText(
        converted - Exact(whole) * Exact.integer(12),
        places: field.precision,
      );
      if (Exact.parse(inches) == Exact.integer(12)) {
        whole += BigInt.one;
        inches = '0';
      }
      entry['text'] = '$whole';
      entry['inches'] = inches;
      entry['rounded'] =
          Exact(whole) * Exact.integer(12) + Exact.parse(inches) != converted;
    } else {
      entry['text'] = decimalText(converted, places: field.precision);
      entry['inches'] = '';
      entry['rounded'] = Exact.parse(entry['text'] as String) != converted;
    }
  }
}

bool _privateName(String value) => RegExp(
  r'cost|margin|profit|private|internal|supplier|wholesale|purchase|markup|secret|note|rate',
  caseSensitive: false,
).hasMatch(value);

String _unit(String unit) => unitShort[unit] ?? unit;
String _measurement(Exact amount, String unit) =>
    '${decimalText(amount, places: 12, approximate: true)} ${_unit(unit)}';

List<ProductParameter> _publicParameters(
  UniversalProduct product,
  SalePriceSnapshot pricing,
) {
  final result = pricing.result;
  final parameters = <ProductParameter>[];
  void add(String name, String value, {bool variantAttribute = false}) {
    if (name.contains(RegExp(r'[\r\n]')) || value.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError('Use single-line customer specifications.');
    }
    var label = name.trim();
    final text = value.trim();
    final existing = parameters
        .where((p) => p.name.toLowerCase() == label.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      if (existing.value == text) return;
      if (variantAttribute) label = 'Variant $label';
    }
    if (parameters.any(
      (p) => p.name.toLowerCase() == label.toLowerCase() && p.value == text,
    )) {
      return;
    }
    parameters.add(ProductParameter(name: label, value: text));
  }

  final fields = [...product.rule.schema.fields]
    ..sort(
      (a, b) => a.displayOrder == b.displayOrder
          ? a.id.compareTo(b.id)
          : a.displayOrder.compareTo(b.displayOrder),
    );
  for (final field in fields) {
    if (_privateName(field.id) ||
        _privateName(field.label) ||
        !result.inputs.visibleFields.contains(field.id)) {
      continue;
    }
    final input = result.inputs.values[field.id];
    if (input is NumberInput &&
        !field.dimension.isCommercialUnit &&
        field.dimension != MeasureDimension.scalar) {
      add(field.label, _measurement(input.value, input.unit));
      final measured = result.inputs.numbers[field.id];
      final billed = result.billableInputs[field.id];
      if (measured != null &&
          billed != null &&
          measured.value != billed.value) {
        final unit = field.defaultUnit!;
        final factor = product.rule.schema.units.registry
            .require(unit)
            .canonicalFactor;
        add('${field.label} billed', _measurement(billed.value / factor, unit));
      }
    } else if (input is ChoiceInput) {
      add(field.label, input.value);
    }
  }
  final attributes = product.attributes.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final attribute in attributes) {
    if (!_privateName(attribute.key)) {
      add(attribute.key, attribute.value, variantAttribute: true);
    }
  }
  for (final charge in result.base.indexed) {
    final item = charge.$2;
    if (item.measured != item.billable || item.measuredUnit != item.unit) {
      final suffix = result.base.length == 1 ? '' : ' ${charge.$1 + 1}';
      add('Measured$suffix', _measurement(item.measured, item.measuredUnit));
      add('Billed$suffix', _measurement(item.billable, item.unit));
    }
  }
  final extras = <String>[];
  for (final extra in result.rule.extras) {
    if (_privateName(extra.label)) continue;
    if (result.extras.any(
      (charge) => charge.label.startsWith('${extra.label} / '),
    )) {
      extras.add(extra.label);
    }
  }
  if (extras.isNotEmpty) add('Extras', extras.join(', '));
  final currency = result.rule.currency;
  if (pricing.discountMinor != 0) {
    add('Discount', moneyText(BigInt.from(pricing.discountMinor), currency));
  }
  final tax = result.rule.tax;
  if (tax.behavior != TaxBehavior.exempt || pricing.taxMinor != 0) {
    add(
      'Tax',
      tax.behavior == TaxBehavior.exempt
          ? 'Exempt (${moneyText(BigInt.from(pricing.taxMinor), currency)})'
          : '${decimalText(tax.percent, places: 12)}% ${tax.behavior.name} (${moneyText(BigInt.from(pricing.taxMinor), currency)})',
    );
  }
  try {
    ProductParameter.validateList(parameters);
  } catch (_) {
    throw ArgumentError(
      'This item has too many or oversized customer specifications. Use at most 20 unique specifications, with names up to 60 and values up to 120 characters.',
    );
  }
  return List.unmodifiable(parameters);
}
