# Hyner Android 0.6.0+8 — QuickPrice estimate to bill

## Counter workflow

1. Open a saved QuickPrice calculator and choose a product or variety.
2. Enter its measurements and quantity, then tap **Add to Estimate**.
3. Change the product, size or quantity for the next row and add it. Compatible
   measurements remain entered when switching products.
4. Open **View estimate** for independent rows and one grand total. Use item
   options to edit, duplicate or remove; long-press a row to reorder on Android.
5. **Copy estimate** and **Share estimate** include the whole customer-safe list.
6. **Continue to Sales** carries all rows into the existing billing workflow.
   Enter/select the customer, mobile and optional address, choose full payment,
   advance or pay later, then **Generate bill**. Items do not need re-entry.

Checkout keeps the item review collapsed and puts customer fields first. Optional
additional inventory products remain available. Back to QuickPrice keeps the
estimate; the confirmation applies only to unsaved checkout/contact details.

A seller who began in public QuickPrice can explicitly choose the local device
workspace and continue without a Firebase account. Account workspaces keep their
own estimates and pricing data.

## Price and transaction integrity

Each estimate row has an independent stable ID, including repeated varieties
with different dimensions. It snapshots the product, approved/calculated rule
version, engine version, exact input state, chosen quantity, rate definition,
billable dimensions, components, discounts, taxes and final amount. Editing one
row does not rewrite another row or the merchant's rates. Editing uses current
rates, which the calculator shows before the seller updates that row.

The active estimate persists in the existing business-scoped QuickPrice storage.
There is one active project draft per pricing workspace, bounded to 100 rows and
one MiB. A converted estimate remains readable until a new estimate is started;
the finalized bill keeps its own independent snapshots permanently. Invalid or
foreign persisted drafts are reported instead of silently discarded.

The same existing sales repository creates the bill and records payments. The
estimate's stable operation ID prevents duplicate confirmed bills after repeated
taps, navigation or a lost response. Re-entering checkout after conversion opens
that bill. A failed post-commit draft-status update cannot turn a committed bill
into a failed transaction. Returning to the estimate through either Back or
router navigation releases its pending checkout state.

Financial snapshots are replay-validated using exact arithmetic. Final line
amounts carry through unchanged, including order charges, discounts, tax and
paisa/cents that cannot divide evenly across quantity. The displayed per-item
allocation uses exact half-up rounding and is labeled approximate when needed;
the saved line amount remains authoritative. Invoice totals and payment balances
use that exact amount. Tax and included discounts remain explainable.

Share text and PDFs allowlist product/specification/selling fields. They do not
render rule administration, alternate rates, supplier information, purchase costs,
profit margins or internal notes. Exempt zero-tax rows omit tax clutter. Measured
and billable sizes are distinguished where the configured policy changes them.

## Inventory and existing data

QuickPrice categories are not inventory SKUs. Custom measured estimate items do
not create fake catalog products, deduct finished stock, or consume raw materials.
No inventory product is required to calculate, save an estimate or bill those
custom items. Automatic matching by product name is intentionally absent.

Actual inventory products can be added explicitly in Sales. They retain normal
availability checks and exactly-once stock movements. Mixed bill validation and
writes remain one SQLite transaction. Reports use exact quoted line totals and
exclude unknown custom costs from gross-profit estimates instead of assuming a
zero purchase cost.

Business schema 10 and QuickPrice schema 4 remain unchanged; the update uses
existing draft storage and extends saved bill-line snapshots additively. Legacy
bills without pricing snapshots continue using their original quantity × unit
price contract. Business backups include finalized bill snapshots and archived
Duplicate PDFs. Active QuickPrice estimates and rate cards still live in the
separate QuickPrice database and are not included in business backups.

No Firebase database setup or rule deployment is needed for the local workflow.
The existing authentication, customer linking, UPI, Original-only WhatsApp PDF,
local Duplicate archive, settings, purchase and inventory modules remain in use.
Install as an update to the same package to retain local data.

## Verification

Final automated results and artifact metadata are recorded below after checks.
Screenshots and rendered invoice fixtures are under
`build/verification/ux-0.6.0/`; logs are under `build/verification/`.

The six-row fixture totals INR 37,675.00 across different dimensions, varieties
and quantities. The fractional-tax fixture retains INR 3.40 for quantity 3 while
the approximate displayed unit price is INR 1.13. Both are checked through the
bill/PDF pipeline. Customer invoice and Duplicate documents remain separate.

Physical Android installation, real WhatsApp/printing/document-provider handoffs
and affordable-device latency are unmeasured without an attached phone. Build,
host, browser and visual tests do not substitute for these device checks.

Comparison mode, dedicated customer presentation, automatic quotation conversion,
explicit QuickPrice-to-catalog linking, multi-device cloud synchronization,
backend staff authorization and paid entitlement workflows remain separate work.

Verified on the final source:

- Static analysis: no issues.
- Formatting: 190 files checked, no changes.
- Host regression suite: **666 passed**, three opt-in visual tests skipped.
- Chrome calculator, estimate/checkout and pricing snapshot suite: **57 passed**.
- Opt-in estimate visual/PDF export: **1 passed**. Six screenshots inspected,
  including 320 dp dark theme with 1.7x text. Separate widget checks exercise 2x
  text, customer details, payment modes and item review expansion.
- All generated PDF pages rendered and inspected: six-row Original, compact
  Duplicate and the fractional-tax Original. The final monetary/signature block
  stays together when paginated.
- SQLite tests passed for custom and mixed-stock bills, retry/idempotency,
  missing/corrupt bill distinctions, backup/restore, report totals, exact payments,
  draft persistence across restarts and business isolation.

The fixture rates are test-only and are never loaded into merchant workspaces.
Build metadata will be recorded below once release builds finish.

## Release artifact

- Android release build: passed; APK signature scheme v2 verified.
- Web release build and Wasm compatibility dry run: passed.
- APK: `build/app/outputs/flutter-apk/hyner-0.6.0.apk`.
- Size: **77,082,390 bytes**.
- Package: `com.hyner.hyner`, version **0.6.0**, version code **8**.
- Android API **24+**. ARM64, ARMv7 and x86_64 app, Flutter and SQLite
  libraries verified in the package.
- Same development signer as the previous APK; install as an update.
- SHA-256: `976a17532fe941cb453075abc5e39ec56ee99225d5ffa47a01ee83b4c3de9790`.

Build toolchain emitted non-blocking future Kotlin Gradle and SDK XML version
warnings. This build completed successfully. No Firebase rules or remote business
records were changed.
