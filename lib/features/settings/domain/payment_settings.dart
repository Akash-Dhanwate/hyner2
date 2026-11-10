import '../../inventory/domain/product.dart';
import '../../sales/domain/sale.dart';

enum BillLayout { right, centered }

enum BillTextSection {
  businessName('Business name'),
  businessDetails('Business details'),
  billDetails('Bill reference and date'),
  customer('Customer details'),
  items('Products and specifications'),
  totals('Totals and payment amounts'),
  footer('Footer and signature');

  const BillTextSection(this.label);
  final String label;
}

class PaymentSettings {
  const PaymentSettings({
    this.upiId = '',
    this.merchantName = '',
    this.businessPhone = '',
    this.businessAddress = '',
    this.taxId = '',
    this.billLayout = BillLayout.right,
    this.logoBase64 = '',
    this.signatureBase64 = '',
    this.headerFontSize = 20,
    this.footerText = 'Thank you for your business.',
    this.fontColors = const {},
  });

  final String upiId;
  final String merchantName;
  final String businessPhone;
  final String businessAddress;
  final String taxId;
  final BillLayout billLayout;
  final String logoBase64;
  final String signatureBase64;
  final double headerFontSize;
  final String footerText;
  final Map<BillTextSection, int> fontColors;

  int fontColor(BillTextSection section) =>
      fontColors[section] ??
      (section == BillTextSection.businessDetails ||
              section == BillTextSection.footer
          ? 0x64707d
          : 0x19212b);

  bool get isReady =>
      RegExp(r'^[A-Za-z0-9._-]{2,100}@[A-Za-z0-9.-]{2,64}$')
          .hasMatch(upiId.trim()) &&
      merchantName.trim().isNotEmpty;

  Uri? upiUri(Sale sale, {int? amountMinor}) {
    final amount = amountMinor ?? sale.draft.totalMinor;
    if (!isReady ||
        sale.draft.currency != 'INR' ||
        amount <= 0 ||
        amount > sale.remainingMinor ||
        amount > sale.draft.totalMinor) {
      return null;
    }
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId.trim(),
        'pn': merchantName.trim(),
        'am': moneyDecimal(amount),
        'cu': 'INR',
        'tn': 'Hyner bill ${sale.id}',
        'tr': '${sale.id}-${sale.payments.length + 1}',
      },
    );
  }
}

abstract interface class PaymentSettingsRepository {
  Future<PaymentSettings> read(String uid);
  Future<void> save(String uid, PaymentSettings settings);
}
