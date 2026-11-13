import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../../features/customers/domain/customer_repository.dart';
import '../../features/expenses/domain/expense_repository.dart';
import '../../features/inventory/domain/inventory_repository.dart';
import '../../features/profile/domain/profile_repository.dart';
import '../../features/purchases/domain/purchase_repository.dart';
import '../../features/reports/domain/reports_repository.dart';
import '../../features/sales/domain/sales_repository.dart';
import '../../features/sales/domain/bill_document_repository.dart';
import '../../features/settings/domain/payment_settings.dart';
import '../config/app_config.dart';
import '../theme/appearance_repository.dart';
import '../theme/theme_preset.dart';

class AppDependencies {
  const AppDependencies({
    required this.auth,
    required this.profiles,
    required this.inventory,
    required this.sales,
    required this.customers,
    required this.paymentSettings,
    required this.purchases,
    required this.reports,
    required this.appearance,
    required this.config,
    this.expenses = const UnconfiguredExpenseRepository(),
    this.initialTheme = ThemeMode.system,
    this.initialPreset = ThemePreset.sageGreen,
    this.startupNotice,
    this.billDocuments,
  });

  final AuthRepository auth;
  final ProfileRepository profiles;
  final InventoryRepository inventory;
  final SalesRepository sales;
  final CustomerRepository customers;
  final PaymentSettingsRepository paymentSettings;
  final PurchaseRepository purchases;
  final ReportsRepository reports;
  final AppearanceRepository appearance;
  final ExpenseRepository expenses;
  final AppConfig config;
  final ThemeMode initialTheme;
  final ThemePreset initialPreset;
  final String? startupNotice;
  final BillDocumentRepository? billDocuments;
}

final dependenciesProvider = Provider<AppDependencies>(
  (ref) => throw StateError(
    'Application dependencies must be initialized before launch.',
  ),
);

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(dependenciesProvider).initialTheme;

  Future<void> select(ThemeMode mode) async {
    await ref.read(dependenciesProvider).appearance.write(mode);
    state = mode;
  }
}

final themePresetProvider =
    NotifierProvider<ThemePresetController, ThemePreset>(
      ThemePresetController.new,
    );

class ThemePresetController extends Notifier<ThemePreset> {
  Future<void> _tail = Future.value();
  @override
  ThemePreset build() => ref.read(dependenciesProvider).initialPreset;

  /// Serialize preference writes so fast selections persist in their chosen order.
  Future<void> select(ThemePreset preset) {
    final repository = ref.read(dependenciesProvider).appearance;
    final next = _tail.then((_) async {
      await repository.writePreset(preset);
      if (ref.mounted) state = preset;
    });
    _tail = next.catchError((Object _) {});
    return next;
  }
}
