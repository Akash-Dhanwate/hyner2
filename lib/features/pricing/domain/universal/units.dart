import '../exact.dart';
import '../pricing_models.dart' show validateId, validateName;

/// Exponents preserve physical compatibility through arithmetic. Counts and
/// packages have distinct commercial dimensions until explicitly converted.
final class MeasureDimension {
  MeasureDimension(Map<String, int> powers)
    : powers = Map.unmodifiable(
        Map.fromEntries(powers.entries.where((e) => e.value != 0)),
      ) {
    if (powers.length > 8 ||
        powers.entries.any(
          (e) =>
              !RegExp(r'^[a-zA-Z][a-zA-Z0-9_:]{0,60}$').hasMatch(e.key) ||
              e.value.abs() > 8,
        )) {
      throw ArgumentError('Unsupported measurement dimension');
    }
  }
  final Map<String, int> powers;
  static final scalar = MeasureDimension({});
  static final length = MeasureDimension({'length': 1});
  static final area = MeasureDimension({'length': 2});
  static final volume = MeasureDimension({'length': 3});
  static final mass = MeasureDimension({'mass': 1});
  static MeasureDimension count(String kind) =>
      MeasureDimension({'count:$kind': 1});
  static MeasureDimension package(String kind) =>
      MeasureDimension({'package:$kind': 1});
  static MeasureDimension money(String currency) =>
      MeasureDimension({'money:$currency': 1});
  bool get isCommercialUnit =>
      powers.length == 1 &&
      powers.values.single == 1 &&
      (powers.keys.single.startsWith('count:') ||
          powers.keys.single.startsWith('package:'));
  bool get isPackage =>
      powers.length == 1 &&
      powers.values.single == 1 &&
      powers.keys.single.startsWith('package:');
  MeasureDimension operator *(MeasureDimension other) => _combine(other, 1);
  MeasureDimension operator /(MeasureDimension other) => _combine(other, -1);
  MeasureDimension _combine(MeasureDimension other, int sign) {
    final result = Map<String, int>.from(powers);
    for (final entry in other.powers.entries) {
      result[entry.key] = (result[entry.key] ?? 0) + sign * entry.value;
    }
    return MeasureDimension(result);
  }

  Map<String, Object?> toJson() => Map<String, Object?>.from(powers);
  factory MeasureDimension.fromJson(Map<String, dynamic> json) =>
      MeasureDimension(json.map((k, v) => MapEntry(k, v as int)));
  @override
  bool operator ==(Object other) =>
      other is MeasureDimension &&
      powers.length == other.powers.length &&
      powers.entries.every((e) => other.powers[e.key] == e.value);
  @override
  int get hashCode {
    final keys = powers.keys.toList()..sort();
    return Object.hashAll(keys.map((k) => Object.hash(k, powers[k])));
  }

  @override
  String toString() {
    final keys = powers.keys.toList()..sort();
    return keys.isEmpty
        ? 'scalar'
        : keys.map((k) => '$k^${powers[k]}').join(' · ');
  }
}

final class MeasuredValue {
  const MeasuredValue(this.value, this.dimension);
  final Exact value;
  final MeasureDimension dimension;
  Map<String, Object?> toJson() => {
    'value': '$value',
    'dimension': dimension.toJson(),
  };
}

final class UnitDefinition {
  UnitDefinition({
    required this.id,
    required this.label,
    required this.dimension,
    required this.canonicalFactor,
  }) {
    validateId(id);
    validateName(label);
    if (canonicalFactor <= Exact.zero) {
      throw ArgumentError('Unit conversion factor must be positive');
    }
  }
  final String id;
  final String label;
  final MeasureDimension dimension;
  final Exact canonicalFactor;
  MeasuredValue normalize(Exact value) =>
      MeasuredValue(value * canonicalFactor, dimension);
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'dimension': dimension.toJson(),
    'canonicalFactor': '$canonicalFactor',
  };
  factory UnitDefinition.fromJson(Map<String, dynamic> j) => UnitDefinition(
    id: j['id'] as String,
    label: j['label'] as String,
    dimension: MeasureDimension.fromJson(
      j['dimension'] as Map<String, dynamic>,
    ),
    canonicalFactor: Exact.parse(j['canonicalFactor'] as String),
  );
}

final class UnitRegistry {
  UnitRegistry(Iterable<UnitDefinition> units)
    : units = Map.unmodifiable({for (final u in units) u.id: u}) {
    if (this.units.length != units.length || this.units.length > 128) {
      throw ArgumentError('Duplicate or excessive unit definitions');
    }
    for (final unit in units) {
      final standard = _standards[unit.id];
      if (standard != null &&
          (standard.dimension != unit.dimension ||
              standard.canonicalFactor != unit.canonicalFactor)) {
        throw ArgumentError('Standard units cannot be redefined: ${unit.id}');
      }
    }
  }
  final Map<String, UnitDefinition> units;
  UnitDefinition require(String id) =>
      units[id] ?? (throw ArgumentError('Unknown unit: $id'));
  Exact convert(Exact value, String from, String to) {
    final a = require(from);
    final b = require(to);
    if (a.dimension != b.dimension) {
      throw ArgumentError(
        'Cannot convert $from to $to without a product conversion',
      );
    }
    return value * a.canonicalFactor / b.canonicalFactor;
  }

  factory UnitRegistry.standard({List<UnitDefinition> additional = const []}) =>
      UnitRegistry([..._standards.values, ...additional]);
  static final Map<String, UnitDefinition> _standards = {
    for (final unit in _standardDefinitions()) unit.id: unit,
  };
  static List<UnitDefinition> _standardDefinitions() {
    UnitDefinition u(
      String id,
      String label,
      MeasureDimension d,
      String scale,
    ) => UnitDefinition(
      id: id,
      label: label,
      dimension: d,
      canonicalFactor: Exact.parse(scale),
    );
    return [
      u('number', 'Number', MeasureDimension.scalar, '1'),
      u('percent', 'Percent', MeasureDimension.scalar, '0.01'),
      for (final e in {
        'm': '1',
        'cm': '0.01',
        'mm': '0.001',
        'ft': '0.3048',
        'in': '0.0254',
        'yd': '0.9144',
      }.entries)
        u(e.key, e.key, MeasureDimension.length, e.value),
      for (final e in {
        'm2': '1',
        'ft2': '0.09290304',
        'in2': '0.00064516',
        'cm2': '0.0001',
      }.entries)
        u(e.key, e.key, MeasureDimension.area, e.value),
      for (final e in {
        'm3': '1',
        'ft3': '0.028316846592',
        'litre': '0.001',
        'ml': '0.000001',
      }.entries)
        u(e.key, e.key, MeasureDimension.volume, e.value),
      for (final e in {
        'kg': '1',
        'g': '0.001',
        'tonne': '1000',
        'lb': '0.45359237',
      }.entries)
        u(e.key, e.key, MeasureDimension.mass, e.value),
      for (final kind in ['piece', 'pair', 'set'])
        u(kind, kind, MeasureDimension.count(kind), '1'),
      u('item', 'Item', MeasureDimension.count('piece'), '1'),
      for (final kind in ['bag', 'box', 'carton', 'roll', 'bucket', 'pack'])
        u(kind, kind, MeasureDimension.package(kind), '1'),
    ];
  }

  List<Object?> toJson() {
    final ids = units.keys.toList()..sort();
    return [for (final id in ids) units[id]!.toJson()];
  }

  factory UnitRegistry.fromJson(List<dynamic> j) => UnitRegistry(
    j.map((e) => UnitDefinition.fromJson(e as Map<String, dynamic>)),
  );
}

final class ProductUnitConversion {
  ProductUnitConversion({
    required this.productId,
    required this.from,
    required this.to,
    required this.factor,
  }) {
    validateId(productId);
    if (factor <= Exact.zero) {
      throw ArgumentError('Pack conversion must be positive');
    }
  }
  final String productId;
  final String from;
  final String to;
  final Exact factor;
  Map<String, Object?> toJson() => {
    'productId': productId,
    'from': from,
    'to': to,
    'factor': '$factor',
  };
  factory ProductUnitConversion.fromJson(Map<String, dynamic> j) =>
      ProductUnitConversion(
        productId: j['productId'] as String,
        from: j['from'] as String,
        to: j['to'] as String,
        factor: Exact.parse(j['factor'] as String),
      );
}

enum CommercialUnitRole { selling, purchase, inventory, display }

/// Validated product-scoped graph. Multiple paths must agree exactly. This is
/// conversion metadata only; it cannot cause an inventory movement.
final class ProductUnitSystem {
  ProductUnitSystem({
    required this.productId,
    required this.registry,
    List<ProductUnitConversion> conversions = const [],
    Map<CommercialUnitRole, String> roles = const {},
  }) : conversions = List.unmodifiable(conversions),
       roles = Map.unmodifiable(roles) {
    validateId(productId);
    if (conversions.length > 64) {
      throw ArgumentError('Too many product conversions');
    }
    final edges = <String, Map<String, Exact>>{
      for (final id in registry.units.keys) id: {},
    };
    void link(String a, String b, Exact factor) {
      if (edges[a]![b] != null && edges[a]![b] != factor) {
        throw ArgumentError('Conflicting unit conversion');
      }
      edges[a]![b] = factor;
      edges[b]![a] = Exact.one / factor;
    }

    for (final a in registry.units.values) {
      for (final b in registry.units.values) {
        if (a.dimension == b.dimension) {
          link(a.id, b.id, a.canonicalFactor / b.canonicalFactor);
        }
      }
    }
    for (final c in conversions) {
      if (c.productId != productId) {
        throw ArgumentError('Conversion belongs to another product');
      }
      final a = registry.require(c.from);
      final b = registry.require(c.to);
      if (a.dimension != b.dimension &&
          !a.dimension.isCommercialUnit &&
          !b.dimension.isCommercialUnit) {
        throw ArgumentError(
          'Unrelated physical dimensions require an explicit formula',
        );
      }
      link(c.from, c.to, c.factor);
    }
    for (final start in edges.keys) {
      final found = <String, Exact>{start: Exact.one};
      final queue = [start];
      for (var i = 0; i < queue.length; i++) {
        for (final e in edges[queue[i]]!.entries) {
          final factor = found[queue[i]]! * e.value;
          if (found.containsKey(e.key)) {
            if (found[e.key] != factor) {
              throw ArgumentError(
                'Inconsistent conversion cycle for $productId',
              );
            }
          } else {
            found[e.key] = factor;
            queue.add(e.key);
          }
        }
      }
      _paths[start] = Map.unmodifiable(found);
    }
    for (final id in roles.values) {
      registry.require(id);
    }
    if (roles.isNotEmpty) {
      final first = roles.values.first;
      for (final id in roles.values) {
        convert(Exact.one, first, id);
      }
    }
  }
  final String productId;
  final UnitRegistry registry;
  final List<ProductUnitConversion> conversions;
  final Map<CommercialUnitRole, String> roles;
  final Map<String, Map<String, Exact>> _paths = {};
  Exact convert(Exact value, String from, String to) {
    registry.require(from);
    registry.require(to);
    final factor = _paths[from]?[to];
    if (factor == null) {
      throw ArgumentError(
        'No approved $productId conversion from $from to $to',
      );
    }
    return value * factor;
  }

  Map<String, Object?> toJson() => {
    'productId': productId,
    'units': registry.toJson(),
    'conversions': conversions.map((c) => c.toJson()).toList(),
    'roles': roles.map((k, v) => MapEntry(k.name, v)),
  };
  factory ProductUnitSystem.fromJson(Map<String, dynamic> j) =>
      ProductUnitSystem(
        productId: j['productId'] as String,
        registry: UnitRegistry.fromJson(j['units'] as List),
        conversions: (j['conversions'] as List)
            .map(
              (e) => ProductUnitConversion.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        roles: (j['roles'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(CommercialUnitRole.values.byName(k), v as String),
        ),
      );
}
