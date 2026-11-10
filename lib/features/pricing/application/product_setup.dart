import '../domain/exact.dart';
import '../domain/pricing_models.dart';
import '../domain/serialization.dart';
import '../domain/universal/rate_card.dart';
import '../domain/universal/universal_pricing.dart';
import 'workspace.dart';

const strategyLabels = {
  'perUnit': 'Per piece / set / pair',
  'area': 'Area',
  'linear': 'Length',
  'weight': 'Weight',
  'volume': 'Volume',
  'packaging': 'Whole packages',
  'sizeSlab': 'Size bands',
  'quantityTier': 'Quantity tiers',
  'component': 'Kit / components',
  'formula': 'Custom formula',
};
const unitLabels = {
  'number': 'Number',
  'piece': 'Piece',
  'item': 'Item',
  'pair': 'Pair',
  'set': 'Set',
  'ft': 'Feet',
  'in': 'Inches',
  'mm': 'Millimetres',
  'cm': 'Centimetres',
  'm': 'Metres',
  'yd': 'Yards',
  'ft2': 'Square feet',
  'm2': 'Square metres',
  'in2': 'Square inches',
  'cm2': 'Square centimetres',
  'm3': 'Cubic metres',
  'ft3': 'Cubic feet',
  'litre': 'Litres',
  'ml': 'Millilitres',
  'kg': 'Kilograms',
  'g': 'Grams',
  'tonne': 'Tonnes',
  'lb': 'Pounds',
  'box': 'Box',
  'bag': 'Bag',
  'carton': 'Carton',
  'roll': 'Roll',
  'bucket': 'Bucket',
  'pack': 'Pack',
  'percent': 'Percent',
};
const unitShort = {
  'ft2': 'ft²',
  'm2': 'm²',
  'in2': 'in²',
  'cm2': 'cm²',
  'ft3': 'ft³',
  'm3': 'm³',
  'ft_in': 'ft + in',
};

List<String> compatibleUnits(String unit) {
  final registry = UnitRegistry.standard();
  final dimension = registry.require(unit).dimension;
  return registry.units.values
      .where((u) => u.dimension == dimension)
      .map((u) => u.id)
      .toList();
}

Map<String, dynamic> inputDraft(String id, String label, String unit) => {
  'id': id,
  'label': label,
  'type': 'decimal',
  'unit': unit,
  'permitted': compatibleUnits(unit),
  'required': true,
  'default': '',
  'minimum': '0.000001',
  'maximum': '',
  'precision': '6',
  'multiple': '',
  'choices': '',
  'visibleField': '',
  'visibleValue': '',
  'billMinimum': '',
  'billIncrement': '',
};
Map<String, dynamic> refDraft(String name) => {
  'kind': 'reference',
  'name': name,
};
Map<String, dynamic> literalDraft(String value, [String unit = 'number']) => {
  'kind': 'literal',
  'value': value,
  'unit': unit,
};
Map<String, dynamic> opDraft(
  String op,
  Map<String, dynamic> left,
  Map<String, dynamic> right,
) => {'kind': 'binary', 'operation': op, 'left': left, 'right': right};

Expression compileExpression(
  Map<String, dynamic> node,
  Currency currency, [
  int depth = 0,
]) {
  if (depth > 16) {
    throw ArgumentError('Keep formulas within 16 nested operations');
  }
  switch (node['kind']) {
    case 'reference':
      return Reference(node['name'] as String);
    case 'literal':
      final number = Exact.parse((node['value'] as String).trim());
      if (node['unit'] == 'money') {
        return Literal(number, MeasureDimension.money(currency.code));
      }
      final unit = UnitRegistry.standard().require(node['unit'] as String);
      return Literal(number * unit.canonicalFactor, unit.dimension);
    case 'binary':
      return Arithmetic(
        ArithmeticOperation.values.byName(node['operation'] as String),
        compileExpression(
          node['left'] as Map<String, dynamic>,
          currency,
          depth + 1,
        ),
        compileExpression(
          node['right'] as Map<String, dynamic>,
          currency,
          depth + 1,
        ),
      );
    default:
      throw ArgumentError('Choose a formula operation');
  }
}

/// Mutable editor data deliberately accepts incomplete text. Only compile()
/// produces a validated domain rule; incomplete setup can never be published.
class ProductSetup {
  ProductSetup(this.data);
  final Map<String, dynamic> data;
  factory ProductSetup.create({String kind = 'area'}) {
    final setup = ProductSetup({
      'schemaVersion': 1,
      'id': newPricingId(),
      'name': '',
      'categoryId': '',
      'categoryName': '',
      'parentId': '',
      'step': 0,
      'kind': kind,
      'taxBehavior': '',
      'taxPercent': '',
      'taxReference': 'local-${newPricingId()}',
      'discountPercent': '',
      'discountFixed': '',
      'discountThreshold': '1',
      'rounding': 'halfUp',
      'minimum': '',
      'increment': '',
      'waste': '',
      'minimumCharge': '',
      'packageUnit': 'box',
      'coverage': '',
      'requestedUnit': 'ft2',
      'conversions': <Map<String, dynamic>>[],
      'roles': <String, dynamic>{},
      'extras': <Map<String, dynamic>>[],
    });
    setup.setKind(kind);
    return setup;
  }
  factory ProductSetup.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported setup draft');
    }
    return ProductSetup(jsonObject(canonicalJson(json)));
  }
  String get id => data['id'] as String;
  String get kind => data['kind'] as String;
  List<Map<String, dynamic>> rows(String key) =>
      (data[key] as List).cast<Map<String, dynamic>>();
  void setKind(String kind) {
    data['kind'] = kind;
    data['tierBasis'] = 'perUnit';
    data['fields'] = <Map<String, dynamic>>[];
    data['rateUnit'] = switch (kind) {
      'area' || 'formula' => 'ft2',
      'linear' => 'm',
      'weight' => 'kg',
      'volume' => 'm3',
      'packaging' => 'box',
      'sizeSlab' => 'number',
      _ => 'piece',
    };
    data['rates'] = <Map<String, dynamic>>[
      {
        'id': newPricingId(),
        'key': 'base',
        'amount': '',
        'unit': '',
        'selectors': <String, dynamic>{},
      },
    ];
    data['tiers'] = <Map<String, dynamic>>[
      {'id': newPricingId(), 'minimum': '1', 'amount': ''},
    ];
    data['bands'] = <Map<String, dynamic>>[
      {'id': newPricingId(), 'amount': '', 'ranges': <String, dynamic>{}},
    ];
    data['components'] = <Map<String, dynamic>>[componentDraft()];
    setBasis(kind == 'quantityTier' || kind == 'component' ? 'perUnit' : kind);
    data['formula'] = opDraft(
      'multiply',
      data['measure'] as Map<String, dynamic>,
      refDraft('rate:base'),
    );
  }

  void setBasis(String basis) {
    data['tierBasis'] = basis;
    final fields = <Map<String, dynamic>>[];
    Map<String, dynamic> measure;
    switch (basis) {
      case 'area':
      case 'formula':
      case 'sizeSlab':
        fields.addAll([
          inputDraft('height', 'Height', 'ft'),
          inputDraft('width', 'Width', 'ft'),
        ]);
        measure = opDraft('multiply', refDraft('height'), refDraft('width'));
      case 'linear':
        fields.add(inputDraft('length', 'Length', 'm'));
        measure = refDraft('length');
      case 'weight':
        fields.add(inputDraft('weight', 'Weight', 'kg'));
        measure = refDraft('weight');
      case 'volume':
        fields.addAll([
          inputDraft('height', 'Height', 'm'),
          inputDraft('width', 'Width', 'm'),
          inputDraft('depth', 'Depth', 'm'),
        ]);
        measure = opDraft(
          'multiply',
          opDraft('multiply', refDraft('height'), refDraft('width')),
          refDraft('depth'),
        );
      case 'packaging':
        fields.add(inputDraft('area', 'Required area', 'ft2'));
        measure = refDraft('area');
      default:
        measure = literalDraft('1', 'piece');
    }
    data['fields'] = fields;
    data['measure'] = measure;
    if (kind == 'quantityTier') {
      data['rateUnit'] = switch (basis) {
        'area' => 'ft2',
        'linear' => 'm',
        'weight' => 'kg',
        'volume' => 'm3',
        _ => 'piece',
      };
    }
  }

  static Map<String, dynamic> componentDraft() => {
    'id': newPricingId(),
    'name': '',
    'amount': '',
    'type': 'perItem',
    'unit': 'piece',
    'optional': false,
    'selected': false,
    'measure': literalDraft('1', 'piece'),
  };

  UniversalProduct compile(String businessId, Currency currency) {
    String text(String key) => (data[key] as String? ?? '').trim();
    Exact number(String key) =>
        text(key).isEmpty ? Exact.zero : Exact.parse(text(key));
    Exact? optional(String key) =>
        text(key).isEmpty ? null : Exact.parse(text(key));
    final name = text('name');
    validateName(name);
    final definitions = <InputDefinition>[];
    final billing = <InputBillingRule>[];
    for (final (index, field) in rows('fields').indexed) {
      final type = InputDataType.values.byName(field['type'] as String);
      final numeric =
          type == InputDataType.decimal || type == InputDataType.integer;
      final unit = field['unit'] as String;
      final defaultText = (field['default'] as String? ?? '').trim();
      Exact? value(String key) => (field[key] as String? ?? '').trim().isEmpty
          ? null
          : Exact.parse((field[key] as String).trim());
      final conditionId = field['visibleField'] as String? ?? '';
      final dependency = rows('fields')
          .where((f) => f['id'] == conditionId)
          .firstOrNull;
      final conditionValue = field['visibleValue'] as String? ?? '';
      definitions.add(
        InputDefinition(
          id: field['id'] as String,
          label: field['label'] as String,
          type: type,
          dimension: numeric
              ? UnitRegistry.standard().require(unit).dimension
              : MeasureDimension.scalar,
          defaultUnit: numeric ? unit : null,
          permittedUnits: numeric
              ? List<String>.from(field['permitted'] as List)
              : [],
          required: field['required'] as bool,
          defaultValue: type == InputDataType.boolean
              ? BooleanInput(defaultText == 'true')
              : defaultText.isEmpty
              ? null
              : numeric
              ? NumberInput(Exact.parse(defaultText), unit)
              : ChoiceInput(defaultText),
          minimum: numeric ? value('minimum') : null,
          maximum: numeric ? value('maximum') : null,
          precision: int.parse(field['precision'] as String),
          multipleOf: numeric ? value('multiple') : null,
          choices: type == InputDataType.choice
              ? (field['choices'] as String)
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList()
              : [],
          visibleWhen: conditionId.isEmpty
              ? null
              : VisibilityCondition(
                  conditionId,
                  dependency?['type'] == 'boolean'
                      ? conditionValue == 'true'
                      : conditionValue,
                ),
          displayOrder: index,
        ),
      );
      if (numeric &&
          (value('billMinimum') != null || value('billIncrement') != null)) {
        billing.add(
          InputBillingRule(
            fieldId: field['id'] as String,
            unit: unit,
            minimum: value('billMinimum'),
            increment: value('billIncrement'),
          ),
        );
      }
    }
    final registry = UnitRegistry.standard();
    final conversions = <ProductUnitConversion>[
      for (final row in rows('conversions'))
        ProductUnitConversion(
          productId: id,
          from: row['from'] as String,
          to: row['to'] as String,
          factor: Exact.parse(row['factor'] as String),
        ),
      if (kind == 'packaging')
        ProductUnitConversion(
          productId: id,
          from: text('packageUnit'),
          to: text('requestedUnit'),
          factor: Exact.parse(text('coverage')),
        ),
    ];
    final rates = <SellingRate>[];
    final unit = text('rateUnit');
    final policy = BillableQuantityPolicy(
      unit: kind == 'packaging' ? text('requestedUnit') : unit,
      minimum: optional('minimum'),
      increment: optional('increment'),
      wastePercent: optional('waste'),
      minimumCharge: optional('minimumCharge'),
    );
    Expression measure = compileExpression(
      data['measure'] as Map<String, dynamic>,
      currency,
    );
    if (kind == 'perUnit' ||
        (kind == 'quantityTier' && text('tierBasis') == 'perUnit')) {
      measure = Literal(Exact.one, registry.require(unit).dimension);
    }
    MeasuredRateStrategy measured(StrategyKind kind, String rateKey) =>
        MeasuredRateStrategy(
          kind: kind,
          measure: FormulaProgram(output: measure),
          rateKey: rateKey,
          policy: policy,
        );
    if (!['sizeSlab', 'quantityTier', 'component'].contains(kind)) {
      for (final row in rows('rates')) {
        rates.add(
          SellingRate(
            id: row['id'] as String,
            key: row['key'] as String,
            amount: Exact.parse((row['amount'] as String).trim()),
            unit: (row['unit'] as String).isEmpty
                ? unit
                : row['unit'] as String,
            selectors: Map<String, String>.from(row['selectors'] as Map),
          ),
        );
      }
    }
    late PricingStrategy strategy;
    switch (StrategyKind.values.byName(kind)) {
      case StrategyKind.packaging:
        strategy = PackageStrategy(
          measure: FormulaProgram(output: measure),
          requestedUnit: text('requestedUnit'),
          packageUnit: text('packageUnit'),
          rateKey: 'base',
          policy: policy,
        );
      case StrategyKind.quantityTier:
        final tiers = <QuantityTier>[];
        for (final row in rows('tiers')) {
          final key = 'tier_${row['id']}';
          rates.add(
            SellingRate(
              id: key,
              key: key,
              amount: Exact.parse(row['amount'] as String),
              unit: unit,
            ),
          );
          tiers.add(
            QuantityTier(
              int.parse(row['minimum'] as String),
              measured(StrategyKind.values.byName(text('tierBasis')), key),
            ),
          );
        }
        strategy = QuantityTierStrategy(tiers);
      case StrategyKind.sizeSlab:
        final bands = <SizeBand>[];
        for (final row in rows('bands')) {
          final key = 'band_${row['id']}';
          rates.add(
            SellingRate(
              id: key,
              key: key,
              amount: Exact.parse(row['amount'] as String),
              unit: 'number',
            ),
          );
          final ranges = row['ranges'] as Map<String, dynamic>;
          bands.add(
            SizeBand(
              id: row['id'] as String,
              rateKey: key,
              ranges: {
                for (final e in ranges.entries)
                  e.key: SlabRange(
                    unit: definitions
                        .singleWhere((f) => f.id == e.key)
                        .defaultUnit!,
                    minimum: Exact.parse(e.value['min'] as String),
                    maximum: Exact.parse(e.value['max'] as String),
                  ),
              },
            ),
          );
        }
        strategy = SizeSlabStrategy(bands: bands);
      case StrategyKind.component:
        strategy = ComponentStrategy(
          _components(rows('components'), definitions, rates, currency),
        );
      case StrategyKind.formula:
        strategy = FormulaPriceStrategy(
          FormulaProgram(
            output: compileExpression(
              data['formula'] as Map<String, dynamic>,
              currency,
            ),
          ),
        );
      default:
        strategy = measured(StrategyKind.values.byName(kind), 'base');
    }
    final extras = _components(rows('extras'), definitions, rates, currency);
    final units = ProductUnitSystem(
      productId: id,
      registry: registry,
      conversions: conversions,
      roles: (data['roles'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(CommercialUnitRole.values.byName(key), value as String),
      ),
    );
    final taxBehavior = text('taxBehavior');
    if (taxBehavior.isEmpty) {
      throw ArgumentError('Choose the tax treatment for this product');
    }
    final tax = TaxPolicy(
      reference: text('taxReference'),
      behavior: TaxBehavior.values.byName(taxBehavior),
      percent: taxBehavior == 'exempt'
          ? Exact.zero
          : Exact.parse(text('taxPercent')),
    );
    return UniversalProduct(
      categoryId: text('categoryId').isEmpty ? id : text('categoryId'),
      name: name,
      rule: UniversalPricingRule(
        businessId: businessId,
        productId: id,
        id: 'rule_$id',
        version: 1,
        currency: currency,
        schema: InputSchema(definitions, units),
        rates: rates,
        strategy: strategy,
        tax: tax,
        discount: DiscountPolicy(
          minimumQuantity: int.parse(text('discountThreshold')),
          percent: number('discountPercent'),
          fixedPerLine: number('discountFixed'),
        ),
        rounding: MoneyRounding.values.byName(text('rounding')),
        effectiveAt: DateTime.utc(1970),
        inputBilling: billing,
        extras: extras,
      ),
    );
  }

  List<PriceComponent> _components(
    List<Map<String, dynamic>> rows,
    List<InputDefinition> fields,
    List<SellingRate> rates,
    Currency currency,
  ) {
    final result = <PriceComponent>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final type = row['type'] as String;
      final key = 'charge_$id';
      final unit = ['perItem', 'perOrder'].contains(type)
          ? 'piece'
          : row['unit'] as String;
      rates.add(
        SellingRate(
          id: key,
          key: key,
          amount: Exact.parse((row['amount'] as String).trim()),
          unit: unit,
        ),
      );
      final enabledBy = row['optional'] == true ? 'include_$id' : null;
      if (enabledBy != null) {
        fields.add(
          InputDefinition(
            id: enabledBy,
            label: row['name'] as String,
            type: InputDataType.boolean,
            dimension: MeasureDimension.scalar,
            defaultUnit: null,
            permittedUnits: [],
            defaultValue: BooleanInput(row['selected'] == true),
            displayOrder: fields.length,
          ),
        );
      }
      result.add(
        PriceComponent(
          id: id,
          label: row['name'] as String,
          perOrder: type == 'perOrder',
          enabledBy: enabledBy,
          strategy: MeasuredRateStrategy(
            kind: switch (type) {
              'area' => StrategyKind.area,
              'linear' => StrategyKind.linear,
              'weight' => StrategyKind.weight,
              _ => StrategyKind.perUnit,
            },
            measure: FormulaProgram(
              output: ['perItem', 'perOrder'].contains(type)
                  ? Literal(Exact.one, MeasureDimension.count('piece'))
                  : compileExpression(
                      row['measure'] as Map<String, dynamic>,
                      currency,
                    ),
            ),
            rateKey: key,
            policy: BillableQuantityPolicy(unit: unit),
          ),
        ),
      );
    }
    return result;
  }
}
