import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/serialization.dart';
import 'package:hyner/features/pricing/domain/universal/universal_pricing.dart';

import 'support/universal_fixture.dart';

void main() {
  group('dimension-safe units', () {
    test(
      'standard physical units cannot be redefined by imported configuration',
      () {
        final bad = UnitDefinition(
          id: 'ft',
          label: 'Incorrect foot',
          dimension: MeasureDimension.length,
          canonicalFactor: Exact.one,
        );
        expect(() => UnitRegistry([bad]), throwsArgumentError);
        expect(
          () => UnitRegistry.fromJson([bad.toJson()]),
          throwsArgumentError,
        );
      },
    );
    for (final sample in [
      ('ft', 'm', '0.3048'),
      ('in', 'mm', '25.4'),
      ('yd', 'ft', '3'),
      ('ft2', 'm2', '0.09290304'),
      ('ft3', 'm3', '0.028316846592'),
      ('litre', 'ml', '1000'),
      ('kg', 'g', '1000'),
      ('tonne', 'kg', '1000'),
      ('lb', 'kg', '0.45359237'),
      ('item', 'piece', '1'),
    ]) {
      test('${sample.$1} converts exactly to ${sample.$2}', () {
        expect(registry.convert(Exact.one, sample.$1, sample.$2), e(sample.$3));
        expect(registry.convert(e(sample.$3), sample.$2, sample.$1), Exact.one);
      });
    }
    test('physical powers compose and cancel', () {
      expect(
        MeasureDimension.length * MeasureDimension.length,
        MeasureDimension.area,
      );
      expect(
        MeasureDimension.volume / MeasureDimension.area,
        MeasureDimension.length,
      );
      expect(
        MeasureDimension.mass / MeasureDimension.mass,
        MeasureDimension.scalar,
      );
      expect(
        MeasureDimension({'mass': 0, 'length': 1}),
        MeasureDimension.length,
      );
    });
    test(
      'unrelated dimensions and commercial packs never implicitly convert',
      () {
        for (final pair in [
          ('m', 'kg'),
          ('m2', 'm'),
          ('pair', 'piece'),
          ('set', 'piece'),
          ('box', 'piece'),
          ('box', 'carton'),
        ]) {
          expect(
            () => registry.convert(Exact.one, pair.$1, pair.$2),
            throwsArgumentError,
          );
        }
      },
    );
    test('merchant length units compose with standard area formulas', () {
      final custom = UnitRegistry.standard(
        additional: [
          UnitDefinition(
            id: 'merchant_length',
            label: 'Stock length',
            dimension: MeasureDimension.length,
            canonicalFactor: e('2.5'),
          ),
        ],
      );
      expect(custom.convert(e('2'), 'merchant_length', 'cm'), e('500'));
      expect(
        () => UnitRegistry.standard(additional: [registry.require('m')]),
        throwsArgumentError,
      );
      expect(
        () => UnitDefinition(
          id: 'bad',
          label: 'Bad',
          dimension: MeasureDimension.length,
          canonicalFactor: Exact.zero,
        ),
        throwsArgumentError,
      );
    });
    test(
      'product pack graph resolves purchase, stock, selling and display roles',
      () {
        final system = ProductUnitSystem(
          productId: 'tiles',
          registry: registry,
          conversions: [
            ProductUnitConversion(
              productId: 'tiles',
              from: 'box',
              to: 'piece',
              factor: e('4'),
            ),
            ProductUnitConversion(
              productId: 'tiles',
              from: 'carton',
              to: 'box',
              factor: e('6'),
            ),
            ProductUnitConversion(
              productId: 'tiles',
              from: 'piece',
              to: 'm2',
              factor: e('0.36'),
            ),
          ],
          roles: {
            CommercialUnitRole.purchase: 'carton',
            CommercialUnitRole.selling: 'box',
            CommercialUnitRole.inventory: 'piece',
            CommercialUnitRole.display: 'm2',
          },
        );
        expect(system.convert(e('2'), 'carton', 'piece'), e('48'));
        expect(system.convert(e('1'), 'box', 'm2'), e('1.44'));
        expect(system.convert(e('1.44'), 'm2', 'box'), Exact.one);
        final loaded = ProductUnitSystem.fromJson(
          jsonObject(canonicalJson(system.toJson())),
        );
        expect(loaded.convert(e('2'), 'carton', 'm2'), e('17.28'));
        expect(
          () => ProductUnitSystem(
            productId: 'other',
            registry: registry,
            conversions: system.conversions,
          ),
          throwsArgumentError,
        );
        expect(
          () => ProductUnitSystem(
            productId: 'other',
            registry: registry,
          ).convert(Exact.one, 'box', 'piece'),
          throwsArgumentError,
        );
      },
    );
    test('inconsistent paths and impossible conversion definitions fail at configuration', () {
      ProductUnitConversion conversion(String from, String to, String factor) =>
          ProductUnitConversion(
            productId: 'product',
            from: from,
            to: to,
            factor: e(factor),
          );
      for (final conversions in [
        [conversion('box', 'piece', '4'), conversion('box', 'piece', '5')],
        [
          conversion('box', 'piece', '4'),
          conversion('carton', 'box', '6'),
          conversion('carton', 'piece', '25'),
        ],
        [conversion('ft', 'm', '1')],
        [conversion('m', 'kg', '2')],
        [conversion('missing', 'box', '1')],
      ]) {
        expect(
          () => ProductUnitSystem(
            productId: 'product',
            registry: registry,
            conversions: conversions,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => ProductUnitConversion(
          productId: 'product',
          from: 'box',
          to: 'piece',
          factor: Exact.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProductUnitSystem(
          productId: 'product',
          registry: registry,
          roles: {
            CommercialUnitRole.selling: 'box',
            CommercialUnitRole.inventory: 'piece',
          },
        ),
        throwsArgumentError,
      );
    });
  });
  group('typed dynamic schema', () {
    final system = ProductUnitSystem(productId: 'product', registry: registry);
    test('switching retains an exact permitted entered unit when display defaults differ', () {
      final old = InputSchema([number('height', 'ft', precision: 3)], system);
      final next = InputSchema([
        number('height', 'm', permitted: ['m', 'ft'], precision: 3),
      ], system);
      final kept = next.preserveFrom(old, {'height': n('7', 'ft')});
      expect((kept['height'] as NumberInput).unit, 'ft');
      expect(next.validate(kept).numbers['height']!.value, e('2.1336'));
    });
    test('a changed pack definition preserves physical coverage rather than stale pack counts', () {
      ProductUnitSystem packs(String coverage) => ProductUnitSystem(
        productId: 'product',
        registry: registry,
        conversions: [
          ProductUnitConversion(
            productId: 'product',
            from: 'box',
            to: 'm2',
            factor: e(coverage),
          ),
        ],
      );
      final fields = [
        number('coverage', 'm2', permitted: ['m2', 'box']),
      ];
      final old = InputSchema(fields, packs('2'));
      final next = InputSchema(fields, packs('3'));
      final kept = next.preserveFrom(old, {'coverage': n('2', 'box')});
      expect((kept['coverage'] as NumberInput).unit, 'm2');
      expect(next.validate(kept).numbers['coverage']!.value, e('4'));
    });
    test('defaults, visibility, normalized values and display ordering', () {
      final fields = [
        number(
          'diameter',
          'mm',
          visibleWhen: VisibilityCondition('material', 'steel'),
        ),
        choice('material', ['steel', 'plastic'], initial: 'plastic'),
        number(
          'length',
          'm',
          permitted: ['m', 'ft'],
          defaultValue: n('2', 'm'),
        ),
      ];
      final schema = InputSchema(fields, system);
      final hidden = schema.validate({'diameter': n('0', 'mm')});
      expect(hidden.visibleFields, ['length', 'material']);
      expect(hidden.numbers.containsKey('diameter'), isFalse);
      expect(hidden.warnings, hasLength(1));
      expect(hidden.numbers['length']!.value, e('2'));
      expect(
        () => schema.validate({'material': const ChoiceInput('steel')}),
        throwsArgumentError,
      );
      final shown = schema.validate({
        'material': const ChoiceInput('steel'),
        'diameter': n('25', 'mm'),
        'length': n('7', 'ft'),
      });
      expect(shown.numbers['diameter']!.value, e('0.025'));
      expect(shown.numbers['length']!.value, e('2.1336'));
      expect(() => shown.numbers.clear(), throwsUnsupportedError);
      expect(
        () => schema.validate({'unknown': n('1', 'm')}),
        throwsArgumentError,
      );
    });
    test('precision, bounds, type and multiple validation respect selected and default units', () {
      final schema = InputSchema([
        number(
          'length',
          'm',
          min: '0.1',
          max: '2',
          precision: 2,
          permitted: ['m', 'cm'],
          multipleOf: e('0.05'),
        ),
      ], system);
      expect(
        schema.validate({'length': n('105', 'cm')}).numbers['length']!.value,
        e('1.05'),
      );
      for (final invalid in [
        n('1.001', 'm'),
        n('1.01', 'm'),
        n('0', 'm'),
        n('-1', 'm'),
        n('201', 'cm'),
        n('1', 'kg'),
        const ChoiceInput('one'),
      ]) {
        expect(() => schema.validate({'length': invalid}), throwsArgumentError);
      }
      expect(
        () => InputSchema([
          number('count', 'piece', type: InputDataType.integer),
        ], system).validate({'count': n('1.5', 'piece')}),
        throwsArgumentError,
      );
    });
    test(
      'only an explicit product pack conversion permits package input for area',
      () {
        final field = number('coverage', 'm2', permitted: ['m2', 'box']);
        expect(() => InputSchema([field], system), throwsArgumentError);
        final tiles = ProductUnitSystem(
          productId: 'product',
          registry: registry,
          conversions: [
            ProductUnitConversion(
              productId: 'product',
              from: 'box',
              to: 'm2',
              factor: e('1.44'),
            ),
          ],
        );
        expect(
          InputSchema(
            [field],
            tiles,
          ).validate({'coverage': n('2', 'box')}).numbers['coverage']!.value,
          e('2.88'),
        );
      },
    );
    test('schema rejects duplicate identifiers, invalid defaults and visibility dependencies', () {
      expect(
        () => InputSchema([number('a', 'm'), number('a', 'm')], system),
        throwsArgumentError,
      );
      expect(
        () =>
            InputSchema([number('a', 'm', defaultValue: n('-1', 'm'))], system),
        throwsArgumentError,
      );
      expect(
        () => InputSchema([
          number('a', 'm', visibleWhen: VisibilityCondition('missing', true)),
        ], system),
        throwsArgumentError,
      );
      expect(() => number('quantity', 'piece'), throwsArgumentError);
      InputDefinition conditional(String id, String dependency) =>
          InputDefinition(
            id: id,
            label: id,
            type: InputDataType.boolean,
            dimension: MeasureDimension.scalar,
            defaultUnit: null,
            permittedUnits: [],
            visibleWhen: VisibilityCondition(dependency, true),
          );
      expect(
        () =>
            InputSchema([conditional('a', 'b'), conditional('b', 'a')], system),
        throwsArgumentError,
      );
    });
    test('switching products preserves physical values and rejects incompatible fields', () {
      final old = InputSchema([
        number('height', 'ft'),
        number('weight', 'kg'),
      ], system);
      final next = InputSchema([
        number('height', 'm'),
        number('weight', 'm'),
      ], ProductUnitSystem(productId: 'other', registry: registry));
      final kept = next.preserveFrom(old, {
        'height': n('7', 'ft'),
        'weight': n('5', 'kg'),
      });
      expect((kept['height'] as NumberInput).value, e('2.1336'));
      expect(kept.containsKey('weight'), isFalse);
      final packs = InputSchema([number('packs', 'box')], system);
      final other = InputSchema([
        number('packs', 'box'),
      ], ProductUnitSystem(productId: 'other', registry: registry));
      expect(other.preserveFrom(packs, {'packs': n('2', 'box')}), isEmpty);
    });
    test('schema and typed input JSON round-trip retains validations', () {
      final schema = InputSchema([
        choice('finish', ['plain', 'polished']),
        number('area', 'ft2'),
        toggle('installation'),
      ], system);
      final loaded = InputSchema.fromJson(
        (jsonObject(canonicalJson({'fields': schema.toJson()})))['fields']
            as List,
        system,
      );
      final request = UniversalPricingRequest(
        inputs: {'finish': const ChoiceInput('plain'), 'area': n('21', 'ft2')},
        quantity: 2,
      );
      final restored = UniversalPricingRequest.fromJson(
        jsonObject(canonicalJson(request.toJson())),
      );
      expect(
        loaded.validate(restored.inputs).numbers['area']!.value,
        e('1.95096384'),
      );
      expect(restored.quantity, 2);
      expect(
        () => InputValue.fromJson({'type': 'executable', 'value': 'evil()'}),
        throwsFormatException,
      );
    });
  });
}
