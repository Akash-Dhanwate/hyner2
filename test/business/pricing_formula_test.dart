import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/inventory/domain/pricing_formula.dart';
import 'package:hyner/features/inventory/domain/product.dart';

void main() {
  test('selling measurements retain units and replace previous sizes', () {
    final result = pricingMeasurementParameters(
      defaultComponentPricingFormula,
      {'length': '84.25', 'width': '36', 'rate': '150.05'},
      const [
        ProductParameter(name: 'Length', value: '80 in'),
        ProductParameter(name: 'Material', value: 'WPC'),
      ],
    );
    expect(result.map((p) => p.toMap()), [
      {'name': 'Length', 'value': '84.25 in'},
      {'name': 'Material', 'value': 'WPC'},
      {'name': 'Width', 'value': '36 in'},
    ]);
  });
  test(
    'any product may carry measurements without exposing pricing internals',
    () {
      const formula = PricingFormula(
        expression: 'weight * rate',
        inputs: [
          PricingInput(name: 'weight', label: 'Weight', unit: 'kg'),
          PricingInput(name: 'diameter', label: 'Diameter', unit: 'mm'),
          PricingInput(name: 'rate'),
          PricingInput(name: 'cost'),
          PricingInput(name: 'margin'),
          PricingInput(name: 'supplierPrice'),
          PricingInput(name: 'qty', label: 'Quantity'),
        ],
      );
      final result = pricingMeasurementParameters(formula, {
        for (final input in formula.inputs) input.name: '2.25',
      }, const []);
      expect(result.map((p) => p.toMap()), [
        {'name': 'Weight', 'value': '2.25 kg'},
        {'name': 'Diameter', 'value': '2.25 mm'},
      ]);
    },
  );
  test('decimal ties round half-up without binary floating point', () {
    const formula = PricingFormula(
      expression: 'price',
      inputs: [PricingInput(name: 'price')],
    );
    expect(
      PricingFormulaCalculator.calculateMinor(formula, {'price': '1.005'}),
      101,
    );
    expect(
      PricingFormulaCalculator.calculateMinor(formula, {'price': '2.675'}),
      268,
    );
    expect(
      PricingFormulaCalculator.calculateMinor(formula, {'price': '.25'}),
      25,
    );
  });

  test('default measured price is per item before applying bill quantity', () {
    expect(
      PricingFormulaCalculator.calculateMinor(defaultComponentPricingFormula, {
        'length': '84',
        'width': '36',
        'rate': '150',
      }),
      315000,
    );
    expect(
      defaultComponentPricingFormula.inputs.any(
        (input) => input.name == 'quantity',
      ),
      isFalse,
    );
  });

  test('invalid formula syntax and undeclared variables cannot be saved', () {
    for (final expression in [
      'price *',
      'price + hidden',
      'price; exit()',
      '(price',
    ]) {
      expect(
        () => PricingFormula(
          expression: expression,
          inputs: const [PricingInput(name: 'price')],
        ).validate(),
        throwsA(isA<Exception>()),
      );
    }
  });
  test('calculates a door price from inches and a rupee rate', () {
    const formula = PricingFormula(
      expression: '(length * width / 144) * rate',
      inputs: [
        PricingInput(name: 'length', label: 'Length', unit: 'in'),
        PricingInput(name: 'width', label: 'Width', unit: 'in'),
        PricingInput(name: 'rate', label: 'Rate', unit: '/sq ft'),
      ],
    );
    expect(
      PricingFormulaCalculator.calculateMinor(formula, {
        'length': 84,
        'width': 36,
        'rate': 250,
      }),
      525000,
    );
  });

  test('supports a saved default formula with parentheses', () {
    const formula = PricingFormula(
      expression: 'quantity * (length * width / 144) * rate',
      inputs: [
        PricingInput(name: 'quantity', label: 'Quantity'),
        PricingInput(name: 'length', label: 'Length', unit: 'in'),
        PricingInput(name: 'width', label: 'Width', unit: 'in'),
        PricingInput(name: 'rate', label: 'Rate', unit: '/sq ft'),
      ],
    );
    expect(
      PricingFormulaCalculator.calculateMinor(formula, {
        'quantity': 2,
        'length': 80,
        'width': 36,
        'rate': 180,
      }),
      720000,
    );
  });

  test('rejects division by zero and unknown variables', () {
    const formula = PricingFormula(
      expression: 'length / width * rate',
      inputs: [
        PricingInput(name: 'length'),
        PricingInput(name: 'width'),
        PricingInput(name: 'rate'),
      ],
    );
    expect(
      () => PricingFormulaCalculator.calculateMinor(formula, {
        'length': 10,
        'width': 0,
        'rate': 2,
      }),
      throwsA(isA<Exception>()),
    );
  });
}
