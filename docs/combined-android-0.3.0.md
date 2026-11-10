# Combined Android workspace — 0.3.0+5

This release combines the business source copied from `/Users/akash/hyner1-full`
with the universal QuickPrice work in `/Users/akash/hyner2`. The source project
was read only. Its own working tree and installed application were not modified.

## What is included

- Universal QuickPrice, its ten pricing strategies, dynamic inputs, owner wizard,
  published rate cards, exact calculations and saved local input drafts.
- Business dashboard, inventory/products/stock adjustments/history/low-stock alerts.
- Multi-product inventory bills, per-bill prices, customer details, pay-later and
  partial payments, remaining payments, UPI QR, customer/seller PDF copies.
- Customer directory/history and opt-in WhatsApp updates/payment follow-up drafts.
- Supplier directory, purchases/stock receipts, supplier returns/payment status.
- Operating expenses, accounting entries, reports/charts/report PDF.
- The original simple quotations and purchase-order registers. These are manual
  customer/supplier descriptions and amounts, not the future QuickPrice estimate
  builder, quotation conversion or stock-receiving workflow.
- Appearance, business/UPI/bill details, logo/signature, local profile editing,
  profile-photo picker, manual business backup/restore.
- Google/email account adapters plus an explicit device-only workspace option.

## Opening and storage

The application renders before account services finish initializing. Device mode
is selected deliberately using **Use on this device**; it does not fabricate a
Firebase user or grant cloud access. The selection persists across restarts.
A failed settings bootstrap offers retry without deleting data.

Business records use `hyner_register_<base64url-account>.db`, schema 8, with a
separate file per account. The device register uses the reserved local identity
`device-local-owner`; it is explicitly distinct from Firebase accounts. No
Firebase console database creation is needed for local operation.

QuickPrice retains `hyner_quickprice`, schema 4, including the existing device
workspace identity/rates from 0.2.0. Signed-in accounts receive separate local
pricing database files with the same schema; device rates keep their original file. Published rules remain immutable. Calculator input, owner draft
and tax approval values are scoped to their pricing workspace. No stock is
changed by calculating or publishing rates.

The two databases keep their established contracts. QuickPrice-to-quotation/bill
conversion is not implemented by silently creating inventory products or sales.
Business backup currently exports business register tables, not QuickPrice rates
or local profile images. Keep the installed application data when updating.

## Transfer from an older installation

The combined package remains `com.hyner.hyner` and updates the 0.2.0 QuickPrice
APK in place using its existing development certificate. Do not uninstall it.

Some `hyner1-full` builds used `com.example.hyner`. Android isolates their files;
copying source cannot transfer their installed databases. In the older app,
export a business backup. In the combined app sign in with the same Firebase
account, open Settings, then Restore business backup. Restore replaces that
account's current register, requires explicit confirmation, validates the backup
account, and runs transactionally. Device mode is a different workspace; it
cannot restore another account's backup. Automatic cloud synchronization is not
included. Optional legacy cloud catalogue import is read-only, checks the
matching signed-in account and has a bounded wait; failures leave local tools
usable. Firebase security rules still govern those reads.

## Corrections made while integrating

- Nonblocking Firebase initialization and explicit device access instead of
  making local tools wait behind an account-service dependency.
- Public legacy inventory constructor fixed; local device mode never imports
  cloud data. Concurrent imports join the same task, preserve existing local
  stock ledgers and use a two-second read budget with retry throttling.
- Schema 7→8 preserves stock history while changing movement uniqueness to
  `(sku,id)`; shared historical sale movement IDs no longer discard rows.
- Full operation IDs retained for sale, purchase and return movements.
- Zero initial payment remains zero when bills reload, preserving same-ID sale
  retries and avoiding another stock deduction.
- Payment confirmation blocks repeated actions. Partial-payment operation IDs
  make same-operation retries idempotent; a changed amount is rejected.
- Backup and report reads are consistent transactions. Invalid/foreign backup
  data cannot silently erase the current register; restoration is atomic.
- Long bill PDFs paginate both copies and repeat table headings.
- Legacy measured pricing uses exact rational arithmetic and explicit half-up
  monetary rounding. The default measured price is per item; bill quantity is
  applied once. Existing saved custom formulas retain their expressions.
- Quotations calculate manually configured tax with integer half-up rounding.
- Quotation/purchase-order/accounting forms use ordinary decimal currency entry,
  provide validation, handle load/write failures and guard account-switch races.
- Expense/WhatsApp errors, stale callbacks and duplicate actions are handled.
- Small-screen sales/customer and bill-layout dropdowns no longer overflow.
- QuickPrice owns a navigator keyed by account scope, including its dialogs.
  Account changes discard the old editor stack; Android Back still dismisses
  dialogs/editors before leaving the calculator.
- Original stale placeholder assertions were updated to exercise actual screens;
  navigation tests scroll to controls and continue checking Android Back/logout.

## Build and verification

Run Flutter commands sequentially to avoid native-assets output collisions.

```
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
python3 tool/build_android.py
flutter build web --release
```

`tool/build_android.py` selects the actual `com.hyner.hyner` registration from
`android/app/google-services.json`, generates build-only account configuration
and passes it to Flutter. It does not invent client IDs, write cloud data,
change Firebase settings or deploy rules. The APK retains development signing
for direct installation and continuity with 0.2.0; a production signing setup
is separate from this phone-test artifact.

Final host verification:

- Formatting: 160 Dart files, no changes required.
- Flutter analysis: no issues.
- Full native-host suite: **510 passed**, one optional screenshot test skipped.
- Includes actual SQLite/FFI tests for migration, stock/idempotency/returns,
  payment retry IDs, reports, backups and account separation.
- Includes editor/dialog removal on account changes, nested Android Back,
  device access with account services pending, and calculator persistence.
- Both read-only final reviews confirmed the pricing scope correction.
- Browser and final build results are appended with the artifact digest.

Known non-failing dependency warnings: several plugins still apply the Kotlin
Gradle Plugin; one Java plugin reports source/target 8 deprecations. These did
not fail the current Android build. No dependencies were upgraded just to hide
warnings.
Physical Android sign-in, external sharing/photo/notification/payment-app flows,
and latency measurements require device testing. An APK build or widget test is
not evidence those physical-device flows passed. Cloud synchronization, staff
permissions, subscription enforcement and the remaining advanced QuickPrice
estimate/comparison/customer-view integrations are not completed by this merge.

## Final APK

- `build/app/outputs/flutter-apk/hyner-combined-0.3.0.apk`
- Version `0.3.0+5`, package `com.hyner.hyner`, Android API 24+.
- 75,509,390 bytes; ARM64, ARMv7 and x86_64 native libraries verified.
- APK v2 signature verification passed; same certificate as 0.2.0.
- SHA-256: `cf5685b88b4118cd4a63ef5d450d4972648d523163803a44137c40a7214e70bd`.
- 41 Chrome tests passed, including combined workspace entry and scope changes.
- No connected Android device was available for installation/runtime profiling.
- Final Android release build and web release build both passed after all fixes.
