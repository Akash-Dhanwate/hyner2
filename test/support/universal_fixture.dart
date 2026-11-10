import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart'
    show TaxPolicy, TaxBehavior, DiscountPolicy;
import 'package:hyner/features/pricing/domain/universal/universal_pricing.dart';

Exact e(String value) => Exact.parse(value);
final at = DateTime.utc(2026, 11, 8);
final registry = UnitRegistry.standard();
InputDefinition number(
  String id,
  String unit, {
  String? min = '0.001',
  String? max = '100000',
  int precision = 6,
  bool required = true,
  InputValue? defaultValue,
  List<String>? permitted,
  VisibilityCondition? visibleWhen,
  Exact? multipleOf,
  InputDataType type = InputDataType.decimal,
}) => InputDefinition(
  id: id,
  label: id,
  type: type,
  dimension: registry.require(unit).dimension,
  defaultUnit: unit,
  permittedUnits: permitted ?? [unit],
  required: required,
  minimum: min == null ? null : e(min),
  maximum: max == null ? null : e(max),
  precision: precision,
  defaultValue: defaultValue,
  visibleWhen: visibleWhen,
  multipleOf: multipleOf,
);
InputDefinition choice(String id, List<String> values, {String? initial}) =>
    InputDefinition(
      id: id,
      label: id,
      type: InputDataType.choice,
      dimension: MeasureDimension.scalar,
      defaultUnit: null,
      permittedUnits: [],
      choices: values,
      defaultValue: initial == null ? null : ChoiceInput(initial),
    );
InputDefinition toggle(String id, {bool initial = false}) => InputDefinition(
  id: id,
  label: id,
  type: InputDataType.boolean,
  dimension: MeasureDimension.scalar,
  defaultUnit: null,
  permittedUnits: [],
  defaultValue: BooleanInput(initial),
);
Expression ref(String id) => Reference(id);
Expression literal(String value, [MeasureDimension? dimension]) =>
    Literal(e(value), dimension ?? MeasureDimension.scalar);
Expression mul(Expression a, Expression b) =>
    Arithmetic(ArithmeticOperation.multiply, a, b);
Expression add(Expression a, Expression b) =>
    Arithmetic(ArithmeticOperation.add, a, b);
Expression div(Expression a, Expression b) =>
    Arithmetic(ArithmeticOperation.divide, a, b);
FormulaProgram program(Expression expression) =>
    FormulaProgram(output: expression);
SellingRate rate(
  String key,
  String amount,
  String unit, {
  String? id,
  Map<String, String> selectors = const {},
}) => SellingRate(
  id: id ?? key,
  key: key,
  amount: e(amount),
  unit: unit,
  selectors: selectors,
);
MeasuredRateStrategy measured(
  StrategyKind kind,
  Expression expression,
  String key,
  String unit, {
  BillableQuantityPolicy? policy,
}) => MeasuredRateStrategy(
  kind: kind,
  measure: program(expression),
  rateKey: key,
  policy: policy ?? BillableQuantityPolicy(unit: unit),
);
MeasuredRateStrategy piece(String key) => measured(
  StrategyKind.perUnit,
  literal('1', MeasureDimension.count('piece')),
  key,
  'piece',
);
UniversalPricingRule rule({
  required PricingStrategy strategy,
  required List<SellingRate> rates,
  List<InputDefinition> fields = const [],
  ProductUnitSystem? units,
  TaxPolicy? tax,
  DiscountPolicy? discount,
  List<PriceComponent> extras = const [],
  List<InputBillingRule> inputBilling = const [],
  int version = 1,
  MoneyRounding rounding = MoneyRounding.halfUp,
  DateTime? effectiveAt,
  DateTime? expiresAt,
}) {
  final system =
      units ?? ProductUnitSystem(productId: 'product', registry: registry);
  return UniversalPricingRule(
    businessId: 'business',
    productId: system.productId,
    id: 'rule',
    version: version,
    currency: Currency('INR', 2),
    schema: InputSchema(fields, system),
    rates: rates,
    strategy: strategy,
    tax:
        tax ??
        TaxPolicy(
          reference: 'approved-zero',
          behavior: TaxBehavior.exempt,
          percent: Exact.zero,
        ),
    discount: discount,
    effectiveAt: effectiveAt ?? at,
    expiresAt: expiresAt,
    extras: extras,
    inputBilling: inputBilling,
    rounding: rounding,
  );
}

PricingResult price(
  UniversalPricingRule definition, {
  Map<String, InputValue> inputs = const {},
  int quantity = 1,
}) => UniversalPricingEngine().calculate(
  definition,
  UniversalPricingRequest(inputs: inputs, quantity: quantity),
  at: at,
);
NumberInput n(String value, String unit) => NumberInput(e(value), unit);
