import '../exact.dart';
import '../pricing_models.dart' show validateId;
import 'units.dart';

enum ArithmeticOperation {
  add,
  subtract,
  multiply,
  divide,
  minimum,
  maximum,
  ceilTo,
}

/// A closed expression tree, never executable source. Literals are canonical
/// measured quantities; only numeric symbols can enter arithmetic.
sealed class Expression {
  const Expression();
  factory Expression.fromJson(Map<String, dynamic> json) {
    var nodes = 0;
    Expression parse(Map<String, dynamic> j, int depth) {
      if (++nodes > 256 || depth > 32) {
        throw const FormatException('Formula exceeds complexity limit');
      }
      switch (j['kind']) {
        case 'literal':
          return Literal(
            Exact.parse(j['value'] as String),
            MeasureDimension.fromJson(j['dimension'] as Map<String, dynamic>),
          );
        case 'reference':
          return Reference(j['name'] as String);
        case 'binary':
          return Arithmetic(
            ArithmeticOperation.values.byName(j['operation'] as String),
            parse(j['left'] as Map<String, dynamic>, depth + 1),
            parse(j['right'] as Map<String, dynamic>, depth + 1),
          );
        default:
          throw const FormatException('Unsupported formula node');
      }
    }

    return parse(json, 0);
  }
  Map<String, Object?> toJson();
}

final class Literal extends Expression {
  const Literal(this.value, this.dimension);
  final Exact value;
  final MeasureDimension dimension;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'literal',
    'value': '$value',
    'dimension': dimension.toJson(),
  };
}

final class Reference extends Expression {
  const Reference(this.name);
  final String name;
  @override
  Map<String, Object?> toJson() => {'kind': 'reference', 'name': name};
}

final class Arithmetic extends Expression {
  const Arithmetic(this.operation, this.left, this.right);
  final ArithmeticOperation operation;
  final Expression left;
  final Expression right;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'binary',
    'operation': operation.name,
    'left': left.toJson(),
    'right': right.toJson(),
  };
}

final class FormulaProgram {
  FormulaProgram({
    required this.output,
    Map<String, Expression> definitions = const {},
    this.version = 1,
  }) : definitions = Map.unmodifiable(definitions) {
    if (version != 1 || definitions.length > 64) {
      throw ArgumentError('Unsupported formula version or size');
    }
    for (final key in definitions.keys) {
      validateId(key);
    }
    // Bound programmatically created trees as well as deserialized ones.
    var count = 0;
    void inspect(Expression e, int depth) {
      if (++count > 1024 || depth > 32) {
        throw ArgumentError('Formula exceeds complexity limit');
      }
      if (e is Reference &&
          !RegExp(r'^(?:rate:)?[a-zA-Z0-9_-]{1,100}$').hasMatch(e.name)) {
        throw ArgumentError('Invalid formula reference');
      }
      if (e is Literal &&
          (e.value.numerator.bitLength > 4096 ||
              e.value.denominator.bitLength > 4096)) {
        throw ArgumentError('Formula literal is too large');
      }
      if (e is Arithmetic) {
        inspect(e.left, depth + 1);
        inspect(e.right, depth + 1);
      }
    }

    for (final e in [...definitions.values, output]) {
      inspect(e, 0);
    }
  }
  final int version;
  final Expression output;
  final Map<String, Expression> definitions;
  Set<String> get externalReferences {
    final names = <String>{};
    void visit(Expression e) {
      if (e is Reference) names.add(e.name);
      if (e is Arithmetic) {
        visit(e.left);
        visit(e.right);
      }
    }

    for (final e in [...definitions.values, output]) {
      visit(e);
    }
    return names.difference(definitions.keys.toSet());
  }

  MeasureDimension validate(Map<String, MeasureDimension> symbols) {
    if (definitions.keys.any(symbols.containsKey)) {
      throw ArgumentError('Formula shadows an input or rate');
    }
    final resolved = Map<String, MeasureDimension>.from(symbols);
    final visiting = <String>{};
    late MeasureDimension Function(Expression) infer;
    MeasureDimension reference(String name) {
      if (resolved.containsKey(name)) return resolved[name]!;
      final definition = definitions[name];
      if (definition == null) {
        throw ArgumentError('Unknown or nonnumeric formula variable: $name');
      }
      if (!visiting.add(name)) {
        throw ArgumentError('Cyclic formula dependency: $name');
      }
      final type = infer(definition);
      visiting.remove(name);
      resolved[name] = type;
      return type;
    }

    infer = (e) {
      if (e is Literal) return e.dimension;
      if (e is Reference) return reference(e.name);
      final binary = e as Arithmetic;
      final a = infer(binary.left);
      final b = infer(binary.right);
      if (binary.right is Literal) {
        final literal = binary.right as Literal;
        if ((binary.operation == ArithmeticOperation.divide &&
                literal.value == Exact.zero) ||
            (binary.operation == ArithmeticOperation.ceilTo &&
                literal.value <= Exact.zero)) {
          throw ArgumentError('Invalid constant divisor or rounding increment');
        }
      }
      if (binary.operation == ArithmeticOperation.multiply) return a * b;
      if (binary.operation == ArithmeticOperation.divide) return a / b;
      if (a != b) {
        throw ArgumentError(
          'Formula combines incompatible dimensions: $a and $b',
        );
      }
      return a;
    };
    for (final name in definitions.keys) {
      reference(name);
    }
    return infer(output);
  }

  MeasuredValue evaluate(Map<String, MeasuredValue> symbols) {
    validate(symbols.map((k, v) => MapEntry(k, v.dimension)));
    final memo = Map<String, MeasuredValue>.from(symbols);
    late MeasuredValue Function(Expression) evaluateNode;
    evaluateNode = (e) {
      if (e is Literal) return MeasuredValue(e.value, e.dimension);
      if (e is Reference) {
        final cached = memo[e.name];
        if (cached != null) return cached;
        final definition = definitions[e.name];
        if (definition == null) {
          throw ArgumentError('Missing formula input: ${e.name}');
        }
        return memo[e.name] = evaluateNode(definition);
      }
      final binary = e as Arithmetic;
      final a = evaluateNode(binary.left);
      final b = evaluateNode(binary.right);
      final dimension = switch (binary.operation) {
        ArithmeticOperation.multiply => a.dimension * b.dimension,
        ArithmeticOperation.divide => a.dimension / b.dimension,
        _ => a.dimension,
      };
      if (binary.operation == ArithmeticOperation.divide &&
          b.value == Exact.zero) {
        throw ArgumentError('Formula cannot divide by zero');
      }
      final result = switch (binary.operation) {
        ArithmeticOperation.add => a.value + b.value,
        ArithmeticOperation.subtract => a.value - b.value,
        ArithmeticOperation.multiply => a.value * b.value,
        ArithmeticOperation.divide => a.value / b.value,
        ArithmeticOperation.minimum => a.value <= b.value ? a.value : b.value,
        ArithmeticOperation.maximum => a.value.max(b.value),
        ArithmeticOperation.ceilTo => a.value.ceilTo(b.value),
      };
      if (result.numerator.bitLength > 4096 ||
          result.denominator.bitLength > 4096) {
        throw ArgumentError('Formula result exceeds supported numeric limits');
      }
      return MeasuredValue(result, dimension);
    };
    return evaluateNode(output);
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'definitions': definitions.map((k, v) => MapEntry(k, v.toJson())),
    'output': output.toJson(),
  };
  factory FormulaProgram.fromJson(Map<String, dynamic> j) => FormulaProgram(
    version: j['version'] as int,
    definitions: (j['definitions'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, Expression.fromJson(v as Map<String, dynamic>)),
    ),
    output: Expression.fromJson(j['output'] as Map<String, dynamic>),
  );
}
