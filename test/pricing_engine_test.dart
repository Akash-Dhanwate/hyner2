import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/measurements.dart';
import 'package:hyner/features/pricing/domain/pricing_engine.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';

final _at = DateTime.utc(2026, 11, 8, 12);

Exact _e(String value) => Exact.parse(value);

Dimensions _dimensions({
  String height = '84',
  String width = '36',
  String? depth,
  LengthUnit unit = LengthUnit.inches,
}) => Dimensions.entered({
  Axis.height: _e(height),
  Axis.width: _e(width),
  if (depth != null) Axis.depth: _e(depth),
}, unit);

PricingInput _input({
  String categoryId = 'panels',
  String? variantId,
  Dimensions? dimensions,
  int quantity = 1,
  Exact? weight,
  Set<String> selected = const {},
  Map<String, Exact> addonQuantities = const {},
}) => PricingInput(
  categoryId: categoryId,
  variantId: variantId,
  dimensions: dimensions ?? _dimensions(),
  quantity: quantity,
  weightKilograms: weight,
  selectedAddonIds: selected,
  addonQuantities: addonQuantities,
);

PricingRule _rule({
  String id = 'panel_rate',
  String categoryId = 'panels',
  String? variantId,
  PricingMethod method = PricingMethod.squareFoot,
  String rate = '150',
  BillingPolicy? billing,
  DiscountPolicy? discount,
  TaxPolicy? tax,
  List<String> addonIds = const [],
}) => PricingRule(
  id: id,
  categoryId: categoryId,
  variantId: variantId,
  method: method,
  rate: _e(rate),
  billing: billing,
  discount: discount,
  tax: tax ?? _tax(TaxBehavior.exempt, '0'),
  addonIds: addonIds,
);

TaxPolicy _tax(TaxBehavior behavior, String percent) => TaxPolicy(
  reference: 'business-configured-tax',
  behavior: behavior,
  percent: _e(percent),
);

PricingAddon _addon(
  String id,
  AddonMethod method,
  String rate, {
  bool required = false,
  bool included = false,
}) => PricingAddon(
  id: id,
  name: 'Add-on $id',
  method: method,
  rate: _e(rate),
  required: required,
  included: included,
);

// Deliberately allows unpublished/legacy configurations: calculate must also
// reject unavailable rates when publication validation has been bypassed.
PublishedRateCard _card({
  List<PricingRule>? rules,
  List<PricingCategory>? categories,
  List<PricingVariant> variants = const [],
  List<PricingAddon> addons = const [],
  Currency? currency,
  MoneyRounding rounding = MoneyRounding.halfUp,
  int version = 1,
  DateTime? effectiveAt,
  DateTime? expiresAt,
}) => PublishedRateCard(
  businessId: 'business_1',
  profileId: 'retail',
  version: version,
  publishedBy: 'owner_1',
  publishedAt: DateTime.utc(2026, 1, 1),
  effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 1),
  expiresAt: expiresAt,
  card: RateCardDraft(
    name: 'Approved retail rates',
    currency: currency ?? Currency('INR', 2),
    rounding: rounding,
    categories: categories ?? [PricingCategory(id: 'panels', name: 'Panels')],
    variants: variants,
    rules: rules ?? [_rule()],
    addons: addons,
  ),
);

PriceBreakdown _price({
  PricingRule? rule,
  PricingInput? input,
  List<PricingAddon> addons = const [],
  Currency? currency,
  MoneyRounding rounding = MoneyRounding.halfUp,
}) => PricingEngine().calculate(
  _card(
    rules: [rule ?? _rule()],
    addons: addons,
    currency: currency,
    rounding: rounding,
  ),
  input ?? _input(),
  at: _at,
);

void _expectMoney(
  PriceBreakdown result, {
  required int subtotal,
  int discount = 0,
  required int net,
  int tax = 0,
  required int total,
}) {
  expect(result.subtotalMinor, BigInt.from(subtotal));
  expect(result.discountMinor, BigInt.from(discount));
  expect(result.netMinor, BigInt.from(net));
  expect(result.taxMinor, BigInt.from(tax));
  expect(result.totalMinor, BigInt.from(total));
  expect(result.subtotalMinor - result.discountMinor, result.netMinor);
  expect(result.netMinor + result.taxMinor, result.totalMinor);
}

void main() {
  group('measurements and category selection', () {
    test('84 by 36 inches at 150 per square foot, quantity 3', () {
      final dimensions = _dimensions();
      final input = _input(dimensions: dimensions, quantity: 3);
      final result = _price(input: input);

      expect(dimensions.squareFeet, _e('21'));
      expect(result.input, same(input));
      expect(result.billableDimensions, same(dimensions));
      expect(result.measuredQuantity, _e('21'));
      expect(result.billableQuantity, _e('21'));
      expect(result.unitBasePrice, _e('3150'));
      expect(result.basePrice, _e('9450'));
      expect(result.addonAmounts, isEmpty);
      expect(result.policies, isEmpty);
      _expectMoney(result, subtotal: 945000, net: 945000, total: 945000);
    });

    test('switching categories reuses dimensions with independent rates', () {
      final engine = PricingEngine();
      final card = _card(
        categories: [
          PricingCategory(id: 'panels', name: 'Panels'),
          PricingCategory(id: 'glass', name: 'Glass'),
        ],
        rules: [
          _rule(),
          _rule(id: 'glass_rate', categoryId: 'glass', rate: '225'),
        ],
      );
      final dimensions = _dimensions();
      final before = jsonEncode(dimensions.toJson());
      final original = PricingInput(
        categoryId: 'panels',
        dimensions: dimensions,
        quantity: 3,
      );
      final switched = PricingInput(
        categoryId: 'glass',
        dimensions: original.dimensions,
        quantity: original.quantity,
      );

      final panel = engine.calculate(card, original, at: _at);
      final glass = engine.calculate(card, switched, at: _at);
      final panelAgain = engine.calculate(card, original, at: _at);

      expect(switched, isNot(same(original)));
      expect(switched.dimensions, same(original.dimensions));
      expect(glass.input, same(switched));
      expect(glass.billableDimensions, same(dimensions));
      expect(glass.measuredQuantity, _e('21'));
      expect(original.categoryId, 'panels');
      expect(jsonEncode(dimensions.toJson()), before);
      expect(panel.rule.rate, _e('150'));
      expect(glass.rule.rate, _e('225'));
      expect(panel.totalMinor, BigInt.from(945000));
      expect(glass.totalMinor, BigInt.from(1417500));
      expect(panelAgain.snapshotJson, panel.snapshotJson);
    });

    final methodCases = [
      (
        method: PricingMethod.piece,
        dimensions: Dimensions({}),
        weight: null,
        measured: '1',
        total: 45000,
      ),
      (
        method: PricingMethod.squareFoot,
        dimensions: _dimensions(),
        weight: null,
        measured: '21',
        total: 945000,
      ),
      (
        method: PricingMethod.squareMetre,
        dimensions: _dimensions(
          height: '200',
          width: '150',
          unit: LengthUnit.centimetres,
        ),
        weight: null,
        measured: '3',
        total: 135000,
      ),
      (
        method: PricingMethod.runningFoot,
        dimensions: Dimensions.entered({
          Axis.height: _e('90'),
        }, LengthUnit.inches),
        weight: null,
        measured: '7.5',
        total: 337500,
      ),
      (
        method: PricingMethod.metre,
        dimensions: Dimensions.entered({
          Axis.height: _e('2500'),
        }, LengthUnit.millimetres),
        weight: null,
        measured: '2.5',
        total: 112500,
      ),
      (
        method: PricingMethod.cubicMetre,
        dimensions: _dimensions(
          height: '2',
          width: '1.5',
          depth: '0.5',
          unit: LengthUnit.metres,
        ),
        weight: null,
        measured: '1.5',
        total: 67500,
      ),
      (
        method: PricingMethod.kilogram,
        dimensions: Dimensions({}),
        weight: _e('2.5'),
        measured: '2.5',
        total: 112500,
      ),
    ];
    for (final c in methodCases) {
      test('${c.method.name} measures and prices its own unit', () {
        final result = _price(
          rule: _rule(method: c.method),
          input: _input(
            dimensions: c.dimensions,
            weight: c.weight,
            quantity: 3,
          ),
        );
        expect(result.measuredQuantity, _e(c.measured));
        expect(result.billableQuantity, _e(c.measured));
        _expectMoney(result, subtotal: c.total, net: c.total, total: c.total);
      });
    }

    test('mixed feet and inches retain fractional feet', () {
      final result = _price(
        input: _input(
          dimensions: Dimensions({
            Axis.height: Dimensions.feetAndInches(feet: 7, inches: _e('6')),
            Axis.width: Dimensions.feetAndInches(feet: 3, inches: Exact.zero),
          }, enteredUnit: LengthUnit.feetInches),
        ),
      );
      expect(result.measuredQuantity, _e('22.5'));
      expect(result.totalMinor, BigInt.from(337500));
    });
  });

  group('invalid or unavailable inputs', () {
    for (final quantity in [-1, 0, 1000001]) {
      test('quantity $quantity is rejected at the input boundary', () {
        expect(() => _input(quantity: quantity), throwsArgumentError);
      });
    }

    test('the maximum quantity remains supported', () {
      final result = _price(
        rule: _rule(method: PricingMethod.piece, rate: '0.01'),
        input: _input(quantity: 1000000, dimensions: Dimensions({})),
      );
      expect(result.totalMinor, BigInt.from(1000000));
    });

    for (final axis in Axis.values) {
      for (final value in ['-1', '0', '1000000.0001']) {
        test('${axis.name} dimension $value metres is rejected', () {
          expect(() => Dimensions({axis: _e(value)}), throwsArgumentError);
        });
      }
    }

    final missingAxes = [
      (
        method: PricingMethod.squareFoot,
        dimensions: Dimensions({Axis.height: Exact.one}),
      ),
      (
        method: PricingMethod.squareMetre,
        dimensions: Dimensions({Axis.width: Exact.one}),
      ),
      (
        method: PricingMethod.runningFoot,
        dimensions: Dimensions({Axis.width: Exact.one}),
      ),
      (method: PricingMethod.metre, dimensions: Dimensions({})),
      (method: PricingMethod.cubicMetre, dimensions: _dimensions()),
    ];
    for (final c in missingAxes) {
      test('${c.method.name} cannot price missing dimensions', () {
        expect(
          () => _price(
            rule: _rule(method: c.method),
            input: _input(dimensions: c.dimensions),
          ),
          throwsArgumentError,
        );
      });
    }

    test('kilogram pricing requires a weight', () {
      expect(
        () => _price(rule: _rule(method: PricingMethod.kilogram)),
        throwsArgumentError,
      );
    });

    for (final value in ['-1', '0', '1000000.0001']) {
      test('weight $value kilograms is rejected', () {
        expect(() => _input(weight: _e(value)), throwsArgumentError);
      });
    }

    for (final categoryId in ['unknown', 'inactive']) {
      test('$categoryId category cannot obtain a quote', () {
        final card = _card(
          categories: [
            PricingCategory(id: 'panels', name: 'Panels'),
            PricingCategory(id: 'inactive', name: 'Inactive', active: false),
          ],
          rules: [
            _rule(),
            _rule(id: 'inactive_rate', categoryId: 'inactive'),
          ],
        );
        expect(
          () => PricingEngine().calculate(
            card,
            _input(categoryId: categoryId),
            at: _at,
          ),
          throwsStateError,
        );
      });
    }

    test('an active variant must be selected and belong to the category', () {
      final card = _card(
        categories: [
          PricingCategory(id: 'panels', name: 'Panels'),
          PricingCategory(id: 'glass', name: 'Glass'),
        ],
        variants: [
          PricingVariant(id: 'oak', categoryId: 'panels', name: 'Oak'),
          PricingVariant(id: 'pine', categoryId: 'panels', name: 'Pine'),
          PricingVariant(
            id: 'retired',
            categoryId: 'panels',
            name: 'Retired',
            active: false,
          ),
          PricingVariant(id: 'clear', categoryId: 'glass', name: 'Clear'),
        ],
        rules: [
          // A category fallback must not bypass an active variant requirement.
          _rule(),
          _rule(id: 'oak_rate', variantId: 'oak', rate: '200'),
          _rule(id: 'pine_rate', variantId: 'pine', rate: '100'),
          _rule(id: 'retired_rate', variantId: 'retired'),
          _rule(id: 'clear_rate', categoryId: 'glass', variantId: 'clear'),
        ],
      );
      final engine = PricingEngine();
      for (final variant in <String?>[null, 'unknown', 'retired', 'clear']) {
        expect(
          () => engine.calculate(card, _input(variantId: variant), at: _at),
          throwsStateError,
          reason: 'Invalid panel variant: $variant',
        );
      }
      expect(
        engine.calculate(card, _input(variantId: 'oak'), at: _at).totalMinor,
        BigInt.from(420000),
      );
      expect(
        engine.calculate(card, _input(variantId: 'pine'), at: _at).totalMinor,
        BigInt.from(210000),
      );
    });

    test('missing rates fail at publication and calculation', () {
      final card = _card(rules: []);
      expect(card.card.validateForPublish, throwsStateError);
      expect(
        () => PricingEngine().calculate(card, _input(), at: _at),
        throwsStateError,
      );
    });

    test('a variant without a rate cannot fall back to the category rate', () {
      final card = _card(
        variants: [
          PricingVariant(id: 'oak', categoryId: 'panels', name: 'Oak'),
        ],
      );
      expect(card.card.validateForPublish, throwsStateError);
      expect(
        () =>
            PricingEngine().calculate(card, _input(variantId: 'oak'), at: _at),
        throwsStateError,
      );
    });

    test('ambiguous rates are rejected by the card model', () {
      expect(
        () => _card(
          rules: [
            _rule(),
            _rule(id: 'duplicate_target', rate: '200'),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('add-ons', () {
    test(
      'required and included apply automatically, optional requires selection',
      () {
        final addons = [
          _addon('required', AddonMethod.perOrder, '10', required: true),
          // Included quantities need no input and must never charge their rate.
          _addon('included', AddonMethod.quantity, '999', included: true),
          _addon(
            'both',
            AddonMethod.perItem,
            '999',
            required: true,
            included: true,
          ),
          _addon('optional', AddonMethod.perItem, '5'),
        ];
        final rule = _rule(
          method: PricingMethod.piece,
          rate: '100',
          addonIds: addons.map((a) => a.id).toList(),
        );
        final unselected = _price(
          rule: rule,
          addons: addons,
          input: _input(quantity: 3),
        );
        final selected = _price(
          rule: rule,
          addons: addons,
          input: _input(
            quantity: 3,
            selected: {'optional', 'included', 'required', 'both'},
          ),
        );
        expect(unselected.addonAmounts, {
          'required': _e('10'),
          'included': Exact.zero,
          'both': Exact.zero,
        });
        expect(selected.addonAmounts, {
          'required': _e('10'),
          'included': Exact.zero,
          'both': Exact.zero,
          'optional': _e('15'),
        });
        _expectMoney(unselected, subtotal: 31000, net: 31000, total: 31000);
        _expectMoney(selected, subtotal: 32500, net: 32500, total: 32500);
      },
    );

    test('every add-on method uses its own basis without compounding', () {
      final addons = [
        _addon('order', AddonMethod.perOrder, '25'),
        _addon('item', AddonMethod.perItem, '12.5'),
        _addon('area', AddonMethod.perSquareFoot, '2'),
        _addon('length', AddonMethod.perRunningFoot, '4'),
        _addon('percentage', AddonMethod.percentage, '7.5'),
        _addon('quantity', AddonMethod.quantity, '6'),
      ];
      final ids = addons.map((a) => a.id).toList();
      final result = _price(
        rule: _rule(addonIds: ids),
        addons: addons,
        input: _input(
          quantity: 3,
          selected: ids.toSet(),
          addonQuantities: {'quantity': _e('2.5')},
        ),
      );
      expect(result.basePrice, _e('9450'));
      expect(result.addonAmounts, {
        'order': _e('25'),
        'item': _e('37.5'),
        'area': _e('126'),
        'length': _e('84'),
        'percentage': _e('708.75'),
        'quantity': _e('15'),
      });
      _expectMoney(result, subtotal: 1044625, net: 1044625, total: 1044625);
    });

    test('area and length add-ons use the dimensions selected for billing', () {
      final addons = [
        _addon('area', AddonMethod.perSquareFoot, '2', required: true),
        _addon('length', AddonMethod.perRunningFoot, '4', required: true),
      ];
      final result = _price(
        rule: _rule(
          addonIds: ['area', 'length'],
          billing: BillingPolicy(
            dimensionIncrementMetres: _e('0.3048'),
            stockedSizes: [_dimensions(height: '36', width: '24')],
          ),
        ),
        addons: addons,
        input: _input(
          dimensions: _dimensions(height: '13', width: '13'),
          quantity: 3,
        ),
      );
      expect(result.measuredQuantity, _e('169/144'));
      expect(result.billableQuantity, _e('6'));
      expect(result.basePrice, _e('2700'));
      expect(result.addonAmounts, {'area': _e('36'), 'length': _e('36')});
      _expectMoney(result, subtotal: 277200, net: 277200, total: 277200);
    });

    test('percentage add-on includes the minimum per-item base charge', () {
      final result = _price(
        rule: _rule(
          method: PricingMethod.piece,
          rate: '10',
          billing: BillingPolicy(minimumPrice: _e('20')),
          addonIds: ['percentage'],
        ),
        addons: [
          _addon('percentage', AddonMethod.percentage, '10', required: true),
        ],
        input: _input(quantity: 3),
      );
      expect(result.basePrice, _e('60'));
      expect(result.addonAmounts['percentage'], _e('6'));
      expect(result.totalMinor, BigInt.from(6600));
    });

    for (final required in [false, true]) {
      test(
        '${required ? 'required' : 'selected'} quantity add-on needs its quantity',
        () {
          expect(
            () => _price(
              rule: _rule(addonIds: ['quantity']),
              addons: [
                _addon(
                  'quantity',
                  AddonMethod.quantity,
                  '6',
                  required: required,
                ),
              ],
              input: _input(selected: required ? {} : {'quantity'}),
            ),
            throwsArgumentError,
          );
        },
      );
    }

    test('unselected optional quantity add-on does not need a quantity', () {
      final result = _price(
        rule: _rule(addonIds: ['quantity']),
        addons: [_addon('quantity', AddonMethod.quantity, '6')],
      );
      expect(result.addonAmounts, isEmpty);
      expect(result.totalMinor, BigInt.from(315000));
    });

    for (final value in ['-1', '0', '1000000.0001']) {
      test('add-on quantity $value is rejected at the input boundary', () {
        expect(
          () => _input(addonQuantities: {'quantity': _e(value)}),
          throwsArgumentError,
        );
      });
    }

    test(
      'the maximum add-on quantity is supported independently of item count',
      () {
        final result = _price(
          rule: _rule(
            method: PricingMethod.piece,
            rate: '0',
            addonIds: ['quantity'],
          ),
          addons: [
            _addon('quantity', AddonMethod.quantity, '0.01', required: true),
          ],
          input: _input(
            quantity: 3,
            addonQuantities: {'quantity': _e('1000000')},
          ),
        );
        expect(result.addonAmounts['quantity'], _e('10000'));
        expect(result.totalMinor, BigInt.from(1000000));
      },
    );

    for (final id in ['unrelated', 'unknown']) {
      test('$id selected add-on is rejected', () {
        expect(
          () => _price(
            addons: [_addon('unrelated', AddonMethod.perOrder, '1')],
            input: _input(selected: {id}),
          ),
          throwsArgumentError,
        );
      });
      test('$id add-on quantity is rejected even without selection', () {
        expect(
          () => _price(
            addons: [_addon('unrelated', AddonMethod.quantity, '1')],
            input: _input(addonQuantities: {id: Exact.one}),
          ),
          throwsArgumentError,
        );
      });
    }

    test(
      'a required add-on for a different rule does not leak into the price',
      () {
        final result = _price(
          addons: [
            _addon('unrelated', AddonMethod.perOrder, '999', required: true),
          ],
        );
        expect(result.addonAmounts, isEmpty);
        expect(result.totalMinor, BigInt.from(315000));
      },
    );
  });

  group('discounts and configured taxes', () {
    for (final c in [
      (
        quantity: 2,
        gross: 22000,
        discount: '0',
        discountMinor: 0,
        total: 22000,
      ),
      (
        quantity: 3,
        gross: 32000,
        discount: '37',
        discountMinor: 3700,
        total: 28300,
      ),
      (
        quantity: 4,
        gross: 42000,
        discount: '47',
        discountMinor: 4700,
        total: 37300,
      ),
    ]) {
      test('fixed plus percentage discount at quantity ${c.quantity}', () {
        final result = _price(
          rule: _rule(
            method: PricingMethod.piece,
            rate: '100',
            addonIds: ['order'],
            discount: DiscountPolicy(
              minimumQuantity: 3,
              percent: _e('10'),
              fixedPerLine: _e('5'),
            ),
          ),
          addons: [_addon('order', AddonMethod.perOrder, '20', required: true)],
          input: _input(quantity: c.quantity),
        );
        expect(result.discount, _e(c.discount));
        _expectMoney(
          result,
          subtotal: c.gross,
          discount: c.discountMinor,
          net: c.total,
          total: c.total,
        );
      });
    }

    test('discount equal to the gross amount yields a zero total', () {
      final result = _price(
        rule: _rule(
          method: PricingMethod.piece,
          rate: '100',
          discount: DiscountPolicy(percent: _e('90'), fixedPerLine: _e('10')),
          tax: _tax(TaxBehavior.exclusive, '7.25'),
        ),
      );
      expect(result.discount, _e('100'));
      expect(result.tax, Exact.zero);
      _expectMoney(result, subtotal: 10000, discount: 10000, net: 0, total: 0);
    });

    test('discount above the gross amount fails instead of making a negative price', () {
      expect(
        () => _price(
          rule: _rule(
            method: PricingMethod.piece,
            rate: '100',
            discount: DiscountPolicy(
              percent: _e('90'),
              fixedPerLine: _e('10.01'),
            ),
          ),
        ),
        throwsStateError,
      );
    });

    test(
      'a discount below its quantity threshold is not applied or rejected',
      () {
        final result = _price(
          rule: _rule(
            method: PricingMethod.piece,
            rate: '100',
            discount: DiscountPolicy(
              minimumQuantity: 3,
              fixedPerLine: _e('1000'),
            ),
          ),
        );
        expect(result.discount, Exact.zero);
        expect(result.totalMinor, BigInt.from(10000));
      },
    );

    final taxCases = [
      (
        behavior: TaxBehavior.exclusive,
        percent: '7.25',
        net: '210.21',
        tax: '15.240225',
        total: '225.450225',
        subtotalMinor: 23595,
        discountMinor: 2574,
        netMinor: 21021,
        taxMinor: 1524,
        totalMinor: 22545,
      ),
      (
        behavior: TaxBehavior.inclusive,
        percent: '7.25',
        net: '196',
        tax: '14.21',
        total: '210.21',
        subtotalMinor: 22000,
        discountMinor: 2400,
        netMinor: 19600,
        taxMinor: 1421,
        totalMinor: 21021,
      ),
      (
        behavior: TaxBehavior.exempt,
        percent: '0',
        net: '210.21',
        tax: '0',
        total: '210.21',
        subtotalMinor: 23595,
        discountMinor: 2574,
        netMinor: 21021,
        taxMinor: 0,
        totalMinor: 21021,
      ),
    ];
    for (final c in taxCases) {
      test(
        '${c.behavior.name} configured tax follows add-ons and both discounts',
        () {
          final result = _price(
            rule: _rule(
              method: PricingMethod.piece,
              rate: '107.25',
              addonIds: ['order'],
              discount: DiscountPolicy(
                percent: _e('10'),
                fixedPerLine: _e('2.145'),
              ),
              tax: _tax(c.behavior, c.percent),
            ),
            addons: [
              _addon('order', AddonMethod.perOrder, '21.45', required: true),
            ],
            input: _input(quantity: 2),
          );
          expect(result.basePrice, _e('214.5'));
          expect(result.addonAmounts['order'], _e('21.45'));
          expect(result.discount, _e('25.74'));
          expect(result.excludingTax, _e(c.net));
          expect(result.tax, _e(c.tax));
          expect(result.includingTax, _e(c.total));
          _expectMoney(
            result,
            subtotal: c.subtotalMinor,
            discount: c.discountMinor,
            net: c.netMinor,
            tax: c.taxMinor,
            total: c.totalMinor,
          );
        },
      );
    }

    for (final c in [
      (percent: '0', tax: 0, total: 10000),
      (percent: '12.5', tax: 1250, total: 11250),
      (percent: '19.6', tax: 1960, total: 11960),
      (percent: '100', tax: 10000, total: 20000),
    ]) {
      test('exclusive tax honors configured ${c.percent} percent', () {
        final result = _price(
          rule: _rule(
            method: PricingMethod.piece,
            rate: '100',
            tax: _tax(TaxBehavior.exclusive, c.percent),
          ),
        );
        _expectMoney(
          result,
          subtotal: 10000,
          net: 10000,
          tax: c.tax,
          total: c.total,
        );
      });
    }

    test(
      'exemption rejects a nonzero configured tax instead of ignoring it',
      () {
        expect(() => _tax(TaxBehavior.exempt, '7.25'), throwsArgumentError);
      },
    );
  });

  group('rounding and snapshots', () {
    for (final c in [
      (mode: MoneyRounding.halfUp, discount: 0, net: 5, tax: 0, total: 5),
      (mode: MoneyRounding.halfEven, discount: 1, net: 4, tax: 1, total: 5),
      (mode: MoneyRounding.down, discount: 1, net: 4, tax: 0, total: 4),
    ]) {
      test('${c.mode.name} reconciles fractional discount and tax residuals', () {
        final rule = _rule(
          method: PricingMethod.piece,
          rate: '0.05',
          discount: DiscountPolicy(fixedPerLine: _e('0.005')),
          tax: _tax(TaxBehavior.exclusive, '10'),
        );
        final result = _price(rule: rule, rounding: c.mode);
        expect(result.discount, _e('0.005'));
        expect(result.excludingTax, _e('0.045'));
        expect(result.tax, _e('0.0045'));
        expect(result.includingTax, _e('0.0495'));
        // These are allocated display amounts, not independently rounded lines.
        _expectMoney(
          result,
          subtotal: 5,
          discount: c.discount,
          net: c.net,
          tax: c.tax,
          total: c.total,
        );
        expect(
          _price(rule: rule, rounding: c.mode).snapshotJson,
          result.snapshotJson,
        );
      });
    }

    for (final c in [
      (mode: MoneyRounding.halfUp, net: 5, tax: 0, total: 5),
      (mode: MoneyRounding.halfEven, net: 4, tax: 1, total: 5),
      (mode: MoneyRounding.down, net: 4, tax: 0, total: 4),
    ]) {
      test(
        '${c.mode.name} reconciles inclusive tax at a half-minor-unit net',
        () {
          final result = _price(
            rule: _rule(
              method: PricingMethod.piece,
              rate: '0.0495',
              tax: _tax(TaxBehavior.inclusive, '10'),
            ),
            rounding: c.mode,
          );
          expect(result.excludingTax, _e('0.045'));
          expect(result.tax, _e('0.0045'));
          expect(result.includingTax, _e('0.0495'));
          _expectMoney(
            result,
            subtotal: c.net,
            net: c.net,
            tax: c.tax,
            total: c.total,
          );
        },
      );
    }

    test('rounding occurs after quantity multiplication', () {
      final result = _price(
        rule: _rule(method: PricingMethod.piece, rate: '0.005'),
        input: _input(quantity: 3),
      );
      expect(result.unitBasePrice, _e('0.005'));
      expect(result.basePrice, _e('0.015'));
      _expectMoney(result, subtotal: 2, net: 2, total: 2);
    });

    for (final c in [
      (digits: 0, total: 1),
      (digits: 1, total: 12),
      (digits: 2, total: 123),
      (digits: 3, total: 1235),
      (digits: 4, total: 12345),
    ]) {
      test('configured currency with ${c.digits} minor digits', () {
        final result = _price(
          rule: _rule(method: PricingMethod.piece, rate: '1.2345'),
          currency: Currency('XTS', c.digits),
        );
        _expectMoney(result, subtotal: c.total, net: c.total, total: c.total);
      });
    }

    test('large supported prices preserve every minor unit', () {
      final result = _price(
        rule: _rule(method: PricingMethod.piece, rate: '1000000000000'),
        input: _input(quantity: 1000000),
      );
      expect(result.basePrice, _e('1000000000000000000'));
      expect(result.totalMinor, BigInt.parse('100000000000000000000'));
      expect(result.netMinor, result.totalMinor);
      expect(result.taxMinor, BigInt.zero);
      expect(result.toJson()['totalMinor'], '100000000000000000000');
    });

    test(
      'equivalent input map and selection orders produce identical snapshots',
      () {
        final card = _card(
          rules: [
            _rule(addonIds: ['a', 'b']),
          ],
          addons: [
            _addon('b', AddonMethod.quantity, '0.2'),
            _addon('a', AddonMethod.quantity, '0.1'),
          ],
        );
        final first = _input(
          dimensions: Dimensions.entered({
            Axis.height: _e('84'),
            Axis.width: _e('36'),
          }, LengthUnit.inches),
          selected: {'b', 'a'},
          addonQuantities: {'b': _e('2'), 'a': _e('3')},
        );
        final second = _input(
          dimensions: Dimensions.entered({
            Axis.width: _e('36'),
            Axis.height: _e('84'),
          }, LengthUnit.inches),
          selected: {'a', 'b'},
          addonQuantities: {'a': _e('3'), 'b': _e('2')},
        );
        final engine = PricingEngine();
        final result = engine.calculate(card, first, at: _at);
        expect(result.totalMinor, BigInt.from(315070));
        expect(
          engine.calculate(card, second, at: _at).snapshotJson,
          result.snapshotJson,
        );
        expect(jsonDecode(result.snapshotJson)['input']['selectedAddonIds'], [
          'a',
          'b',
        ]);
      },
    );

    test('historical snapshots retain rules, definitions and totals after new rates', () {
      final engine = PricingEngine();
      final input = _input(variantId: 'oak', quantity: 3);
      final oldCard = _card(
        version: 7,
        categories: [PricingCategory(id: 'panels', name: 'Original panels')],
        variants: [
          PricingVariant(
            id: 'oak',
            categoryId: 'panels',
            name: 'Original oak',
            attributes: {'finish': 'natural'},
          ),
        ],
        rules: [
          _rule(
            variantId: 'oak',
            method: PricingMethod.piece,
            rate: '100',
            billing: BillingPolicy(minimumQuantity: 2, minimumPrice: _e('90')),
            discount: DiscountPolicy(percent: _e('10'), fixedPerLine: _e('5')),
            tax: _tax(TaxBehavior.exclusive, '7.25'),
            addonIds: ['order'],
          ),
        ],
        addons: [_addon('order', AddonMethod.perOrder, '20', required: true)],
      );
      final oldResult = engine.calculate(oldCard, input, at: _at);
      final saved = oldResult.snapshotJson;
      final snapshot = jsonDecode(saved) as Map<String, dynamic>;
      final newCard = _card(
        version: 8,
        categories: [PricingCategory(id: 'panels', name: 'Renamed panels')],
        variants: [
          PricingVariant(
            id: 'oak',
            categoryId: 'panels',
            name: 'Renamed oak',
            attributes: {'finish': 'painted'},
          ),
        ],
        rules: [
          _rule(
            variantId: 'oak',
            method: PricingMethod.piece,
            rate: '200',
            tax: _tax(TaxBehavior.exclusive, '12.5'),
            addonIds: ['order'],
          ),
        ],
        addons: [_addon('order', AddonMethod.perOrder, '40', required: true)],
      );
      expect(
        engine.calculate(newCard, input, at: _at).totalMinor,
        BigInt.from(72000),
      );
      _expectMoney(
        oldResult,
        subtotal: 32000,
        discount: 3700,
        net: 28300,
        tax: 2052,
        total: 30352,
      );
      expect(oldResult.snapshotJson, saved);
      expect(snapshot['engineVersion'], 'quickprice-1');
      expect(snapshot['snapshotVersion'], 1);
      expect(snapshot['businessId'], 'business_1');
      expect(snapshot['profileId'], 'retail');
      expect(snapshot['rateCardVersion'], 7);
      expect(snapshot['currency'], {'code': 'INR', 'minorDigits': 2});
      expect(snapshot['moneyRounding'], 'halfUp');
      expect(snapshot['input'], input.toJson());
      expect(snapshot['categoryName'], 'Original panels');
      expect(snapshot['variant'], {
        'id': 'oak',
        'categoryId': 'panels',
        'name': 'Original oak',
        'attributes': {'finish': 'natural'},
        'active': true,
      });
      expect(snapshot['rule']['rate'], '100');
      expect(snapshot['rule']['billing']['minimumQuantity'], 2);
      expect(snapshot['rule']['billing']['minimumPrice'], '90');
      expect(snapshot['rule']['discount'], {
        'minimumQuantity': 1,
        'fixedPerLine': '5',
        'percent': '10',
      });
      expect(snapshot['rule']['tax'], {
        'reference': 'business-configured-tax',
        'behavior': 'exclusive',
        'percent': '29/4',
      });
      expect(snapshot['addonDefinitions'], [
        {
          'id': 'order',
          'name': 'Add-on order',
          'method': 'perOrder',
          'rate': '20',
          'required': true,
          'included': false,
          'defaultSelected': false,
        },
      ]);
      expect(snapshot['addonAmounts'], {'order': '20'});
      expect(snapshot['discount'], '37');
      expect(snapshot['excludingTax'], '283');
      expect(snapshot['tax'], '8207/400');
      expect(snapshot['includingTax'], '121407/400');
      expect(snapshot['totalMinor'], '30352');

      final restored = PublishedRateCard.fromJson(
        jsonDecode(jsonEncode(oldCard.toJson())) as Map<String, dynamic>,
      );
      expect(engine.calculate(restored, input, at: _at).snapshotJson, saved);
    });

    test(
      'caller collection mutations cannot change an existing calculation',
      () {
        final metres = {Axis.height: _e('2'), Axis.width: _e('1')};
        final selected = {'extra'};
        final quantities = {'extra': _e('2')};
        final addonIds = ['extra'];
        final addons = [_addon('extra', AddonMethod.quantity, '3')];
        final rules = [
          _rule(
            method: PricingMethod.squareMetre,
            rate: '100',
            addonIds: addonIds,
          ),
        ];
        final card = _card(rules: rules, addons: addons);
        final input = _input(
          dimensions: Dimensions(metres),
          selected: selected,
          addonQuantities: quantities,
        );
        final result = PricingEngine().calculate(card, input, at: _at);
        final saved = result.snapshotJson;
        metres[Axis.height] = _e('99');
        selected.clear();
        quantities['extra'] = _e('99');
        addonIds.clear();
        addons.clear();
        rules.clear();
        expect(result.totalMinor, BigInt.from(20600));
        expect(result.snapshotJson, saved);
        expect(
          PricingEngine().calculate(card, input, at: _at).snapshotJson,
          saved,
        );
        expect(() => input.dimensions.metres.clear(), throwsUnsupportedError);
        expect(() => input.selectedAddonIds.clear(), throwsUnsupportedError);
        expect(() => input.addonQuantities.clear(), throwsUnsupportedError);
        expect(() => result.addonAmounts.clear(), throwsUnsupportedError);
        expect(() => result.policies.add('changed'), throwsUnsupportedError);
      },
    );
  });

  group('rate-card validity and unsupported methods', () {
    test('effective time is inclusive and expiration is exclusive', () {
      final start = DateTime.utc(2026, 11, 1);
      final end = DateTime.utc(2026, 12, 1);
      final card = _card(effectiveAt: start, expiresAt: end);
      final input = _input();
      final engine = PricingEngine();
      expect(
        () => engine.calculate(
          card,
          input,
          at: start.subtract(const Duration(microseconds: 1)),
        ),
        throwsStateError,
      );
      expect(
        engine.calculate(card, input, at: start).totalMinor,
        BigInt.from(315000),
      );
      expect(
        engine
            .calculate(
              card,
              input,
              at: end.subtract(const Duration(microseconds: 1)),
            )
            .totalMinor,
        BigInt.from(315000),
      );
      expect(() => engine.calculate(card, input, at: end), throwsStateError);
      expect(
        () =>
            engine.calculate(card, input, at: end.add(const Duration(days: 1))),
        throwsStateError,
      );
    });

    test(
      'a future card is rejected using the explicitly supplied quote time',
      () {
        expect(
          () => PricingEngine().calculate(
            _card(effectiveAt: _at.add(const Duration(days: 1))),
            _input(),
            at: _at,
          ),
          throwsStateError,
        );
      },
    );

    test('a card without expiration remains eligible for later replay', () {
      expect(
        PricingEngine()
            .calculate(_card(), _input(), at: DateTime.utc(2100))
            .totalMinor,
        BigInt.from(315000),
      );
    });

    for (final method in [
      PricingMethod.quantityTier,
      PricingMethod.dimensionRange,
      PricingMethod.customFormula,
      PricingMethod.composite,
    ]) {
      test('${method.name} fails closed at publication and calculation', () {
        final rule = _rule(method: method);
        final card = _card(rules: [rule]);
        expect(rule.supported, isFalse);
        expect(card.card.validateForPublish, throwsStateError);
        // Even a deserialized published card must not silently use a base rate.
        final restored = PublishedRateCard.fromJson(
          jsonDecode(jsonEncode(card.toJson())) as Map<String, dynamic>,
        );
        expect(
          () => PricingEngine().calculate(
            restored,
            _input(dimensions: Dimensions({})),
            at: _at,
          ),
          throwsUnsupportedError,
        );
      });
    }
  });

  group('billing policies', () {
    test('minimum area changes billing without changing entered area', () {
      final dimensions = _dimensions(height: '12', width: '12');
      final result = _price(
        rule: _rule(billing: BillingPolicy(minimumMeasure: _e('4'))),
        input: _input(dimensions: dimensions, quantity: 3),
      );
      expect(result.measuredQuantity, Exact.one);
      expect(result.billableQuantity, _e('4'));
      expect(result.billableDimensions, same(dimensions));
      expect(result.unitBasePrice, _e('600'));
      expect(result.policies, contains(contains('Minimum billable measure')));
      _expectMoney(result, subtotal: 180000, net: 180000, total: 180000);
    });

    test('each dimension rounds upward in metres, retaining entered units', () {
      final dimensions = _dimensions(
        height: '1010',
        width: '510',
        unit: LengthUnit.millimetres,
      );
      final result = _price(
        rule: _rule(
          method: PricingMethod.squareMetre,
          rate: '100',
          billing: BillingPolicy(dimensionIncrementMetres: _e('0.1')),
        ),
        input: _input(dimensions: dimensions, quantity: 2),
      );
      expect(result.input.dimensions, same(dimensions));
      expect(dimensions.require(Axis.height), _e('1.01'));
      expect(dimensions.require(Axis.width), _e('0.51'));
      expect(result.measuredQuantity, _e('0.5151'));
      expect(result.billableDimensions.require(Axis.height), _e('1.1'));
      expect(result.billableDimensions.require(Axis.width), _e('0.6'));
      expect(result.billableDimensions.enteredUnit, LengthUnit.millimetres);
      expect(result.billableQuantity, _e('0.66'));
      _expectMoney(result, subtotal: 13200, net: 13200, total: 13200);
    });

    test('minimum measure is applied before the measure increment', () {
      final result = _price(
        rule: _rule(
          method: PricingMethod.squareMetre,
          rate: '100',
          billing: BillingPolicy(
            minimumMeasure: _e('1.1'),
            measureIncrement: _e('0.25'),
          ),
        ),
        input: _input(
          dimensions: _dimensions(
            height: '1',
            width: '0.5',
            unit: LengthUnit.metres,
          ),
          quantity: 2,
        ),
      );
      expect(result.measuredQuantity, _e('0.5'));
      expect(result.billableQuantity, _e('1.25'));
      expect(result.policies, hasLength(2));
      _expectMoney(result, subtotal: 25000, net: 25000, total: 25000);
    });

    for (final c in [
      (height: '1.25', billed: '1.25', total: 12500),
      (height: '1.26', billed: '1.5', total: 15000),
    ]) {
      test('measure increment boundary at ${c.height}', () {
        final result = _price(
          rule: _rule(
            method: PricingMethod.metre,
            rate: '100',
            billing: BillingPolicy(measureIncrement: _e('0.25')),
          ),
          input: _input(dimensions: Dimensions({Axis.height: _e(c.height)})),
        );
        expect(result.billableQuantity, _e(c.billed));
        expect(result.totalMinor, BigInt.from(c.total));
      });
    }

    test(
      'stock uses the smallest fitting measure, independent of list order',
      () {
        final stock = [
          _dimensions(height: '3', width: '1', unit: LengthUnit.metres),
          _dimensions(height: '1', width: '1', unit: LengthUnit.metres),
          _dimensions(height: '1.5', width: '1.5', unit: LengthUnit.metres),
          _dimensions(height: '2', width: '1', unit: LengthUnit.metres),
          _dimensions(height: '2', width: '0.7', unit: LengthUnit.metres),
        ];
        final input = _input(
          dimensions: _dimensions(
            height: '120',
            width: '80',
            unit: LengthUnit.centimetres,
          ),
          quantity: 2,
        );
        for (final sizes in [stock, stock.reversed.toList()]) {
          final result = _price(
            rule: _rule(
              method: PricingMethod.squareMetre,
              rate: '100',
              billing: BillingPolicy(stockedSizes: sizes),
            ),
            input: input,
          );
          expect(result.measuredQuantity, _e('0.96'));
          expect(result.billableQuantity, _e('2'));
          expect(result.billableDimensions.metres, {
            Axis.height: _e('2'),
            Axis.width: Exact.one,
          });
          expect(result.billableDimensions.enteredUnit, LengthUnit.centimetres);
          expect(input.dimensions.require(Axis.height), _e('1.2'));
          _expectMoney(result, subtotal: 40000, net: 40000, total: 40000);
        }
      },
    );

    test('dimension increments are applied before choosing stock', () {
      final result = _price(
        rule: _rule(
          method: PricingMethod.squareMetre,
          rate: '100',
          billing: BillingPolicy(
            dimensionIncrementMetres: _e('0.1'),
            stockedSizes: [
              _dimensions(
                height: '1.05',
                width: '0.55',
                unit: LengthUnit.metres,
              ),
              _dimensions(height: '1.2', width: '0.6', unit: LengthUnit.metres),
            ],
          ),
        ),
        input: _input(
          dimensions: _dimensions(
            height: '1.01',
            width: '0.51',
            unit: LengthUnit.metres,
          ),
          quantity: 2,
        ),
      );
      expect(result.measuredQuantity, _e('0.5151'));
      expect(result.billableQuantity, _e('0.72'));
      expect(result.policies, hasLength(2));
      expect(result.totalMinor, BigInt.from(14400));
    });

    test('equal-area stock has a deterministic dimension tie-break', () {
      final stock = [
        _dimensions(height: '3', width: '2', unit: LengthUnit.metres),
        _dimensions(height: '2', width: '3', unit: LengthUnit.metres),
      ];
      for (final sizes in [stock, stock.reversed.toList()]) {
        final result = _price(
          rule: _rule(
            method: PricingMethod.squareMetre,
            billing: BillingPolicy(stockedSizes: sizes),
          ),
          input: _input(
            dimensions: _dimensions(
              height: '1',
              width: '1',
              unit: LengthUnit.metres,
            ),
          ),
        );
        expect(result.billableQuantity, _e('6'));
        expect(result.billableDimensions.metres, {
          Axis.height: _e('2'),
          Axis.width: _e('3'),
        });
      }
    });

    test('unavailable stock fails instead of silently using entered size', () {
      expect(
        () => _price(
          rule: _rule(
            billing: BillingPolicy(
              stockedSizes: [_dimensions(height: '83', width: '36')],
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    for (final c in [
      (rate: '12', unit: '20', total: 6000),
      (rate: '20', unit: '20', total: 6000),
      (rate: '25', unit: '25', total: 7500),
    ]) {
      test('minimum charge is per item at rate ${c.rate}', () {
        final result = _price(
          rule: _rule(
            method: PricingMethod.piece,
            rate: c.rate,
            billing: BillingPolicy(minimumPrice: _e('20')),
          ),
          input: _input(quantity: 3),
        );
        expect(result.unitBasePrice, _e(c.unit));
        expect(result.policies, c.rate == '12' ? isNotEmpty : isEmpty);
        _expectMoney(result, subtotal: c.total, net: c.total, total: c.total);
      });
    }

    test('minimum order quantity is inclusive', () {
      final rule = _rule(billing: BillingPolicy(minimumQuantity: 3));
      expect(
        () => _price(rule: rule, input: _input(quantity: 2)),
        throwsArgumentError,
      );
      expect(
        _price(rule: rule, input: _input(quantity: 3)).totalMinor,
        BigInt.from(945000),
      );
    });

    for (final axis in Axis.values) {
      for (final c in [
        (value: '0.99', valid: false),
        (value: '1', valid: true),
        (value: '2', valid: true),
        (value: '2.01', valid: false),
      ]) {
        test('${axis.name} range boundary ${c.value}', () {
          final rule = _rule(
            method: PricingMethod.piece,
            billing: BillingPolicy(
              ranges: {axis: DimensionRange(_e('1'), _e('2'))},
            ),
          );
          PriceBreakdown calculate() => _price(
            rule: rule,
            input: _input(dimensions: Dimensions({axis: _e(c.value)})),
          );
          if (c.valid) {
            expect(calculate().totalMinor, BigInt.from(15000));
          } else {
            expect(calculate, throwsArgumentError);
          }
        });
      }
    }

    test('required range axes cannot be omitted even for piece pricing', () {
      expect(
        () => _price(
          rule: _rule(
            method: PricingMethod.piece,
            billing: BillingPolicy(
              ranges: {Axis.depth: DimensionRange(_e('1'), _e('2'))},
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('dimensions are checked against ranges before rounding', () {
      expect(
        () => _price(
          rule: _rule(
            method: PricingMethod.metre,
            billing: BillingPolicy(
              dimensionIncrementMetres: _e('1'),
              ranges: {Axis.height: DimensionRange(_e('1'), _e('2'))},
            ),
          ),
          input: _input(dimensions: Dimensions({Axis.height: _e('0.9')})),
        ),
        throwsArgumentError,
      );
    });

    test('rounded dimensions cannot exceed configured ranges', () {
      expect(
        () => _price(
          rule: _rule(
            method: PricingMethod.metre,
            billing: BillingPolicy(
              dimensionIncrementMetres: _e('0.1'),
              ranges: {Axis.height: DimensionRange(_e('1'), _e('1.99'))},
            ),
          ),
          input: _input(dimensions: Dimensions({Axis.height: _e('1.95')})),
        ),
        throwsArgumentError,
      );
    });

    test('stocked dimensions cannot exceed configured ranges', () {
      expect(
        () => _price(
          rule: _rule(
            method: PricingMethod.metre,
            billing: BillingPolicy(
              stockedSizes: [
                Dimensions({Axis.height: _e('2.1')}),
              ],
              ranges: {Axis.height: DimensionRange(_e('1'), _e('2'))},
            ),
          ),
          input: _input(dimensions: Dimensions({Axis.height: _e('1.5')})),
        ),
        throwsArgumentError,
      );
    });
  });
}
