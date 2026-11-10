import 'exact.dart';
import 'pricing_models.dart';

/// Structure only. There are deliberately no rates or publishable rules.
RateCardDraft doorTemplate(Currency currency) => RateCardDraft(
  name: 'Door Price Calculator',
  currency: currency,
  industryTemplate: 'doors',
  categories: [
    PricingCategory(id: 'basic_flush', name: 'Basic Flush Door', sortOrder: 0),
    PricingCategory(
      id: 'premium_flush',
      name: 'Premium Flush Door',
      sortOrder: 1,
    ),
    PricingCategory(id: 'wpc', name: 'WPC Door', sortOrder: 2),
    PricingCategory(id: 'designer', name: 'Designer Door', sortOrder: 3),
  ],
);
