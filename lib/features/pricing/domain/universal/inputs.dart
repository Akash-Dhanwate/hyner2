import '../exact.dart';
import '../pricing_models.dart' show validateId, validateName;
import 'units.dart';

enum InputDataType { decimal, integer, choice, boolean }

sealed class InputValue {
  const InputValue();
  Map<String, Object?> toJson();
  factory InputValue.fromJson(Map<String, dynamic> j) => switch (j['type']) {
    'number' => NumberInput(
      Exact.parse(j['value'] as String),
      j['unit'] as String,
    ),
    'choice' => ChoiceInput(j['value'] as String),
    'boolean' => BooleanInput(j['value'] as bool),
    _ => throw const FormatException('Unsupported input type'),
  };
}

final class NumberInput extends InputValue {
  const NumberInput(this.value, this.unit);
  final Exact value;
  final String unit;
  @override
  Map<String, Object?> toJson() => {
    'type': 'number',
    'value': '$value',
    'unit': unit,
  };
}

final class ChoiceInput extends InputValue {
  const ChoiceInput(this.value);
  final String value;
  @override
  Map<String, Object?> toJson() => {'type': 'choice', 'value': value};
}

final class BooleanInput extends InputValue {
  const BooleanInput(this.value);
  final bool value;
  @override
  Map<String, Object?> toJson() => {'type': 'boolean', 'value': value};
}

final class VisibilityCondition {
  VisibilityCondition(this.fieldId, this.equals) {
    if (equals is! String && equals is! bool) {
      throw ArgumentError('Visibility requires a choice or boolean value');
    }
  }
  final String fieldId;
  final Object equals;
  bool matches(InputValue? value) => switch (value) {
    ChoiceInput() => value.value == equals,
    BooleanInput() => value.value == equals,
    _ => false,
  };
  Map<String, Object?> toJson() => {'fieldId': fieldId, 'equals': equals};
  factory VisibilityCondition.fromJson(Map<String, dynamic> j) =>
      VisibilityCondition(j['fieldId'] as String, j['equals'] as Object);
}

final class InputDefinition {
  InputDefinition({
    required this.id,
    required this.label,
    required this.type,
    required this.dimension,
    required this.defaultUnit,
    required List<String> permittedUnits,
    this.required = true,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.precision = 3,
    this.visibleWhen,
    this.displayOrder = 0,
    List<String> choices = const [],
    this.multipleOf,
  }) : permittedUnits = List.unmodifiable(permittedUnits),
       choices = List.unmodifiable(choices) {
    validateId(id);
    validateName(label);
    if (id == 'quantity') {
      throw ArgumentError('quantity is reserved for the order control');
    }
    if (precision < 0 ||
        precision > 12 ||
        (minimum != null && maximum != null && minimum! > maximum!) ||
        (multipleOf != null && multipleOf! <= Exact.zero)) {
      throw ArgumentError('Invalid input validation rules');
    }
    if (choices.toSet().length != choices.length ||
        choices.length > 100 ||
        choices.any((c) => c.isEmpty || c.length > 120)) {
      throw ArgumentError('Invalid choices');
    }
    if (isNumeric) {
      if (defaultUnit == null ||
          permittedUnits.isEmpty ||
          permittedUnits.toSet().length != permittedUnits.length ||
          !permittedUnits.contains(defaultUnit) ||
          choices.isNotEmpty) {
        throw ArgumentError('Numeric input requires permitted/default units');
      }
    } else if (dimension != MeasureDimension.scalar ||
        defaultUnit != null ||
        permittedUnits.isNotEmpty ||
        minimum != null ||
        maximum != null ||
        multipleOf != null) {
      throw ArgumentError(
        'Choice and boolean inputs cannot carry numeric rules',
      );
    }
    if (type == InputDataType.choice && choices.isEmpty) {
      throw ArgumentError('Choice input needs options');
    }
    if (type != InputDataType.choice && choices.isNotEmpty) {
      throw ArgumentError('Options require a choice input');
    }
  }
  final String id;
  final String label;
  final InputDataType type;
  final MeasureDimension dimension;
  final String? defaultUnit;
  final List<String> permittedUnits;
  final bool required;
  final InputValue? defaultValue;

  /// Bounds and multipleOf are expressed in the default unit.
  final Exact? minimum;
  final Exact? maximum;
  final int precision;
  final VisibilityCondition? visibleWhen;
  final int displayOrder;
  final List<String> choices;
  final Exact? multipleOf;
  bool get isNumeric =>
      type == InputDataType.decimal || type == InputDataType.integer;
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    'dimension': dimension.toJson(),
    'defaultUnit': defaultUnit,
    'permittedUnits': permittedUnits,
    'required': required,
    'defaultValue': defaultValue?.toJson(),
    'minimum': minimum?.toString(),
    'maximum': maximum?.toString(),
    'precision': precision,
    'visibleWhen': visibleWhen?.toJson(),
    'displayOrder': displayOrder,
    'choices': choices,
    'multipleOf': multipleOf?.toString(),
  };
  factory InputDefinition.fromJson(Map<String, dynamic> j) => InputDefinition(
    id: j['id'] as String,
    label: j['label'] as String,
    type: InputDataType.values.byName(j['type'] as String),
    dimension: MeasureDimension.fromJson(
      j['dimension'] as Map<String, dynamic>,
    ),
    defaultUnit: j['defaultUnit'] as String?,
    permittedUnits: List<String>.from(j['permittedUnits'] as List),
    required: j['required'] as bool,
    defaultValue: j['defaultValue'] == null
        ? null
        : InputValue.fromJson(j['defaultValue'] as Map<String, dynamic>),
    minimum: j['minimum'] == null ? null : Exact.parse(j['minimum'] as String),
    maximum: j['maximum'] == null ? null : Exact.parse(j['maximum'] as String),
    precision: j['precision'] as int,
    visibleWhen: j['visibleWhen'] == null
        ? null
        : VisibilityCondition.fromJson(
            j['visibleWhen'] as Map<String, dynamic>,
          ),
    displayOrder: j['displayOrder'] as int,
    choices: List<String>.from(j['choices'] as List),
    multipleOf: j['multipleOf'] == null
        ? null
        : Exact.parse(j['multipleOf'] as String),
  );
}

final class ValidatedInputs {
  ValidatedInputs(
    Map<String, InputValue> values,
    Map<String, MeasuredValue> numbers,
    List<String> visible,
    List<String> warnings,
  ) : values = Map.unmodifiable(values),
      numbers = Map.unmodifiable(numbers),
      visibleFields = List.unmodifiable(visible),
      warnings = List.unmodifiable(warnings);
  final Map<String, InputValue> values;
  final Map<String, MeasuredValue> numbers;
  final List<String> visibleFields;
  final List<String> warnings;
}

final class InputSchema {
  InputSchema(List<InputDefinition> fields, this.units)
    : fields = List.unmodifiable(fields) {
    if (fields.length > 64 ||
        fields.map((f) => f.id).toSet().length != fields.length) {
      throw ArgumentError('Duplicate or excessive input definitions');
    }
    final map = {for (final f in fields) f.id: f};
    final visiting = <String>{};
    final done = <String>{};
    void visit(InputDefinition field) {
      if (done.contains(field.id)) return;
      if (!visiting.add(field.id)) {
        throw ArgumentError('Cyclic input visibility');
      }
      final condition = field.visibleWhen;
      if (condition != null) {
        final dependency = map[condition.fieldId];
        if (dependency == null ||
            (dependency.type != InputDataType.choice &&
                dependency.type != InputDataType.boolean) ||
            (dependency.type == InputDataType.choice &&
                !dependency.choices.contains(condition.equals)) ||
            (dependency.type == InputDataType.boolean &&
                condition.equals is! bool)) {
          throw ArgumentError('Invalid visibility dependency');
        }
        visit(dependency);
      }
      if (field.isNumeric) {
        if (units.registry.require(field.defaultUnit!).dimension !=
            field.dimension) {
          throw ArgumentError('Input unit/dimension mismatch');
        }
        for (final unit in field.permittedUnits) {
          units.convert(Exact.one, unit, field.defaultUnit!);
        }
      }
      if (field.defaultValue != null) {
        _validateValue(field, field.defaultValue!);
      }
      visiting.remove(field.id);
      done.add(field.id);
      _ordered.add(field);
    }

    for (final f in fields) {
      visit(f);
    }
  }
  final List<InputDefinition> fields;
  final ProductUnitSystem units;
  final List<InputDefinition> _ordered = [];
  Map<String, MeasureDimension> get numericTypes => {
    for (final f in fields.where((f) => f.isNumeric)) f.id: f.dimension,
  };
  ValidatedInputs validate(Map<String, InputValue> input) {
    if (input.keys.any((id) => !fields.any((f) => f.id == id))) {
      throw ArgumentError('Unknown product input');
    }
    final values = <String, InputValue>{};
    final numbers = <String, MeasuredValue>{};
    final visible = <InputDefinition>[];
    final warnings = <String>[];
    for (final f in _ordered) {
      if (f.visibleWhen != null &&
          !f.visibleWhen!.matches(values[f.visibleWhen!.fieldId])) {
        if (input.containsKey(f.id)) {
          warnings.add('Ignored hidden field: ${f.label}');
        }
        continue;
      }
      visible.add(f);
      final value = input[f.id] ?? f.defaultValue;
      if (value == null) {
        if (f.required) throw ArgumentError('Enter ${f.label}');
        continue;
      }
      final number = _validateValue(f, value);
      values[f.id] = value;
      if (number != null) numbers[f.id] = number;
    }
    visible.sort((a, b) {
      final c = a.displayOrder.compareTo(b.displayOrder);
      return c == 0 ? a.id.compareTo(b.id) : c;
    });
    return ValidatedInputs(
      values,
      numbers,
      visible.map((f) => f.id).toList(),
      warnings,
    );
  }

  MeasuredValue? _validateValue(InputDefinition field, InputValue value) {
    if (field.isNumeric) {
      if (value is! NumberInput || !field.permittedUnits.contains(value.unit)) {
        throw ArgumentError('Choose a permitted unit for ${field.label}');
      }
      final scale = Exact(BigInt.from(10).pow(field.precision));
      if (!(value.value * scale).isInteger ||
          (field.type == InputDataType.integer && !value.value.isInteger)) {
        throw ArgumentError('${field.label} exceeds permitted precision');
      }
      final normalized = units.convert(
        value.value,
        value.unit,
        field.defaultUnit!,
      );
      if ((field.minimum != null && normalized < field.minimum!) ||
          (field.maximum != null && normalized > field.maximum!) ||
          (field.multipleOf != null &&
              !(normalized / field.multipleOf!).isInteger)) {
        throw ArgumentError('${field.label} is outside its permitted values');
      }
      return units.registry.require(field.defaultUnit!).normalize(normalized);
    }
    if (field.type == InputDataType.choice &&
        (value is! ChoiceInput || !field.choices.contains(value.value))) {
      throw ArgumentError('Choose ${field.label}');
    }
    if (field.type == InputDataType.boolean && value is! BooleanInput) {
      throw ArgumentError('${field.label} requires yes or no');
    }
    return null;
  }

  /// Product switching preserves only semantically compatible fields. Product
  /// package quantities are not carried to a different product implicitly.
  Map<String, InputValue> preserveFrom(
    InputSchema previous,
    Map<String, InputValue> values,
  ) {
    final kept = <String, InputValue>{};
    for (final field in fields) {
      final prior = previous.fields.where((f) => f.id == field.id).firstOrNull;
      final value = values[field.id];
      if (prior == null ||
          value == null ||
          prior.type != field.type ||
          prior.dimension != field.dimension) {
        continue;
      }
      try {
        InputValue next = value;
        if (value is NumberInput) {
          final source = previous.units.registry.require(value.unit);
          final target = units.registry.require(field.defaultUnit!);
          if (source.dimension.isCommercialUnit &&
              previous.units.productId != units.productId) {
            continue;
          }
          final canonical = previous._validateValue(prior, value)!;
          if (canonical.dimension != target.dimension) continue;
          next = NumberInput(
            canonical.value / target.canonicalFactor,
            field.defaultUnit!,
          );
          // Preserve the entered unit when it represents the same exact
          // measurement. This avoids unnecessary precision loss (7 ft is
          // exact even when a metre control permits only three decimals).
          if (field.permittedUnits.contains(value.unit)) {
            final inTarget =
                units.convert(value.value, value.unit, field.defaultUnit!) *
                target.canonicalFactor;
            if (inTarget == canonical.value) next = value;
          }
        }
        _validateValue(field, next);
        kept[field.id] = next;
      } on ArgumentError {
        continue;
      }
    }
    return Map.unmodifiable(kept);
  }

  List<Object?> toJson() => fields.map((f) => f.toJson()).toList();
  factory InputSchema.fromJson(List<dynamic> j, ProductUnitSystem units) =>
      InputSchema(
        j
            .map((e) => InputDefinition.fromJson(e as Map<String, dynamic>))
            .toList(),
        units,
      );
}
