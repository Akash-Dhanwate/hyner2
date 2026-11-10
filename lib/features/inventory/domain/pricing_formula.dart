import 'product.dart';
import '../../pricing/domain/exact.dart';

class PricingInput {
  const PricingInput({required this.name, String? label, this.unit = ''})
    : label = label ?? name;

  final String name;
  final String label;
  final String unit;

  Map<String, String> toMap() => {'name': name, 'label': label, 'unit': unit};

  factory PricingInput.fromMap(Map<dynamic, dynamic> map) => PricingInput(
    name: map['name'] as String,
    label: map['label'] as String? ?? map['name'] as String,
    unit: map['unit'] as String? ?? '',
  );
}

class PricingFormula {
  const PricingFormula({required this.expression, required this.inputs});

  final String expression;
  final List<PricingInput> inputs;

  bool get enabled => expression.trim().isNotEmpty && inputs.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'expression': expression,
    'inputs': [for (final input in inputs) input.toMap()],
  };

  factory PricingFormula.fromMap(Map<dynamic, dynamic> map) => PricingFormula(
    expression: map['expression'] as String,
    inputs: [
      for (final input in (map['inputs'] as List? ?? const []))
        PricingInput.fromMap(input as Map<dynamic, dynamic>),
    ],
  );

  void validate() {
    if (expression.length > 240 || inputs.length > 8) {
      throw inventoryInvalid(
        'Pricing formulas support up to 240 characters and 8 inputs.',
      );
    }
    final names = <String>{};
    for (final input in inputs) {
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,30}$').hasMatch(input.name) ||
          input.label.trim().isEmpty ||
          input.label.length > 60 ||
          input.unit.length > 20 ||
          !names.add(input.name)) {
        throw inventoryInvalid(
          'Each pricing input needs a unique name, label and optional unit.',
        );
      }
    }
    final parser = _PricingParser(
      PricingFormulaCalculator._tokenize(expression),
      {for (final input in inputs) input.name: Exact.one},
      validateOnly: true,
    );
    parser.parseExpression();
    if (parser.hasRemaining) throw inventoryInvalid('Formula is incomplete.');
  }
}

/// Per-item fallback for older measured products. Bill quantity is applied once.
/// Measurements are entered in inches, which is common for cut-to-size items.
const defaultComponentPricingFormula = PricingFormula(
  expression: '(length * width / 144) * rate',
  inputs: [
    PricingInput(name: 'length', label: 'Length', unit: 'in'),
    PricingInput(name: 'width', label: 'Width', unit: 'in'),
    PricingInput(name: 'rate', label: 'Rate', unit: '/sq ft'),
  ],
);

/// Customer-visible measurements are copied with the selling price, so later
/// catalog changes cannot change the specifications on an issued bill.
List<ProductParameter> pricingMeasurementParameters(
  PricingFormula formula,
  Map<String, String> values,
  List<ProductParameter> existing,
) {
  final parameters = [...existing];
  final privateInput = RegExp(
    r'cost|margin|profit|supplier|purchase|rate|price|quantity|\bqty\b',
    caseSensitive: false,
  );
  for (final input in formula.inputs) {
    if (privateInput.hasMatch('${input.name} ${input.label}')) continue;
    final value = values[input.name]?.trim();
    if (value == null || value.isEmpty) continue;
    final parameter = ProductParameter(
      name: input.label.trim(),
      value: [
        value,
        if (input.unit.trim().isNotEmpty) input.unit.trim(),
      ].join(' '),
    );
    final index = parameters.indexWhere(
      (p) => p.name.trim().toLowerCase() == parameter.name.toLowerCase(),
    );
    if (index < 0) {
      parameters.add(parameter);
    } else {
      parameters[index] = parameter;
    }
  }
  if (parameters.length > 20) {
    throw inventoryInvalid(
      'Keep up to 20 product specifications per bill item.',
    );
  }
  ProductParameter.validateList(parameters);
  return List.unmodifiable(parameters);
}

class PricingFormulaCalculator {
  static int calculateMinor(
    PricingFormula formula,
    Map<String, Object> values,
  ) {
    formula.validate();
    final allowed = formula.inputs.map((input) => input.name).toSet();
    if (!values.keys.toSet().containsAll(allowed)) {
      throw inventoryInvalid(
        'Enter all measurements for this price calculation.',
      );
    }
    final normalized = <String, Exact>{};
    for (final input in formula.inputs) {
      final raw = values[input.name];
      if (raw is! String && raw is! num) {
        throw inventoryInvalid('Enter a valid decimal for ${input.label}.');
      }
      try {
        final value = _decimal(raw.toString().trim());
        if (value < Exact.zero) throw const FormatException('Negative input');
        normalized[input.name] = value;
      } on FormatException {
        throw inventoryInvalid(
          'Enter a nonnegative plain decimal for ${input.label}.',
        );
      }
    }
    final result = _evaluate(formula.expression, normalized);
    if (result < Exact.zero ||
        result > Exact.integer(maxMoneyMinor) / Exact.integer(100)) {
      throw inventoryInvalid('This formula produced an invalid price.');
    }
    // No intermediate rounding; half-up once at the currency boundary.
    return (result * Exact.integer(100))
        .roundInteger(MoneyRounding.halfUp)
        .toInt();
  }

  static List<String> _tokenize(String expression) {
    final tokens = <String>[];
    var index = 0;
    while (index < expression.length) {
      final char = expression[index];
      if (char.trim().isEmpty) {
        index++;
      } else if ('+-*/()'.contains(char)) {
        tokens.add(char);
        index++;
      } else {
        final match = RegExp(r'(?:\d+(?:\.\d*)?|\.\d+)|[A-Za-z][A-Za-z0-9_]*')
            .matchAsPrefix(expression, index);
        if (match == null) {
          throw inventoryInvalid('Formula contains an invalid character.');
        }
        tokens.add(match.group(0)!);
        index = match.end;
      }
    }
    return tokens;
  }

  static Exact _evaluate(String expression, Map<String, Exact> values) {
    final parser = _PricingParser(_tokenize(expression), values);
    final result = parser.parseExpression();
    if (parser.hasRemaining) {
      throw inventoryInvalid('Formula is incomplete.');
    }
    return result;
  }
}

class _PricingParser {
  _PricingParser(this._tokens, this._values, {this.validateOnly = false});

  final List<String> _tokens;
  final Map<String, Exact> _values;
  final bool validateOnly;
  var _index = 0;

  bool get hasRemaining => _index < _tokens.length;

  Exact parseExpression() {
    var value = parseTerm();
    while (_match('+') || _match('-')) {
      final operator = _tokens[_index - 1];
      final right = parseTerm();
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }

  Exact parseTerm() {
    var value = parseFactor();
    while (_match('*') || _match('/')) {
      final operator = _tokens[_index - 1];
      final right = parseFactor();
      if (operator == '/') {
        if (right == Exact.zero && !validateOnly) {
          throw inventoryInvalid('Formula cannot divide by zero.');
        }
        value = validateOnly ? Exact.one : value / right;
      } else {
        value *= right;
      }
    }
    return value;
  }

  Exact parseFactor() {
    if (_match('+')) return parseFactor();
    if (_match('-')) return Exact.zero - parseFactor();
    if (_match('(')) {
      final value = parseExpression();
      if (!_match(')')) {
        throw inventoryInvalid('Formula parentheses do not match.');
      }
      return value;
    }
    if (!hasRemaining) throw inventoryInvalid('Formula is incomplete.');
    final token = _tokens[_index++];
    if (RegExp(r'^(?:\d|\.)').hasMatch(token)) return _decimal(token);
    final value = _values[token];
    if (value == null || value < Exact.zero) {
      throw inventoryInvalid(
        'Formula uses an unknown or invalid input: $token.',
      );
    }
    return value;
  }

  bool _match(String token) {
    if (_index >= _tokens.length || _tokens[_index] != token) return false;
    _index++;
    return true;
  }
}

Exact _decimal(String value) {
  var text = value;
  if (text.startsWith('.')) text = '0$text';
  if (text.endsWith('.')) text = '${text}0';
  return Exact.parse(text);
}
