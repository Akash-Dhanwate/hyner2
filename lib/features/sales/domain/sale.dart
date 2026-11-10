import '../../inventory/domain/product.dart';
import '../../customers/domain/customer.dart';
import 'sale_price_snapshot.dart';

class SaleLine {
  SaleLine({
    required this.sku,
    required this.name,
    required this.unitPriceMinor,
    required this.quantity,
    this.unitCostMinor = 0,
    this.pricing,
    List<ProductParameter> parameters = const [],
  }) : parameters = List.unmodifiable(parameters);

  factory SaleLine.fromProduct(
    Product product,
    int quantity, {
    int? unitPriceMinor,
    List<ProductParameter>? parameters,
  }) => SaleLine(
    sku: product.sku,
    name: product.name,
    unitPriceMinor: unitPriceMinor ?? product.priceMinor,
    quantity: quantity,
    unitCostMinor: product.costMinor,
    parameters: parameters ?? product.parameters,
  );

  final String sku, name;
  final int unitPriceMinor, quantity, unitCostMinor;
  final List<ProductParameter> parameters;
  final SalePriceSnapshot? pricing;
  bool get stockTracked => pricing == null;
  int get totalMinor => pricing?.totalMinor ?? unitPriceMinor * quantity;
  int get totalCostMinor => unitCostMinor * quantity;

  void validate() {
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,39}$').hasMatch(sku) ||
        name.trim().isEmpty ||
        name.length > 120 ||
        quantity < 1 ||
        quantity > maxStock ||
        unitPriceMinor < 0 ||
        unitPriceMinor > maxMoneyMinor ||
        stockTracked && unitPriceMinor > maxMoneyMinor ~/ quantity ||
        unitCostMinor < 0 ||
        unitCostMinor > maxMoneyMinor ~/ quantity) {
      throw inventoryInvalid(
        'Enter a valid product quantity and keep the bill within the supported total.',
      );
    }
    final snapshot = pricing;
    if (snapshot != null) {
      snapshot.validate();
      if (quantity != snapshot.quantity ||
          unitPriceMinor != snapshot.unitPriceMinor ||
          unitCostMinor != 0) {
        throw inventoryInvalid(
          'Custom line quantity and price must match the saved quote, with no inventory cost.',
        );
      }
    }
    ProductParameter.validateList(parameters);
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'unitPriceMinor': unitPriceMinor,
    'unitCostMinor': unitCostMinor,
    'quantity': quantity,
    'totalMinor': totalMinor,
    'parameters': [for (final parameter in parameters) parameter.toMap()],
    if (pricing != null) 'pricing': pricing!.toJson(),
  };
}

class SaleDraft {
  SaleDraft({
    required this.currency,
    required List<SaleLine> lines,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.initialPaymentMinor,
  }) : lines = List.unmodifiable(lines);

  final String currency;
  final List<SaleLine> lines;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final int? initialPaymentMinor;
  int get totalMinor => lines.fold(0, (sum, line) => sum + line.totalMinor);
  int get taxMinor =>
      lines.fold(0, (sum, line) => sum + (line.pricing?.taxMinor ?? 0));
  int get netMinor => totalMinor - taxMinor;
  int get discountMinor =>
      lines.fold(0, (sum, line) => sum + (line.pricing?.discountMinor ?? 0));
  int get firstPaymentMinor => initialPaymentMinor ?? totalMinor;
  int get units => lines.fold(0, (sum, line) => sum + line.quantity);
  SaleDraft linkedTo(String? id) => SaleDraft(
    currency: currency,
    lines: lines,
    customerId: id,
    customerName: customerName,
    customerPhone: customerPhone,
    customerAddress: customerAddress,
    initialPaymentMinor: initialPaymentMinor,
  );

  void validate() {
    if (!inventoryCurrencies.contains(currency) ||
        lines.isEmpty ||
        lines.map((line) => line.sku).toSet().length != lines.length) {
      throw inventoryInvalid('Choose different products in the same currency.');
    }
    if (customerId != null && customerName == null ||
        customerName != null && customerName!.trim().isEmpty ||
        customerName != null && customerName!.length > 120 ||
        customerPhone != null && customerPhone!.length > 40 ||
        customerAddress != null && customerAddress!.length > 240) {
      throw inventoryInvalid(
        'Choose a valid customer or clear the customer field.',
      );
    }
    for (final line in lines) {
      line.validate();
      if (line.pricing != null && line.pricing!.currency != currency) {
        throw inventoryInvalid('Choose custom quotes in the bill currency.');
      }
    }
    if (totalMinor > maxMoneyMinor ||
        firstPaymentMinor < 0 ||
        firstPaymentMinor > totalMinor) {
      throw inventoryInvalid(
        'The first payment amount must be zero or no more than the bill total.',
      );
    }
  }

  /// Historical anonymous bills remain readable; new bills require a customer
  /// selection or contact details entered at checkout.
  void validateForNewBill() {
    validate();
    if (customerId == null &&
        (customerName?.trim().isNotEmpty != true ||
            !validCustomerMobile(customerPhone ?? ''))) {
      throw inventoryInvalid(
        'Enter the customer name and a valid mobile number.',
      );
    }
  }

  Map<String, dynamic> get items => {
    for (final line in lines) line.sku: line.toMap(),
  };

  bool matches(SaleDraft other) =>
      currency == other.currency &&
      customerId == other.customerId &&
      customerName == other.customerName &&
      customerPhone == other.customerPhone &&
      (customerAddress ?? '') == (other.customerAddress ?? '') &&
      firstPaymentMinor == other.firstPaymentMinor &&
      lines.length == other.lines.length &&
      lines.every(
        (line) => other.lines.any(
          (item) =>
              item.sku == line.sku &&
              item.name == line.name &&
              item.quantity == line.quantity &&
              item.unitPriceMinor == line.unitPriceMinor &&
              item.unitCostMinor == line.unitCostMinor &&
              item.pricing?.snapshotJson == line.pricing?.snapshotJson &&
              _parametersEqual(item.parameters, line.parameters),
        ),
      );
}

bool _parametersEqual(
  List<ProductParameter> first,
  List<ProductParameter> second,
) =>
    first.length == second.length &&
    first.indexed.every(
      (entry) =>
          entry.$2.name == second[entry.$1].name &&
          entry.$2.value == second[entry.$1].value,
    );

enum PaymentStatus { unpaid, partial, paid }

class PaymentEntry {
  const PaymentEntry({
    required this.amountMinor,
    required this.createdAt,
    this.operationId,
  });

  final int amountMinor;
  final String? operationId;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'amountMinor': amountMinor,
    if (operationId != null) 'operationId': operationId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

class Sale {
  const Sale({
    required this.id,
    required this.draft,
    required this.createdAt,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paidAt,
    this.paidMinor = 0,
    this.expectedPaymentMinor = 0,
    this.payments = const [],
    this.followupAt,
  });

  final String id;
  final SaleDraft draft;
  final DateTime createdAt;
  final PaymentStatus paymentStatus;
  final DateTime? paidAt;
  final int paidMinor;
  final int expectedPaymentMinor;
  final List<PaymentEntry> payments;
  final DateTime? followupAt;
  int get remainingMinor {
    final balance = draft.totalMinor - paidMinor;
    if (balance < 0) return 0;
    if (balance > maxMoneyMinor) return maxMoneyMinor;
    return balance;
  }
}

String saleDate(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}
