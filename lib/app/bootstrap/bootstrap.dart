import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../features/auth/data/device_access_repository.dart';
import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/customers/data/local_customer_repository.dart';
import '../../features/expenses/data/local_expense_repository.dart';
import '../../features/inventory/data/local_inventory_repository.dart';
import '../../features/inventory/data/account_legacy_inventory_repository.dart';
import '../../features/profile/data/local_profile_repository.dart';
import '../../features/purchases/data/local_purchase_repository.dart';
import '../../features/reports/data/local_reports_repository.dart';
import '../../features/sales/data/local_sales_repository.dart';
import '../../features/sales/data/local_bill_document_repository.dart';
import '../../features/settings/data/local_payment_settings_repository.dart';
import '../../core/storage/local_business_database.dart';
import '../config/app_config.dart';
import '../theme/appearance_repository.dart';
import 'app_dependencies.dart';

Future<AuthRepository> _accountServices(AppConfig config) async {
  if (!config.isConfigured) return UnconfiguredAuthRepository();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: config.firebaseOptions)
          .timeout(const Duration(seconds: 10));
    }
    if (Firebase.app().options.projectId != config.firebaseOptions!.projectId ||
        Firebase.app().options.appId != config.firebaseOptions!.appId) {
      return UnconfiguredAuthRepository();
    }
    return FirebaseAuthRepository(
      FirebaseAuth.instance,
      config.googleServerClientId,
    );
  } catch (_) {
    return UnconfiguredAuthRepository();
  }
}

Future<AppDependencies> bootstrap() async {
  final config = AppConfig.fromEnvironment();
  // Starts in the background. Opening device data never waits for Firebase.
  final remote = _accountServices(config);
  final appearance = LocalAppearanceRepository();
  var initialTheme = ThemeMode.system;
  String? notice;
  try {
    initialTheme = await appearance.read().timeout(const Duration(seconds: 3));
  } catch (_) {
    notice = 'Your saved appearance could not be loaded. The device theme is being used.';
  }
  final auth = await DeviceAccessRepository.open(remote)
      .timeout(const Duration(seconds: 5));
  final store = LocalBusinessDatabase.instance;
  return AppDependencies(
    auth: auth,
    profiles: LocalProfileRepository(),
    inventory: LocalInventoryRepository(
      store,
      legacySource: config.isConfigured
          ? AccountLegacyInventoryRepository(remote)
          : null,
    ),
    sales: LocalSalesRepository(store),
    billDocuments: LocalBillDocumentRepository(store),
    customers: LocalCustomerRepository(store),
    paymentSettings: LocalPaymentSettingsRepository(store),
    purchases: LocalPurchaseRepository(store),
    expenses: LocalExpenseRepository(store),
    reports: LocalReportsRepository(store),
    appearance: appearance,
    config: config,
    initialTheme: initialTheme,
    startupNotice: notice,
  );
}
