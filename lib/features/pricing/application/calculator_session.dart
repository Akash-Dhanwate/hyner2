import 'package:flutter/foundation.dart';

import '../domain/exact.dart';
import '../domain/universal/rate_card.dart';
import '../domain/universal/universal_pricing.dart';
import 'product_setup.dart';

String pricingError(Object error) => switch (error) {
  ArgumentError() => '${error.message}',
  FormatException() => error.message,
  StateError() => error.message,
  _ => 'This action could not be completed. Please try again.',
};

String decimalText(Exact value, {int places = 6, bool approximate = false}) {
  final scale = BigInt.from(10).pow(places);
  final scaled = value * Exact(scale);
  final digits = scaled.roundInteger(MoneyRounding.halfUp);
  final text = digits.abs().toString().padLeft(places + 1, '0');
  var result = places == 0
      ? text
      : '${text.substring(0, text.length - places)}.${text.substring(text.length - places)}';
  if (places > 0) result = result.replaceFirst(RegExp(r'\.?0+$'), '');
  if (digits.isNegative) result = '-$result';
  return '${approximate && !scaled.isInteger ? '≈ ' : ''}$result';
}

String moneyText(BigInt minor, Currency currency) {
  final digits = minor.abs().toString().padLeft(currency.minorDigits + 1, '0');
  final split = digits.length - currency.minorDigits;
  final whole = digits
      .substring(0, split)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final fraction = currency.minorDigits == 0
      ? ''
      : '.${digits.substring(split)}';
  final symbol =
      {'INR': '₹', 'USD': '\$', 'EUR': '€', 'GBP': '£'}[currency.code] ??
      '${currency.code} ';
  return '${minor.isNegative ? '-' : ''}$symbol$whole$fraction';
}

class CalculatorSession extends ChangeNotifier {
  CalculatorSession({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  UniversalProduct? product;
  Map<String, Map<String, dynamic>> entries = {};
  String quantity = '1';
  PricingResult? result;
  String? error;
  int lastCalculationMicros = 0;

  static const lengthUnits = ['in', 'ft', 'mm', 'cm', 'm'];
  bool _useSameUnit = true;
  String? _linkedUnit;
  String? _baseRateOverride;
  bool get useSameUnit => _useSameUnit;
  String? get baseRateOverrideText => _baseRateOverride;
  bool get hasBaseRateOverride => _baseRateOverride != null;

  SellingRate? get _availableBaseRate {
    final rates = product?.rule.rateLookup.rates
        .where((r) => r.key == 'base')
        .toList();
    return rates != null && rates.length == 1 && rates.single.selectors.isEmpty
        ? rates.single
        : null;
  }

  /// Null means this product does not have a single selector-free base rate.
  String? get availableBaseRateText {
    final rate = _availableBaseRate;
    if (rate == null) return null;
    // A rate may itself be rational; never present a rounded value as exact.
    final text = decimalText(rate.amount, places: 12);
    return Exact.parse(text) == rate.amount ? text : '${rate.amount}';
  }

  String? get availableBaseRateUnit => _availableBaseRate?.unit;

  void setBaseRateOverride(String value) {
    if (_availableBaseRate == null) {
      throw StateError('A single base rate without selectors is required');
    }
    // Keep invalid edits visible and remove the price until they are corrected.
    _baseRateOverride = value;
    recalculate();
  }

  void resetBaseRateOverride() {
    _baseRateOverride = null;
    recalculate();
  }

  List<InputDefinition> get lengthFields =>
      product?.rule.schema.fields
          .where((f) => f.isNumeric && f.dimension == MeasureDimension.length)
          .toList() ??
      [];
  List<String> get availableLengthUnits => lengthUnits
      .where(
        (u) =>
            lengthFields.isNotEmpty &&
            lengthFields.every((f) => f.permittedUnits.contains(u)),
      )
      .toList();
  String? get commonLengthUnit {
    if (availableLengthUnits.contains(_linkedUnit)) return _linkedUnit;
    for (final field in visibleFields) {
      if (field.dimension == MeasureDimension.length &&
          availableLengthUnits.contains(entries[field.id]?['unit'])) {
        return entries[field.id]!['unit'] as String;
      }
    }
    return availableLengthUnits.firstOrNull;
  }

  bool usesCommonUnit(InputDefinition field) =>
      useSameUnit &&
      field.dimension == MeasureDimension.length &&
      entries[field.id]?['unit'] == commonLengthUnit;

  void setUseSameUnit(bool value) {
    _useSameUnit = value;
    if (value && commonLengthUnit != null) {
      changeLengthUnit(commonLengthUnit!);
    } else {
      recalculate();
    }
  }

  /// Applies to hidden compatible dimensions too, so revealing one is safe.
  void changeLengthUnit(String unit) {
    if (!availableLengthUnits.contains(unit)) {
      throw ArgumentError('Choose a compatible length unit');
    }
    _linkedUnit = unit;
    for (final field in lengthFields) {
      if (field.permittedUnits.contains(unit)) _convertEntry(field, unit);
    }
    recalculate();
  }

  bool isRounded(String id) => entries[id]?['rounded'] == true;

  Map<String, dynamic> _initial(InputDefinition field) {
    final value = field.defaultValue;
    return {
      'text': value is NumberInput
          ? decimalText(value.value, places: field.precision)
          : '',
      'unit': value is NumberInput ? value.unit : field.defaultUnit,
      'inches': '',
      'choice': value is ChoiceInput ? value.value : null,
      'checked': value is BooleanInput ? value.value : false,
    };
  }

  void select(UniversalProduct next) {
    final old = product;
    final previous = entries;
    final kept = <String, Map<String, dynamic>>{};
    for (final field in next.rule.schema.fields) {
      final prior = old?.rule.schema.fields
          .where((f) => f.id == field.id)
          .firstOrNull;
      var entry = _initial(field);
      if (prior != null &&
          prior.type == field.type &&
          prior.dimension == field.dimension &&
          previous[field.id] != null) {
        final value = Map<String, dynamic>.from(previous[field.id]!);
        if (!field.isNumeric) {
          if (field.type == InputDataType.boolean ||
              field.choices.contains(value['choice'])) {
            entry = value;
          }
        } else if (!field.dimension.isCommercialUnit || next.id == old!.id) {
          final unit = value['unit'] as String;
          entry = value;
          if (!field.permittedUnits.contains(unit) &&
              !(unit == 'ft_in' &&
                  field.permittedUnits.contains('in') &&
                  field.permittedUnits.contains('ft'))) {
            // Convert below, once the new product registry is active.
            try {
              final source = _sourceEntry(value);
              _rawNumber(prior, source);
              entry = {...value, 'source': source};
            } catch (_) {
              entry = _initial(field);
            }
          }
        }
      }
      kept[field.id] = entry;
    }
    if (old?.id != next.id ||
        old?.rule.businessId != next.rule.businessId ||
        old?.rule.version != next.rule.version) {
      _baseRateOverride = null;
    }
    product = next;
    entries = kept;
    if (useSameUnit && availableLengthUnits.isNotEmpty) {
      _linkedUnit = commonLengthUnit;
    }
    for (final field in next.rule.schema.fields.where((f) => f.isNumeric)) {
      final unit = entries[field.id]!['unit'];
      final target =
          useSameUnit &&
              _linkedUnit != null &&
              field.dimension == MeasureDimension.length &&
              field.permittedUnits.contains(_linkedUnit)
          ? _linkedUnit!
          : field.permittedUnits.contains(unit) ||
                (unit == 'ft_in' &&
                    field.permittedUnits.contains('in') &&
                    field.permittedUnits.contains('ft'))
          ? unit as String
          : field.defaultUnit!;
      _convertEntry(field, target);
    }
    recalculate();
  }

  bool visible(InputDefinition field) {
    final condition = field.visibleWhen;
    if (condition == null) return true;
    final dependency = product!.rule.schema.fields.singleWhere(
      (f) => f.id == condition.fieldId,
    );
    if (!visible(dependency)) return false;
    final state = entries[dependency.id]!;
    return dependency.type == InputDataType.boolean
        ? state['checked'] == condition.equals
        : state['choice'] == condition.equals;
  }

  List<InputDefinition> get visibleFields {
    final fields = product?.rule.schema.fields.where(visible).toList() ?? [];
    fields.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return fields;
  }

  Map<String, dynamic> _sourceEntry(Map<String, dynamic> entry) =>
      Map<String, dynamic>.from(
        entry['source'] as Map? ??
            {
              'text': entry['text'],
              'unit': entry['unit'],
              'inches': entry['inches'] ?? '',
            },
      );

  NumberInput _number(InputDefinition field, Map<String, dynamic> entry) =>
      _rawNumber(field, _sourceEntry(entry));

  NumberInput _rawNumber(InputDefinition field, Map<String, dynamic> entry) {
    final text = (entry['text'] as String).trim();
    if (text.isEmpty) throw ArgumentError('Enter ${field.label}');
    if (entry['unit'] == 'ft_in') {
      final feet = Exact.parse(text);
      final inchText = (entry['inches'] as String? ?? '').trim();
      final inches = inchText.isEmpty ? Exact.zero : Exact.parse(inchText);
      if (!feet.isInteger ||
          feet < Exact.zero ||
          inches < Exact.zero ||
          inches >= Exact.integer(12)) {
        throw ArgumentError(
          '${field.label}: enter whole feet and inches below 12',
        );
      }
      return NumberInput(feet * Exact.integer(12) + inches, 'in');
    }
    return NumberInput(Exact.parse(text), entry['unit'] as String);
  }

  Map<String, dynamic> _renderNumber(
    InputDefinition field,
    Map<String, dynamic> source,
    String unit,
  ) {
    final number = _rawNumber(field, source);
    final targetUnit = unit == 'ft_in' ? 'in' : unit;
    final converted = product!.rule.schema.units.registry.convert(
      number.value,
      number.unit,
      targetUnit,
    );
    var display = converted;
    var feet = BigInt.zero;
    if (unit == 'ft_in') {
      if (converted < Exact.zero) {
        throw ArgumentError('Enter a positive length');
      }
      final totalFeet = converted / Exact.integer(12);
      feet = totalFeet.numerator ~/ totalFeet.denominator;
      display = converted - Exact(feet) * Exact.integer(12);
    }
    var text = decimalText(display, places: field.precision);
    if (unit == 'ft_in' && Exact.parse(text) == Exact.integer(12)) {
      feet += BigInt.one;
      text = '0';
    }
    final represented = unit == 'ft_in'
        ? Exact(feet) * Exact.integer(12) + Exact.parse(text)
        : Exact.parse(text);
    return {
      'unit': unit,
      'text': unit == 'ft_in' ? '$feet' : text,
      'inches': unit == 'ft_in' ? text : '',
      'rounded': represented != converted,
    };
  }

  void _convertEntry(InputDefinition field, String unit) {
    final entry = entries[field.id]!;
    if (entry['unit'] == unit && entry['source'] == null) return;
    if ((entry['text'] as String).trim().isEmpty) {
      entry.addAll({'unit': unit, 'inches': ''});
      entry.remove('source');
      entry.remove('rounded');
      return;
    }
    try {
      final source = _sourceEntry(entry);
      final number = _rawNumber(field, source);
      // Invalid precision must not become valid merely by changing units.
      if (!(number.value * Exact(BigInt.from(10).pow(12))).isInteger) {
        throw ArgumentError('Measurement exceeds supported precision');
      }
      if (entry['source'] == null &&
          (!(number.value * Exact(BigInt.from(10).pow(field.precision)))
                  .isInteger ||
              (field.type == InputDataType.integer &&
                  !number.value.isInteger))) {
        throw ArgumentError('${field.label} exceeds permitted precision');
      }
      entry.addAll({..._renderNumber(field, source, unit), 'source': source});
    } catch (_) {
      // Keep an invalid edit in its original unit; never reinterpret its digits.
    }
  }

  void change(String id, String property, dynamic value) {
    final field = product!.rule.schema.fields.singleWhere((f) => f.id == id);
    if (property == 'unit') {
      final unit = value as String;
      if (!field.permittedUnits.contains(unit) &&
          !(unit == 'ft_in' &&
              field.permittedUnits.contains('in') &&
              field.permittedUnits.contains('ft'))) {
        throw ArgumentError('Choose a permitted unit for ${field.label}');
      }
      if (useSameUnit &&
          field.dimension == MeasureDimension.length &&
          lengthUnits.contains(unit)) {
        changeLengthUnit(unit);
        return;
      }
      if (unit == 'ft_in') _useSameUnit = false;
      _convertEntry(field, unit);
    } else {
      entries[id]![property] = value;
      if (property == 'text' || property == 'inches') {
        entries[id]!.remove('source');
        entries[id]!.remove('rounded');
      }
    }
    recalculate();
  }

  void changeQuantity(String value) {
    quantity = value;
    recalculate();
  }

  void stepQuantity(int delta) {
    changeQuantity(
      ((int.tryParse(quantity) ?? 1) + delta).clamp(1, 1000000).toString(),
    );
  }

  UniversalPricingRule _calculationRule() {
    final rule = product!.rule;
    var changed = false;
    final fields = rule.schema.fields.map((field) {
      final entry = entries[field.id]!;
      if (!field.isNumeric || entry['source'] == null) return field;
      final source = _number(field, entry);
      var precision = field.precision;
      while (precision < 12 &&
          !(source.value * Exact(BigInt.from(10).pow(precision))).isInteger) {
        precision++;
      }
      if (field.permittedUnits.contains(source.unit) &&
          precision == field.precision) {
        return field;
      }
      changed = true;
      // Only this calculation accepts the retained, finite source unit. Bounds,
      // dimensions, integer constraints and billing rules still apply unchanged.
      return InputDefinition.fromJson({
        ...field.toJson(),
        'permittedUnits': {...field.permittedUnits, source.unit}.toList(),
        'precision': precision,
      });
    }).toList();
    var rates = rule.rateLookup.rates;
    if (hasBaseRateOverride) {
      final base = _availableBaseRate;
      if (base == null) throw StateError('Base rate override is unavailable');
      final amount = Exact.parse(_baseRateOverride!.trim());
      final replacement = SellingRate(
        id: base.id,
        key: base.key,
        amount: amount,
        unit: base.unit,
      );
      rates = [for (final r in rates) r.id == base.id ? replacement : r];
      changed = true;
    }
    if (!changed) return rule;
    return UniversalPricingRule(
      businessId: rule.businessId,
      productId: rule.productId,
      id: rule.id,
      version: rule.version,
      currency: rule.currency,
      schema: InputSchema(fields, rule.schema.units),
      rates: rates,
      strategy: rule.strategy,
      tax: rule.tax,
      discount: rule.discount,
      rounding: rule.rounding,
      effectiveAt: rule.effectiveAt,
      expiresAt: rule.expiresAt,
      inputBilling: rule.inputBilling,
      extras: rule.extras,
    );
  }

  void recalculate() {
    result = null;
    error = null;
    final watch = Stopwatch()..start();
    try {
      if (product == null) throw StateError('Select a product');
      final count = int.tryParse(quantity);
      if (count == null || count < 1 || count > 1000000) {
        throw ArgumentError('Enter a whole quantity from 1 to 1,000,000');
      }
      final inputs = <String, InputValue>{};
      for (final field in visibleFields) {
        final entry = entries[field.id]!;
        if (field.isNumeric) {
          if ((entry['text'] as String).trim().isEmpty && !field.required) {
            continue;
          }
          inputs[field.id] = _number(field, entry);
        } else if (field.type == InputDataType.boolean) {
          inputs[field.id] = BooleanInput(entry['checked'] == true);
        } else {
          if (entry['choice'] == null) {
            if (field.required) throw ArgumentError('Choose ${field.label}');
          } else {
            inputs[field.id] = ChoiceInput(entry['choice'] as String);
          }
        }
      }
      result = UniversalPricingEngine().calculate(
        _calculationRule(),
        UniversalPricingRequest(inputs: inputs, quantity: count),
        at: _clock(),
      );
      if (hasBaseRateOverride) {
        final calculated = result!;
        result = PricingResult(
          rule: calculated.rule,
          calculatedAt: calculated.calculatedAt,
          request: calculated.request,
          inputs: calculated.inputs,
          billableInputs: calculated.billableInputs,
          base: calculated.base,
          extras: calculated.extras,
          unitBaseAmount: calculated.unitBaseAmount,
          orderBaseAmount: calculated.orderBaseAmount,
          extraAmount: calculated.extraAmount,
          amounts: calculated.amounts,
          warnings: [
            ...calculated.warnings,
            'Base rate overridden for this calculation. Stored rates are unchanged.',
          ],
        );
      }
    } catch (e) {
      error = pricingError(e);
    }
    watch.stop();
    lastCalculationMicros = watch.elapsedMicroseconds;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'productId': product?.id,
    'businessId': product?.rule.businessId,
    'ruleVersion': product?.rule.version,
    'quantity': quantity,
    'useSameUnit': useSameUnit,
    'linkedUnit': _linkedUnit,
    'baseRateOverride': _baseRateOverride,
    'entries': {
      for (final e in entries.entries)
        e.key: {
          ...e.value,
          if (e.value['source'] is Map)
            'source': Map<String, dynamic>.from(e.value['source'] as Map),
        },
    },
  };

  bool _boundedText(dynamic value, int limit, {bool nullable = false}) =>
      (nullable && value == null) || (value is String && value.length <= limit);

  void restore(Map<String, dynamic> state) {
    if (product == null ||
        state['schemaVersion'] != 1 ||
        state['productId'] != product!.id ||
        (state['businessId'] != null &&
            state['businessId'] != product!.rule.businessId)) {
      return;
    }
    final saved = state['entries'];
    if (saved is! Map || saved.length > 64) return;
    for (final field in product!.rule.schema.fields) {
      final value = saved[field.id];
      if (value is! Map ||
          value.length > 8 ||
          !_boundedText(value['text'], 256) ||
          !_boundedText(value['inches'], 256, nullable: true) ||
          !_boundedText(value['unit'], 64, nullable: true) ||
          !_boundedText(value['choice'], 120, nullable: true) ||
          value['checked'] is! bool) {
        continue;
      }
      if (field.isNumeric &&
          !field.permittedUnits.contains(value['unit']) &&
          !(value['unit'] == 'ft_in' &&
              field.permittedUnits.contains('in') &&
              field.permittedUnits.contains('ft'))) {
        continue;
      }
      final entry = <String, dynamic>{
        'text': value['text'],
        'inches': value['inches'] ?? '',
        'unit': value['unit'],
        'choice': value['choice'],
        'checked': value['checked'],
      };
      if (value['source'] != null) {
        final source = value['source'];
        if (!field.isNumeric ||
            source is! Map ||
            source.length != 3 ||
            !_boundedText(source['text'], 256) ||
            !_boundedText(source['inches'], 256) ||
            !_boundedText(source['unit'], 64)) {
          continue;
        }
        try {
          final raw = Map<String, dynamic>.from(source);
          final number = _rawNumber(field, raw);
          if (product!.rule.schema.units.registry
                      .require(number.unit)
                      .dimension !=
                  field.dimension ||
              !(number.value * Exact(BigInt.from(10).pow(12))).isInteger) {
            continue;
          }
          final rendered = _renderNumber(field, raw, entry['unit'] as String);
          if (rendered['text'] != entry['text'] ||
              rendered['inches'] != entry['inches']) {
            continue;
          }
          entry.addAll({...rendered, 'source': raw});
        } catch (_) {
          continue;
        }
      }
      entries[field.id] = entry;
    }
    if (_boundedText(state['quantity'], 12)) {
      quantity = state['quantity'] as String;
    }
    _useSameUnit = state['useSameUnit'] is bool
        ? state['useSameUnit'] as bool
        : true;
    _linkedUnit = availableLengthUnits.contains(state['linkedUnit'])
        ? state['linkedUnit'] as String
        : null;
    final override = state['baseRateOverride'];
    _baseRateOverride =
        _availableBaseRate != null &&
            state['ruleVersion'] == product!.rule.version &&
            _boundedText(override, 256)
        ? override as String
        : null;
    recalculate();
  }

  String publicPriceText() {
    final value = result;
    if (value == null) {
      throw StateError('Complete the calculation before sharing');
    }
    final currency = value.rule.currency;
    final lines = <String>['Price estimate', product!.name];
    for (final field in visibleFields.where(
      (f) =>
          f.isNumeric &&
          !f.dimension.isCommercialUnit &&
          f.dimension != MeasureDimension.scalar,
    )) {
      final entry = entries[field.id]!;
      lines.add(
        entry['unit'] == 'ft_in'
            ? '${field.label}: ${isRounded(field.id) ? '≈ ' : ''}${entry['text']} ft ${(entry['inches'] as String? ?? '').isEmpty ? '0' : entry['inches']} in'
            : '${field.label}: ${isRounded(field.id) ? '≈ ' : ''}${entry['text']} ${unitShort[entry['unit']] ?? entry['unit']}',
      );
    }
    lines.addAll([
      'Quantity: ${value.request.quantity}',
      if (value.extras.isNotEmpty)
        'Extras: ${value.extras.map((e) => e.label.split(' / ').first).join(', ')}',
      'Excluding tax: ${moneyText(value.amounts.netMinor, currency)}',
      'Tax: ${moneyText(value.amounts.taxMinor, currency)}',
      'Total: ${moneyText(value.amounts.totalMinor, currency)}',
      ...value.warnings,
    ]);
    return lines.join('\n');
  }
}
