import 'exact.dart';

enum LengthUnit { feet, feetInches, inches, millimetres, centimetres, metres }

enum Axis { height, width, depth }

extension LengthConversion on LengthUnit {
  Exact get metresPerUnit => Exact.parse(switch (this) {
    LengthUnit.feet || LengthUnit.feetInches => '0.3048',
    LengthUnit.inches => '0.0254',
    LengthUnit.millimetres => '0.001',
    LengthUnit.centimetres => '0.01',
    LengthUnit.metres => '1',
  });
  Exact toMetres(Exact value) => value * metresPerUnit;
  Exact fromMetres(Exact value) => value / metresPerUnit;
}

/// Metres internally; entered units are retained for presentation.
final class Dimensions {
  Dimensions(Map<Axis, Exact> metres, {this.enteredUnit = LengthUnit.metres})
    : metres = Map.unmodifiable(metres) {
    if (metres.values.any(
      (v) => v <= Exact.zero || v > Exact.integer(1000000),
    )) {
      throw ArgumentError(
        'Dimensions must be positive and within supported limits',
      );
    }
  }
  factory Dimensions.entered(Map<Axis, Exact> values, LengthUnit unit) =>
      Dimensions(
        values.map((key, value) => MapEntry(key, unit.toMetres(value))),
        enteredUnit: unit,
      );

  /// 7′6″ is never interpreted as 7.6 feet.
  static Exact feetAndInches({required int feet, required Exact inches}) {
    if (feet < 0 || inches < Exact.zero || inches >= Exact.integer(12)) {
      throw ArgumentError('Use nonnegative feet and inches below 12');
    }
    return LengthUnit.feet.toMetres(Exact.integer(feet)) +
        LengthUnit.inches.toMetres(inches);
  }

  final Map<Axis, Exact> metres;
  final LengthUnit enteredUnit;
  Exact require(Axis axis) =>
      metres[axis] ?? (throw ArgumentError('Enter ${axis.name}'));
  Exact get squareMetres => require(Axis.height) * require(Axis.width);
  Exact get squareFeet =>
      squareMetres /
      (LengthUnit.feet.metresPerUnit * LengthUnit.feet.metresPerUnit);
  Exact get cubicMetres => squareMetres * require(Axis.depth);
  Map<String, Object?> toJson() => {
    'enteredUnit': enteredUnit.name,
    'metres': metres.map((key, value) => MapEntry(key.name, value.toString())),
  };
  factory Dimensions.fromJson(Map<String, dynamic> json) => Dimensions(
    (json['metres'] as Map<String, dynamic>).map(
      (key, value) =>
          MapEntry(Axis.values.byName(key), Exact.parse(value as String)),
    ),
    enteredUnit: LengthUnit.values.byName(json['enteredUnit'] as String),
  );
}
