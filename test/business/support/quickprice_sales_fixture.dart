import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart'
    show DiscountPolicy, TaxBehavior, TaxPolicy;
import 'package:hyner/features/pricing/domain/universal/universal_pricing.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/sale_price_snapshot.dart';

import '../../support/universal_fixture.dart' as u;

PricingResult measuredQuote({
  String variety = 'plain',
  String width = '1',
  String height = '1',
  int quantity = 3,
  TaxBehavior taxBehavior = TaxBehavior.exclusive,
}) => u.price(
  u.rule(
    strategy: u.measured(
      StrategyKind.area,
      u.mul(u.ref('width'), u.ref('height')),
      'base',
      'ft2',
    ),
    fields: [
      u.choice('variety', ['plain', 'premium']),
      u.number('width', 'ft'),
      u.number('height', 'ft'),
    ],
    rates: [
      u.rate(
        'base',
        '1.01',
        'ft2',
        id: 'plain',
        selectors: {'variety': 'plain'},
      ),
      u.rate(
        'base',
        '1.37',
        'ft2',
        id: 'premium',
        selectors: {'variety': 'premium'},
      ),
      u.rate('handling', '0.01', 'piece'),
    ],
    extras: [
      PriceComponent(
        id: 'handling',
        label: 'Handling',
        strategy: u.piece('handling'),
        perOrder: true,
      ),
    ],
    tax: TaxPolicy(
      reference: 'gst-18',
      behavior: taxBehavior,
      percent: u.e(taxBehavior == TaxBehavior.exempt ? '0' : '18'),
    ),
    discount: DiscountPolicy(percent: u.e('5'), fixedPerLine: u.e('0.01')),
  ),
  inputs: {
    'variety': ChoiceInput(variety),
    'width': u.n(width, 'ft'),
    'height': u.n(height, 'ft'),
  },
  quantity: quantity,
);

SaleLine measuredSaleLine(int index, {PricingResult? result, String? sku}) {
  final pricing = SalePriceSnapshot.fromResult(result ?? measuredQuote());
  return SaleLine(
    sku: sku ?? 'QP_${index.toRadixString(16).padLeft(32, '0')}',
    name: 'Measured panel',
    unitPriceMinor: pricing.unitPriceMinor,
    quantity: pricing.quantity,
    pricing: pricing,
    parameters: const [ProductParameter(name: 'Source', value: 'QuickPrice')],
  );
}

List<SaleLine> sixMeasuredLines() => [
  for (var index = 0; index < 6; index++)
    measuredSaleLine(
      index,
      result: measuredQuote(
        variety: index < 3 ? 'plain' : 'premium',
        width: ['1', '1.25', '2'][index % 3],
        height: ['1', '2.5', '3.125'][index % 3],
      ),
    ),
];

SaleDraft customSaleDraft(
  List<SaleLine> lines, {
  int? initialPaymentMinor = 0,
}) => SaleDraft(
  currency: 'INR',
  customerName: 'Asha Buyer',
  customerPhone: '9876543210',
  customerAddress: '42 Market Road',
  initialPaymentMinor: initialPaymentMinor,
  lines: lines,
);
