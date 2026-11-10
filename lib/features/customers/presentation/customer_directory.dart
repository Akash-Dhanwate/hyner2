import '../domain/customer.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String customerAddedDate(DateTime createdAt) {
  final date = createdAt.toLocal();
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

bool matchesCustomerDirectoryQuery(Customer customer, String query) {
  final normalized = normalizedCustomerName(query);
  if (normalized.isEmpty) return true;
  final date = customer.createdAt.toLocal();
  final month = _months[date.month - 1];
  final searchable = [
    customer.name,
    customer.phone,
    normalizedCustomerPhone(customer.phone),
    customer.id,
    customer.reference,
    customerAddedDate(customer.createdAt),
    '${date.day}/${date.month}/${date.year}',
    date.toIso8601String().split('T').first,
    '${date.day} $month ${date.year}',
    '${date.day} ${month.substring(0, 3)} ${date.year}',
  ].join(' ').toLowerCase();
  if (normalized.split(' ').every(searchable.contains)) return true;

  // Match a phone pasted with spaces, brackets, or a country-code prefix.
  final phone = normalizedCustomerPhone(normalized);
  return phone.isNotEmpty &&
      RegExp(r'^[+0-9 ()-]+$').hasMatch(normalized) &&
      normalizedCustomerPhone(customer.phone).contains(phone);
}
