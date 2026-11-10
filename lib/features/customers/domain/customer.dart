import 'dart:convert';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    this.address = '',
    this.whatsappOptIn = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String notes;
  final String address;
  final bool whatsappOptIn;
  final DateTime createdAt;
  final DateTime updatedAt;
  String get reference => customerReference(name, phone, id);
}

String normalizedCustomerName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
String normalizedCustomerPhone(String value) =>
    value.replaceAll(RegExp(r'\D'), '');

String? customerIdentityKey(String name, String phone) =>
    name.trim().isEmpty || !validCustomerMobile(phone)
    ? null
    : jsonEncode([
        normalizedCustomerName(name),
        normalizedCustomerPhone(phone),
      ]);

String customerReference(String name, String phone, String id) {
  var label = name
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (label.isEmpty) label = 'CUSTOMER';
  if (label.length > 24) {
    label = label.substring(0, 24).replaceFirst(RegExp(r'-+$'), '');
  }
  final number = normalizedCustomerPhone(phone);
  final suffix = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  return '$label-${number.isEmpty ? 'NO-MOBILE' : number}-${suffix.length > 6 ? suffix.substring(suffix.length - 6) : suffix}';
}

class CustomerDraft {
  const CustomerDraft({
    required this.name,
    this.phone = '',
    this.notes = '',
    this.address = '',
    this.whatsappOptIn = true,
  });

  final String name;
  final String phone;
  final String notes;
  final String address;
  final bool whatsappOptIn;

  void validate() {
    if (name.trim().isEmpty || name != name.trim() || name.length > 120) {
      throw const FormatException('Enter a customer name of 1–120 characters.');
    }
    if (phone.length > 40 || notes.length > 500 || address.length > 240) {
      throw const FormatException(
        'Keep phone under 40 characters, address under 240, and notes under 500.',
      );
    }
  }
}

bool validCustomerMobile(String value) {
  final phone = value.trim();
  if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone)) return false;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 15;
}
