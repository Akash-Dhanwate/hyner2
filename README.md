# Hyner — business workspace and universal QuickPrice

Android build **0.7.0+10** combines the business features copied from
`hyner1-full` with the current universal QuickPrice calculator. The original
source folder remains untouched.

The current release unifies the business and calculator UI, groups optional
settings and item specifications, and keeps primary selling actions direct.
See the [UI/UX audit, implementation report and before/after captures](UX_REDESIGN_REPORT.md).

## Use the Android app

Install the matching `hyner-0.7.0-ux-redesign-arm64-v8a.apk` (most current phones),
`hyner-0.7.0-ux-redesign-armeabi-v7a.apk` (32-bit Android), or
`hyner-0.7.0-ux-redesign-x86_64.apk` from `build/app/outputs/flutter-apk/`.
The separately built universal APK is the compatibility fallback. Install over the
existing Hyner application; do not uninstall or clear app data. The original
universal APK remains preserved. See [Plan A measurement and rollback guidance](docs/performance/PLAN_A.md).

Choose **Use on this device** for local inventory, sales, purchases, customers,
expenses, accounting, quotations, purchase orders, reports, settings and
QuickPrice. No Firebase database setup is needed for this mode. Google/email
sign-in opens a separate account workspace using the existing Firebase project.
The build script obtains configuration from the actual Android registration.
Business data stays on the phone; automatic cloud sync is not included.

Open **QuickPrice**, choose Create calculator, select Doors (or another template),
enter product names and selling rates, then **Save and use calculator**. Door
measurements default to inches, taxes default off, and final money uses half-up
rounding to paisa/cents. Extras, tax settings and advanced configuration are
optional. Saved calculators reopen without repeating setup.

Use **Add variety** under a product to save named types such as Flush and
Laminated with separate rates. Existing calculators support this through
**More options → Edit selling rates**. Choose the **Variety** on the calculator;
measurements and quantity stay in place while the price recalculates.
The visible **Customer rate** field applies a negotiated rate to the current
item without changing saved rates. Switching variety restores its saved rate.
Estimate and bill items retain their selected variety and agreed price.

The shared unit selector converts the physical measurements together; uncheck
**Use the same unit** for different units. Exact source measurements are retained
when a converted display needs rounding. Optional calculation-only rate changes
are separate from **Edit selling rates**, which publishes a new immutable version.

Build a customer project by calculating an item and tapping **Add to Estimate**.
Change product, measurements or quantity and add the next item. **View estimate**
shows all rows and the grand total; items can be edited, duplicated, removed or
reordered. Copy/share includes the entire estimate. Drafts persist locally.

Choose **Continue to Sales** from the estimate. The saved items, quantities,
measurements and exact prices arrive prefilled. Enter/select the customer, add
payment details and **Generate bill**. Custom QuickPrice items are not assumed to
be inventory SKUs; stock changes only for actual catalog products explicitly added
to Sales. Reopening the same estimate opens its existing bill instead of creating
a duplicate. Start a new estimate for another order.

Sales now start with products. Customer name and mobile are required at checkout
when entering bill contact details; address is optional. Saved bills expose
**WhatsApp PDF**, **Print original** and **Save PDF** after the payment section. Only the
Original goes to WhatsApp. A compact Duplicate is compressed and archived locally;
Save duplicate PDF exports it as a normal PDF. Document actions operate on the
saved bill and never deduct stock again.

Checkout automatically saves and links a new customer by name and mobile.
Customers can be searched by name, mobile, readable customer ID or added date.
Customer history includes products, saved specifications, bill dates and payment
totals. Existing unlinked bills with usable contact details are linked during
the local database upgrade without changing their prices or stock.

Open **Settings → Bill appearance** (also available on a saved bill) to configure
your business name, address, logo, signature and footer. Measurements used in
bill component calculations are copied onto the bill with their units. Unit
prices and amounts retain their decimal values.

If the older business APK was installed as `com.example.hyner`, its data is in a
separate Android app. Export a backup there, sign into the same account here,
and use Settings → Restore business backup. Restore replaces the current
account register after confirmation. Business backups currently do not include
QuickPrice rates, active estimate drafts or local profile images.

## Included and pending

The copied business features include inventory stock history, supplier purchases
and returns, multi-product bills, partial/pay-later payment records, exact-amount
UPI QR, separate paginated Original/Duplicate PDFs, customer history, expenses, reports,
manual quotation/purchase-order/accounting registers and opted-in WhatsApp
message drafts. WhatsApp requires the seller to send messages. UPI payments
are verified by the seller, not automatically processed by Hyner.

QuickPrice retains all ten universal strategies, its guided setup, exact rational
engine, dynamic input schema, immutable published rate cards, offline local
calculation, input persistence, breakdown and customer-safe price text sharing.

Multi-item QuickPrice estimates and direct bill checkout are included. Advanced
comparison/customer presentation and automatic quotation conversion remain pending.
Cloud sync, backend staff permissions and paid-plan enforcement remain pending.
This directly installable APK uses the existing development certificate.

Read [the variety and customer-rate release notes](docs/calculator-varieties-0.6.1.md), [the previous UX release notes](docs/estimate-android-0.6.0.md) and [the combined release notes](docs/combined-android-0.3.0.md) for fixes,
storage/transfer details, validation results and device testing boundaries.
Historical domain contracts remain in [Stage A](docs/universal-stage-a.md),
[Stage B](docs/universal-stage-b.md) and [Stages C–D](docs/universal-stages-c-d.md).

## Build and check

Flutter/Dart versions and dependencies are pinned by the project. Run Flutter
commands sequentially to avoid shared native-assets output collisions.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
python3 tool/build_android.py --label ux-redesign
flutter build web --release
```

The Android script reads `android/app/google-services.json` and creates build-only
Dart configuration for `com.hyner.hyner`. It does not deploy rules or modify
Firebase services. Business database schema 12 upgrades the copied register
additively, including customer/bill addresses, indexed customer identity matching,
historical bill links, compressed local Duplicate archives and additive query indexes.
Portable backup rows remain format 10. QuickPrice schema 4 preserves earlier rates and snapshots.
