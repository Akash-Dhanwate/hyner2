# Sales and reports refinements — 0.7.1+11

This release keeps the existing logo, palette, calculator varieties, negotiated
rates, stock handling, billing, account workspaces and offline workflows.

## Sales entry and history

- Sales opens with **Build a bill → Add product**. Customer details, payment
  inputs and Generate bill appear after a product is selected. Calculator
  checkout arrives with its existing items and retains customer/payment entry.
- The empty builder shows the latest three saved bills, a search field and Saved
  bills. Adding further products remains available above the item list.
- Saved bills searches the complete local history by customer name, mobile,
  reference or **exact total bill amount**. Names are case-insensitive; mobile
  formatting is ignored. Examples: `Sudeep`, `9876543210`, `25000`, `₹25,000.00`.
  Numeric searches can match either a mobile or a total; they are not amount
  ranges or item-price searches. Results retain newest-first pagination.
- Search is submitted explicitly. Recent bills have independent state and a
  database limit of three; history searches do not filter that preview. Search
  text is passed internally between screens rather than included in the URL.
- Customer names lead each bill summary and the bill detail page. Amounts follow
  the contact/reference information.

Search scans older records in bounded batches of 32 and returns at most 30
matches per page. This avoids loading an entire history into memory and supports
older Android SQLite versions without JSON SQL functions. It is still a linear
scan: very large histories may take longer, particularly for numeric searches.
No search latency or device-memory improvement is claimed without measurement.

## Bill contact corrections

**Edit customer details** changes only that bill's name and mobile within seven
24-hour periods after its original creation time. Exactly seven days later it is
locked. The repository checks the limit inside the write transaction, including
when the dialog was opened earlier. It also checks the expected previous contact
values to reject stale competing edits.

The bill ID/reference, creation time, amounts, item lines, stock movements,
payment records, linked customer ID, saved customer profile, other bills and
WhatsApp consent remain unchanged. Existing archived duplicate PDFs remain
immutable; newly generated original copies use the corrected bill contact.
Each correction writes its old/new contact and timestamp into the existing
settings store under a namespaced audit key. Tests verify that this audit and
the corrected contact survive export/restore. There is no database migration
(schema remains 12; export format remains 10).

The offline window uses the device clock. It is not a server-enforced or
clock-tamper-resistant restriction. There is no administrator override in this
release. Expired contacts remain readable.

## Calmer bill details and inventory

- Payment history, reminders and secondary document actions use existing
  expandable controls. Main payment and bill-copy workflows remain available.
- Optional UPI setup/QR explanations appear through the red eye button. Settings
  and retry actions are offered inside the explanation when appropriate. Actual
  save/payment failures remain visible.
- Payment received and remaining balance share a row where space permits;
  enlarged text and narrow screens retain a stacked layout.
- Inventory product rows have clear rectangular boundaries. Product entry,
  quantities and stock actions retain their behavior.
- Contact entry supports scrolling with an open keyboard, inline validation and
  a pending-save state. Neither the reference nor any amount is an editable field.

## Reports: sales, earnings and money received

- **Sales revenue** remains the amount billed for the selected currency/period.
- **Gross profit** uses the selling amounts and buying costs saved on the bills.
- **Earnings after costs** is gross profit minus recorded operating expenses.
  Inventory purchases are not subtracted a second time: sold-item costs already
  account for the stock used. Unrecorded expenses cannot be included.
- **Payment received** remains recorded payments on bills created in the selected
  period, including later payments on those bills. It is not a cash-receipts
  ledger grouped by payment date, and earnings are not an available cash balance.
- Bills without saved buying costs, including custom-calculator and legacy bills,
  are excluded from gross profit. The earnings display explicitly says
  **Known-cost earnings** and marks the result incomplete when these exist.
- Home and the exported report also include the earnings figure. Reports show
  three recent sales in the selected period alongside the existing sales count,
  units, revenue, received and due totals.
- The activity chart initially positions itself at its latest week/period.
  Users can scroll backward. Refreshes within the same range preserve that
  position; changing the period/currency resets to the latest activity.

Verified arithmetic fixture: two units bought at INR 150 and sold at INR 165
produce INR 330 sales, INR 30 gross profit, and INR 20 earnings after an INR 10
operating expense. An additional INR 1,500 stock purchase does not reduce that
INR 20 a second time. INR 10 received and INR 320 due remain independent totals.

## Implementation and verification

Changes are confined to sales repository/search/controller/widgets, the existing
shared help widget, inventory row presentation, report/earnings presentation and
PDF export, Home's earnings metric, version metadata, tests and documentation.
New production files are `sale_search.dart`, `bill_summary.dart` and
`bill_contact_dialog.dart`. No production dependency was added.

Verification evidence is under `build/sales-refinement/`:

- `analyze-final.log`: no static-analysis issues.
- `all-tests-final.log`: 710 passed, four existing opt-in tests skipped.
- `feature-final.log`: all 12 focused database/UI/chart/PDF checks passed.
- Real SQLite tests search 85 bills, paginate matching results without duplicates,
  reject cross-account/stale/expired/invalid edits, verify all other persisted
  sale columns and archived duplicate bytes are unchanged, and exercise backup.
- Widget tests cover required customer fields, multi-product bills, calculator
  checkout, navigation/discard behavior, payment saving, account changes, 320dp
  layouts, enlarged text, light/dark mode and an open keyboard.
- `after/`: inspected real-font sales/search/bill/contact screenshots, including
  320dp dark mode at 1.8x text with keyboard insets; report PDF rendered and
  inspected on all three fixture pages.

Release build results and exact artifact sizes/checksums are recorded below after
packaging. Android signing, package/version, ABI and release-artifact checks use
`tool/build_android.py`. No Android device was connected, so installation,
WhatsApp sharing, printing, device-clock behavior and physical-device performance
have not been tested on hardware. iOS was not built in this task.

## Update and rollback

Install the matching APK over the existing Hyner app; do not uninstall or clear
its data. ARM64 is appropriate for most current phones; universal is the
compatibility fallback. Package and signing identity are preserved.

The starting source snapshot and existing-work diff are preserved in
`build/sales-refinement/before/`. Roll back only this release's source changes and
build with a higher Android version code; Android normally rejects installing an
older version over a newer one. No schema rollback is needed. Preserve any
contact corrections and audit entries: a prior UI will ignore the extra settings
keys while retaining corrected bill contact snapshots. Export a backup before
manual data recovery; do not remove audit keys or recreate historical sales.

## Verified release artifacts

- `hyner-0.7.1-sales-refinement-armeabi-v7a.apk`: 25,938,913 bytes (25.94 MB). SHA-256: `d10ebed9c8470bfb38abb538bcbb646eb4ed8844c08c473e746e8e151fcd93f7`.
- `hyner-0.7.1-sales-refinement-arm64-v8a.apk`: 27,841,431 bytes (27.84 MB). SHA-256: `cad3c1cfa554c23f0fb91fae86d068a79b59e50d95eb6f660e7cff908924842f`.
- `hyner-0.7.1-sales-refinement-x86_64.apk`: 29,421,368 bytes (29.42 MB). SHA-256: `d3b3286067f99efe5726812dd3408dce29f2c59749163a8c49515d75e176617e`.
- `hyner-0.7.1-sales-refinement-universal.apk`: 77,492,790 bytes (77.49 MB). SHA-256: `bfa349842bdeb3f1df96980609084c60910dcfd6476bd4ffafebb9d3f66644b1`.

All four APKs are version 0.7.1, version code 11, package `com.hyner.hyner`,
and retain the existing certificate. Split and universal APKs contain identical
Dart AOT libraries for each corresponding ABI and share the verified source
fingerprint. `flutter build web --release --no-pub` also completed successfully;
the web build was not deployed. Android dependency/plugin deprecation notices
remain in the build logs; no dependency upgrade was included.
