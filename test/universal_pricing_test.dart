import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart'
    show TaxPolicy, TaxBehavior, DiscountPolicy;
import 'package:hyner/features/pricing/domain/serialization.dart';
import 'package:hyner/features/pricing/domain/universal/universal_pricing.dart';

import 'support/universal_fixture.dart';

void main() {
  final examples =
      <
        ({
          String name,
          UniversalPricingRule definition,
          Map<String, InputValue> inputs,
          int quantity,
          int total,
        })
      >[
        (
          name: 'perUnit',
          definition: rule(
            strategy: piece('base'),
            rates: [rate('base', '120', 'piece')],
          ),
          inputs: {},
          quantity: 2,
          total: 24000,
        ),
        (
          name: 'area',
          definition: rule(
            strategy: measured(
              StrategyKind.area,
              mul(ref('height'), ref('width')),
              'base',
              'ft2',
            ),
            rates: [rate('base', '150', 'ft2')],
            fields: [number('height', 'in'), number('width', 'in')],
          ),
          inputs: {'height': n('84', 'in'), 'width': n('36', 'in')},
          quantity: 3,
          total: 945000,
        ),
        (
          name: 'linear',
          definition: rule(
            strategy: measured(
              StrategyKind.linear,
              ref('length'),
              'base',
              'ft',
            ),
            rates: [rate('base', '50', 'ft')],
            fields: [
              number('length', 'ft', permitted: ['ft', 'm']),
            ],
          ),
          inputs: {'length': n('7', 'ft')},
          quantity: 1,
          total: 35000,
        ),
        (
          name: 'weight',
          definition: rule(
            strategy: measured(
              StrategyKind.weight,
              ref('weight'),
              'base',
              'kg',
            ),
            rates: [rate('base', '80', 'kg')],
            fields: [
              number('weight', 'g', permitted: ['g', 'kg', 'tonne', 'lb']),
            ],
          ),
          inputs: {'weight': n('2500', 'g')},
          quantity: 2,
          total: 40000,
        ),
        (
          name: 'volume',
          definition: rule(
            strategy: measured(
              StrategyKind.volume,
              ref('volume'),
              'base',
              'litre',
            ),
            rates: [rate('base', '75', 'litre')],
            fields: [
              number('volume', 'ml', permitted: ['ml', 'litre']),
            ],
          ),
          inputs: {'volume': n('2000', 'ml')},
          quantity: 1,
          total: 15000,
        ),
        (
          name: 'packaging',
          definition: rule(
            strategy: PackageStrategy(
              measure: program(ref('area')),
              requestedUnit: 'm2',
              packageUnit: 'box',
              rateKey: 'base',
              policy: BillableQuantityPolicy(unit: 'm2', wastePercent: e('10')),
            ),
            rates: [rate('base', '450', 'box')],
            fields: [number('area', 'm2')],
            units: ProductUnitSystem(
              productId: 'tiles',
              registry: registry,
              conversions: [
                ProductUnitConversion(
                  productId: 'tiles',
                  from: 'box',
                  to: 'm2',
                  factor: e('1.44'),
                ),
              ],
            ),
          ),
          inputs: {'area': n('10', 'm2')},
          quantity: 1,
          total: 360000,
        ),
        (
          name: 'sizeSlab',
          definition: rule(
            strategy: SizeSlabStrategy(
              bands: [
                SizeBand(
                  id: 'small',
                  ranges: {
                    'width': SlabRange(
                      unit: 'm',
                      minimum: e('0'),
                      maximum: e('1'),
                    ),
                  },
                  rateKey: 'small',
                ),
                SizeBand(
                  id: 'large',
                  ranges: {
                    'width': SlabRange(
                      unit: 'm',
                      minimum: e('1'),
                      maximum: e('2'),
                    ),
                  },
                  rateKey: 'large',
                ),
              ],
            ),
            rates: [
              rate('small', '1000', 'number'),
              rate('large', '1500', 'number'),
            ],
            fields: [number('width', 'm')],
          ),
          inputs: {'width': n('1', 'm')},
          quantity: 1,
          total: 150000,
        ),
        (
          name: 'quantityTier',
          definition: rule(
            strategy: QuantityTierStrategy([
              QuantityTier(1, piece('retail')),
              QuantityTier(10, piece('bulk')),
            ]),
            rates: [
              rate('retail', '120', 'piece'),
              rate('bulk', '100', 'piece'),
            ],
          ),
          inputs: {},
          quantity: 10,
          total: 100000,
        ),
        (
          name: 'component',
          definition: rule(
            strategy: ComponentStrategy([
              PriceComponent(
                id: 'kit',
                label: 'Kit',
                strategy: ComponentStrategy([
                  PriceComponent(
                    id: 'base',
                    label: 'Panel',
                    strategy: piece('base'),
                  ),
                  PriceComponent(
                    id: 'hinges',
                    label: 'Two hinges',
                    strategy: measured(
                      StrategyKind.perUnit,
                      literal('2', MeasureDimension.count('piece')),
                      'hinge',
                      'piece',
                    ),
                  ),
                ]),
              ),
              PriceComponent(
                id: 'install',
                label: 'Installation',
                strategy: piece('install'),
                perOrder: true,
                enabledBy: 'installation',
              ),
            ]),
            rates: [
              rate('base', '100', 'piece'),
              rate('hinge', '10', 'piece'),
              rate('install', '500', 'piece'),
            ],
            fields: [toggle('installation')],
          ),
          inputs: {'installation': const BooleanInput(true)},
          quantity: 3,
          total: 86000,
        ),
        (
          name: 'formula',
          definition: rule(
            strategy: FormulaPriceStrategy(
              FormulaProgram(
                definitions: {'surface': mul(ref('height'), ref('width'))},
                output: add(
                  mul(ref('surface'), ref('rate:glass')),
                  mul(literal('2'), ref('rate:cutting')),
                ),
              ),
            ),
            rates: [
              rate('glass', '150', 'm2'),
              rate('cutting', '20', 'number'),
            ],
            fields: [number('height', 'm'), number('width', 'm')],
          ),
          inputs: {'height': n('2', 'm'), 'width': n('1', 'm')},
          quantity: 1,
          total: 34000,
        ),
      ];

  group('all ten strategies from serializable merchant configuration', () {
    for (final example in examples) {
      test(
        '${example.name} config round-trips and produces the expected selling total',
        () {
          final encoded = canonicalJson(example.definition.toJson());
          final restored = UniversalPricingRule.fromJson(jsonObject(encoded));
          final result = price(
            restored,
            inputs: example.inputs,
            quantity: example.quantity,
          );
          expect(result.amounts.totalMinor, BigInt.from(example.total));
          expect(
            result.amounts.netMinor + result.amounts.taxMinor,
            result.amounts.totalMinor,
          );
          expect(
            result.amounts.subtotalMinor - result.amounts.discountMinor,
            result.amounts.netMinor,
          );
          expect(canonicalJson(restored.toJson()), encoded);
          expect(
            result.snapshotJson,
            price(
              example.definition,
              inputs: example.inputs,
              quantity: example.quantity,
            ).snapshotJson,
          );
          final snapshot = jsonObject(result.snapshotJson);
          expect(snapshot['engineVersion'], 'universal-1');
          final replayRule = UniversalPricingRule.fromJson(
            snapshot['rule'] as Map<String, dynamic>,
          );
          final replayRequest = UniversalPricingRequest.fromJson(
            snapshot['request'] as Map<String, dynamic>,
          );
          expect(
            UniversalPricingEngine()
                .calculate(replayRule, replayRequest, at: at)
                .snapshotJson,
            result.snapshotJson,
          );
        },
      );
    }
    for (final commercial in ['pair', 'set', 'item', 'piece']) {
      test(
        'per-unit supports $commercial without an assumed pack conversion',
        () {
          final d = registry.require(commercial).dimension;
          final definition = rule(
            strategy: measured(
              StrategyKind.perUnit,
              literal('1', d),
              'base',
              commercial,
            ),
            rates: [rate('base', '50', commercial)],
          );
          expect(
            price(definition, quantity: 3).amounts.totalMinor,
            BigInt.from(15000),
          );
        },
      );
    }
    for (final package in ['bag', 'carton', 'roll', 'bucket', 'pack']) {
      test('packaging supports whole $package counts', () {
        final definition = rule(
          strategy: PackageStrategy(
            measure: program(ref('packs')),
            requestedUnit: package,
            packageUnit: package,
            rateKey: 'base',
            policy: BillableQuantityPolicy(unit: package),
          ),
          rates: [rate('base', '20', package)],
          fields: [number('packs', package)],
        );
        expect(
          price(
            definition,
            inputs: {'packs': n('2.1', package)},
          ).amounts.totalMinor,
          BigInt.from(6000),
        );
      });
    }
  });

  group('safe expressions', () {
    test('DAG dependency inference and exact arithmetic', () {
      final formula = FormulaProgram(
        definitions: {
          'volume': mul(ref('area'), ref('depth')),
          'area': mul(ref('height'), ref('width')),
        },
        output: div(ref('volume'), ref('depth')),
      );
      final symbols = {
        'height': MeasuredValue(e('1/3'), MeasureDimension.length),
        'width': MeasuredValue(e('3'), MeasureDimension.length),
        'depth': MeasuredValue(e('0.5'), MeasureDimension.length),
      };
      expect(
        formula.validate(symbols.map((k, v) => MapEntry(k, v.dimension))),
        MeasureDimension.area,
      );
      expect(formula.evaluate(symbols).value, Exact.one);
    });
    test('each approved arithmetic operation has defined exact semantics', () {
      for (final entry in {
        ArithmeticOperation.add: '4',
        ArithmeticOperation.subtract: '1',
        ArithmeticOperation.multiply: '3.75',
        ArithmeticOperation.divide: '5/3',
        ArithmeticOperation.minimum: '1.5',
        ArithmeticOperation.maximum: '2.5',
        ArithmeticOperation.ceilTo: '3',
      }.entries) {
        expect(
          program(Arithmetic(entry.key, literal('2.5'), literal('1.5')))
              .evaluate({})
              .value,
          e(entry.value),
        );
      }
    });
    test('dimensional mistakes, nonnumeric names and cyclic dependencies are rejected', () {
      expect(
        () => program(
          add(
            literal('1', MeasureDimension.length),
            literal('1', MeasureDimension.mass),
          ),
        ).validate({}),
        throwsArgumentError,
      );
      expect(
        () => FormulaProgram(
          definitions: {'a': ref('b'), 'b': ref('a')},
          output: ref('a'),
        ).validate({}),
        throwsArgumentError,
      );
      expect(
        () =>
            program(ref('material'))
                .validate({'height': MeasureDimension.length}),
        throwsArgumentError,
      );
      expect(
        () => FormulaProgram(
          definitions: {'height': literal('1')},
          output: ref('height'),
        ).validate({'height': MeasureDimension.length}),
        throwsArgumentError,
      );
      expect(
        () => rule(
          strategy: FormulaPriceStrategy(
            program(literal('100', MeasureDimension.mass)),
          ),
          rates: [],
        ),
        throwsArgumentError,
      );
    });
    test('division by zero and negative selling price are explicit errors', () {
      expect(
        () => program(div(literal('1'), literal('0'))).evaluate({}),
        throwsArgumentError,
      );
      final definition = rule(
        strategy: FormulaPriceStrategy(
          program(div(ref('rate:base'), ref('denominator'))),
        ),
        rates: [rate('base', '10', 'number')],
        fields: [number('denominator', 'number', min: '0')],
      );
      expect(
        () => price(definition, inputs: {'denominator': n('0', 'number')}),
        throwsArgumentError,
      );
      final negative = rule(
        strategy: FormulaPriceStrategy(
          program(literal('-1', MeasureDimension.money('INR'))),
        ),
        rates: [],
      );
      expect(() => price(negative), throwsArgumentError);
    });
    test(
      'unknown operators, executable source and excessive trees are rejected',
      () {
        expect(
          () =>
              Expression.fromJson({'kind': 'source', 'code': 'while(true) {}'}),
          throwsFormatException,
        );
        final json = add(literal('1'), literal('2')).toJson()
          ..['operation'] = 'eval';
        expect(() => Expression.fromJson(json), throwsArgumentError);
        Expression deep = literal('1');
        for (var i = 0; i < 34; i++) {
          deep = add(deep, literal('1'));
        }
        expect(() => FormulaProgram(output: deep), throwsArgumentError);
        expect(
          () => Expression.fromJson(jsonObject(canonicalJson(deep.toJson()))),
          throwsFormatException,
        );
        final big = Literal(Exact(BigInt.one << 5000), MeasureDimension.scalar);
        expect(() => FormulaProgram(output: big), throwsArgumentError);
        expect(
          () => FormulaProgram(output: literal('1'), version: 99),
          throwsArgumentError,
        );
      },
    );
    test('new fields and rates alter JSON configuration without application code changes', () {
      final original = examples.last.definition.toJson();
      final config = jsonObject(canonicalJson(original));
      (config['inputs'] as List).add(
        number('finishing_units', 'number').toJson(),
      );
      (config['rates'] as List).add(rate('finishing', '5', 'number').toJson());
      final current = Expression.fromJson(
        (config['strategy']['program']['output']) as Map<String, dynamic>,
      );
      config['strategy']['program']['output'] = add(
        current,
        mul(ref('finishing_units'), ref('rate:finishing')),
      ).toJson();
      final changed = UniversalPricingRule.fromJson(config);
      expect(
        price(
          changed,
          inputs: {
            'height': n('2', 'm'),
            'width': n('1', 'm'),
            'finishing_units': n('4', 'number'),
          },
        ).amounts.totalMinor,
        BigInt.from(36000),
      );
      expect(
        canonicalJson(examples.last.definition.toJson()),
        canonicalJson(original),
      );
    });
  });

  group('rates, policies and composition safeguards', () {
    test('selling pairs can use piece rates only with a product-specific conversion', () {
      final strategy = measured(
        StrategyKind.perUnit,
        literal('1', MeasureDimension.count('pair')),
        'base',
        'pair',
      );
      expect(
        () => rule(strategy: strategy, rates: [rate('base', '10', 'piece')]),
        throwsArgumentError,
      );
      final units = ProductUnitSystem(
        productId: 'product',
        registry: registry,
        conversions: [
          ProductUnitConversion(
            productId: 'product',
            from: 'pair',
            to: 'piece',
            factor: e('2'),
          ),
        ],
      );
      final definition = rule(
        strategy: strategy,
        rates: [rate('base', '10', 'piece')],
        units: units,
      );
      expect(
        price(definition, quantity: 3).amounts.totalMinor,
        BigInt.from(6000),
      );
    });
    test('selling whole boxes can use a configured carton rate without rounding cartons', () {
      final units = ProductUnitSystem(
        productId: 'product',
        registry: registry,
        conversions: [
          ProductUnitConversion(
            productId: 'product',
            from: 'box',
            to: 'm2',
            factor: e('2'),
          ),
          ProductUnitConversion(
            productId: 'product',
            from: 'carton',
            to: 'box',
            factor: e('6'),
          ),
        ],
      );
      final definition = rule(
        strategy: PackageStrategy(
          measure: program(ref('coverage')),
          requestedUnit: 'm2',
          packageUnit: 'box',
          rateKey: 'base',
          policy: BillableQuantityPolicy(unit: 'm2'),
        ),
        rates: [rate('base', '120', 'carton')],
        fields: [number('coverage', 'm2')],
        units: units,
      );
      final result = price(definition, inputs: {'coverage': n('3', 'm2')});
      expect(result.base.single.billable, e('2'));
      expect(result.base.single.rates.single.unit, 'carton');
      expect(result.amounts.totalMinor, BigInt.from(4000));
    });
    test(
      'package breakdown separates requested coverage from billable boxes',
      () {
        final sample = examples.firstWhere((e) => e.name == 'packaging');
        final result = price(sample.definition, inputs: sample.inputs);
        expect(result.base.single.measured, e('10'));
        expect(result.base.single.measuredUnit, 'm2');
        expect(result.base.single.billable, e('8'));
        expect(result.base.single.unit, 'box');
      },
    );
    test('composition depth is bounded before recursive execution', () {
      PricingStrategy strategy = piece('base');
      for (var i = 0; i < 18; i++) {
        strategy = ComponentStrategy([
          PriceComponent(id: 'component', label: 'Nested', strategy: strategy),
        ]);
      }
      expect(
        () => rule(strategy: strategy, rates: [rate('base', '1', 'piece')]),
        throwsArgumentError,
      );
      expect(
        () => PricingStrategy.fromJson(
          jsonObject(canonicalJson(strategy.toJson())),
        ),
        throwsFormatException,
      );
    });
    test('variant rate resolution selects approved exact match with explicit fallback', () {
      final definition = rule(
        strategy: piece('base'),
        rates: [
          rate('base', '100', 'piece', id: 'retail'),
          rate(
            'base',
            '150',
            'piece',
            id: 'premium',
            selectors: {'finish': 'polished'},
          ),
        ],
        fields: [
          choice('finish', ['plain', 'polished']),
        ],
      );
      expect(
        price(
          definition,
          inputs: {'finish': const ChoiceInput('plain')},
        ).amounts.totalMinor,
        BigInt.from(10000),
      );
      final result = price(
        definition,
        inputs: {'finish': const ChoiceInput('polished')},
      );
      expect(result.amounts.totalMinor, BigInt.from(15000));
      expect(result.base.single.rates.single.id, 'premium');
    });
    test('missing, ambiguous and dimensionally incompatible rates fail', () {
      expect(
        () => rule(strategy: piece('base'), rates: []),
        throwsArgumentError,
      );
      expect(
        () => rule(
          strategy: piece('base'),
          rates: [
            rate('base', '1', 'piece', id: 'a'),
            rate('base', '2', 'piece', id: 'b'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => rule(strategy: piece('base'), rates: [rate('base', '1', 'kg')]),
        throwsArgumentError,
      );
      final definition = rule(
        strategy: piece('base'),
        rates: [
          rate('base', '1', 'piece', selectors: {'finish': 'plain'}),
        ],
        fields: [
          choice('finish', ['plain', 'polished']),
        ],
      );
      expect(
        () => price(
          definition,
          inputs: {'finish': const ChoiceInput('polished')},
        ),
        throwsStateError,
      );
    });
    test('no quantity tier gaps, boundary uses approved all-unit rate', () {
      final definition = examples
          .firstWhere((e) => e.name == 'quantityTier')
          .definition;
      expect(
        price(definition, quantity: 9).amounts.totalMinor,
        BigInt.from(108000),
      );
      expect(
        price(definition, quantity: 10).amounts.totalMinor,
        BigInt.from(100000),
      );
      expect(
        () => QuantityTierStrategy([QuantityTier(2, piece('base'))]),
        throwsArgumentError,
      );
      expect(
        () => QuantityTierStrategy([
          QuantityTier(1, piece('base')),
          QuantityTier(1, piece('other')),
        ]),
        throwsArgumentError,
      );
    });
    test('size slabs are half-open and gaps/overlaps never produce a guessed price', () {
      final definition = examples
          .firstWhere((e) => e.name == 'sizeSlab')
          .definition;
      expect(
        price(definition, inputs: {'width': n('0.99', 'm')}).amounts.totalMinor,
        BigInt.from(100000),
      );
      expect(
        () => price(definition, inputs: {'width': n('2', 'm')}),
        throwsStateError,
      );
      expect(
        () => rule(
          strategy: SizeSlabStrategy(
            bands: [
              SizeBand(
                id: 'a',
                ranges: {
                  'width': SlabRange(
                    unit: 'm',
                    minimum: e('0'),
                    maximum: e('2'),
                  ),
                },
                rateKey: 'a',
              ),
              SizeBand(
                id: 'b',
                ranges: {
                  'width': SlabRange(
                    unit: 'cm',
                    minimum: e('100'),
                    maximum: e('300'),
                  ),
                },
                rateKey: 'a',
              ),
            ],
          ),
          rates: [rate('a', '100', 'number')],
          fields: [number('width', 'm')],
        ),
        throwsArgumentError,
      );
    });
    test('minimum, wastage, increment and minimum charge are explicit', () {
      final definition = rule(
        strategy: measured(
          StrategyKind.area,
          ref('area'),
          'base',
          'm2',
          policy: BillableQuantityPolicy(
            unit: 'm2',
            wastePercent: e('10'),
            minimum: e('2'),
            increment: e('0.5'),
            minimumCharge: e('25'),
          ),
        ),
        rates: [rate('base', '10', 'm2')],
        fields: [number('area', 'm2')],
      );
      final result = price(
        definition,
        inputs: {'area': n('1', 'm2')},
        quantity: 2,
      );
      expect(result.base.single.measured, Exact.one);
      expect(result.base.single.billable, e('2'));
      expect(result.amounts.totalMinor, BigInt.from(5000));
      expect(result.warnings, hasLength(4));
      final exact = BillableQuantityPolicy(unit: 'm2').billing(e('1/3'));
      expect(exact, e('1/3'));
    });
    test(
      'dimension billing retains measured input and rejects rounded oversize',
      () {
        final definition = rule(
          strategy: measured(
            StrategyKind.area,
            mul(ref('height'), ref('width')),
            'base',
            'ft2',
          ),
          rates: [rate('base', '150', 'ft2')],
          fields: [
            number('height', 'in', max: '84'),
            number('width', 'in'),
          ],
          inputBilling: [
            InputBillingRule(fieldId: 'height', unit: 'in', increment: e('3')),
          ],
        );
        final result = price(
          definition,
          inputs: {'height': n('80', 'in'), 'width': n('36', 'in')},
        );
        expect(result.inputs.numbers['height']!.value, e('2.032'));
        expect(result.billableInputs['height']!.value, e('2.0574'));
        expect(result.amounts.totalMinor, BigInt.from(303750));
        expect(result.warnings.single, contains('81'));
        final invalid = rule(
          strategy: measured(StrategyKind.linear, ref('length'), 'base', 'm'),
          rates: [rate('base', '1', 'm')],
          fields: [number('length', 'm', max: '2')],
          inputBilling: [
            InputBillingRule(fieldId: 'length', unit: 'm', increment: e('3')),
          ],
        );
        expect(
          () => price(invalid, inputs: {'length': n('2', 'm')}),
          throwsArgumentError,
        );
      },
    );
    test(
      'once-per-order components and extras never multiply by item quantity',
      () {
        final definition = rule(
          strategy: piece('base'),
          rates: [rate('base', '10', 'piece'), rate('delivery', '50', 'piece')],
          fields: [toggle('deliver')],
          extras: [
            PriceComponent(
              id: 'delivery',
              label: 'Delivery',
              strategy: piece('delivery'),
              perOrder: true,
              enabledBy: 'deliver',
            ),
          ],
        );
        expect(
          price(definition, quantity: 3).amounts.totalMinor,
          BigInt.from(3000),
        );
        final result = price(
          definition,
          inputs: {'deliver': const BooleanInput(true)},
          quantity: 3,
        );
        expect(result.extraAmount, e('50'));
        expect(result.amounts.totalMinor, BigInt.from(8000));
        expect(
          () => rule(
            strategy: ComponentStrategy([
              PriceComponent(
                id: 'a',
                label: 'Bad',
                strategy: piece('base'),
                enabledBy: 'missing',
              ),
            ]),
            rates: [rate('base', '1', 'piece')],
          ),
          throwsArgumentError,
        );
      },
    );
    test(
      'same input values reprice across products and versions without mutation',
      () {
        final old = examples[1].definition;
        final original = price(old, inputs: examples[1].inputs, quantity: 2);
        final snapshot = original.snapshotJson;
        final json = jsonObject(canonicalJson(old.toJson()));
        json['version'] = 2;
        json['rates'][0]['amount'] = '200';
        final next = UniversalPricingRule.fromJson(json);
        final request = UniversalPricingRequest(
          inputs: next.schema.preserveFrom(old.schema, examples[1].inputs),
          quantity: 2,
        );
        expect(
          UniversalPricingEngine()
              .calculate(next, request, at: at)
              .amounts
              .totalMinor,
          BigInt.from(840000),
        );
        expect(original.snapshotJson, snapshot);
        expect(
          price(
            old,
            inputs: examples[1].inputs,
            quantity: 2,
          ).amounts.totalMinor,
          BigInt.from(630000),
        );
      },
    );
    test('missing hidden-dependent values never become zero implicitly', () {
      final definition = rule(
        strategy: measured(StrategyKind.linear, ref('length'), 'base', 'm'),
        rates: [rate('base', '1', 'm')],
        fields: [
          toggle('custom'),
          number(
            'length',
            'm',
            visibleWhen: VisibilityCondition('custom', true),
          ),
        ],
      );
      expect(() => price(definition), throwsArgumentError);
    });
  });

  group('financial result and lifecycle', () {
    test('a historical snapshot retains its original eligibility time after expiry', () {
      final definition = rule(
        strategy: piece('base'),
        rates: [rate('base', '10', 'piece')],
        expiresAt: at.add(const Duration(days: 1)),
      );
      final original = price(definition);
      final snapshot = jsonObject(original.snapshotJson);
      final restored = UniversalPricingRule.fromJson(
        snapshot['rule'] as Map<String, dynamic>,
      );
      final request = UniversalPricingRequest.fromJson(
        snapshot['request'] as Map<String, dynamic>,
      );
      expect(
        () => UniversalPricingEngine().calculate(
          restored,
          request,
          at: at.add(const Duration(days: 2)),
        ),
        throwsStateError,
      );
      expect(
        UniversalPricingEngine()
            .calculate(
              restored,
              request,
              at: DateTime.parse(snapshot['calculatedAt'] as String),
            )
            .snapshotJson,
        original.snapshotJson,
      );
    });
    for (final mode in TaxBehavior.values) {
      test(
        '${mode.name} configured tax follows extras and approved discounts',
        () {
          final definition = rule(
            strategy: piece('base'),
            rates: [rate('base', '100', 'piece')],
            tax: TaxPolicy(
              reference: 'business-tax',
              behavior: mode,
              percent: mode == TaxBehavior.exempt ? Exact.zero : e('12.5'),
            ),
            discount: DiscountPolicy(percent: e('10'), fixedPerLine: e('5')),
          );
          final result = price(definition, quantity: 2);
          expect(
            result.amounts.total,
            mode == TaxBehavior.exclusive ? e('196.875') : e('175'),
          );
          expect(
            result.amounts.netMinor + result.amounts.taxMinor,
            result.amounts.totalMinor,
          );
          expect(
            result.amounts.subtotalMinor - result.amounts.discountMinor,
            result.amounts.netMinor,
          );
        },
      );
    }
    for (final mode in MoneyRounding.values) {
      test('${mode.name} rounding only occurs at financial output', () {
        final definition = rule(
          strategy: piece('base'),
          rates: [rate('base', '0.005', 'piece')],
          rounding: mode,
        );
        final result = price(definition, quantity: 3);
        expect(result.unitBaseAmount, e('0.005'));
        expect(result.amounts.total, e('0.015'));
        expect(
          result.amounts.totalMinor,
          BigInt.from(mode == MoneyRounding.down ? 1 : 2),
        );
        expect(
          result.snapshotJson,
          price(definition, quantity: 3).snapshotJson,
        );
      });
    }
    test('invalid quantities, expiry and excessive discounts are explicit', () {
      for (final qty in [0, -1, 1000001]) {
        expect(
          () => UniversalPricingRequest(inputs: {}, quantity: qty),
          throwsArgumentError,
        );
      }
      final future = rule(
        strategy: piece('base'),
        rates: [rate('base', '1', 'piece')],
        effectiveAt: at.add(const Duration(days: 1)),
      );
      expect(() => price(future), throwsStateError);
      final expired = rule(
        strategy: piece('base'),
        rates: [rate('base', '1', 'piece')],
        effectiveAt: at.subtract(const Duration(days: 1)),
        expiresAt: at,
      );
      expect(() => price(expired), throwsStateError);
      final over = rule(
        strategy: piece('base'),
        rates: [rate('base', '1', 'piece')],
        discount: DiscountPolicy(fixedPerLine: e('2')),
      );
      expect(() => price(over), throwsStateError);
    });
    test('unsupported snapshot versions fail closed', () {
      final json = jsonObject(
        canonicalJson(examples.first.definition.toJson()),
      );
      json['engineVersion'] = 'future-engine';
      expect(() => UniversalPricingRule.fromJson(json), throwsFormatException);
    });
  });
}
