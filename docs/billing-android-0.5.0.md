# Hyner Android 0.5.0+7 — customer records and bill documents

This update builds on the existing business workspace and QuickPrice. It does
not change approved pricing rules, historical bill prices, or the authoritative
sale/stock transaction semantics.

## Customer checkout and history

A confirmed sale now saves a new contact and links its bill in the same local
SQLite transaction. If stock validation fails, customer and stock writes roll
back together. A retry uses the original bill operation ID and cannot create a
second sale or deduct stock twice.

Matching uses the normalized full name and mobile number together: case and
spacing in names, and formatting characters in mobile numbers, are ignored.
Different people sharing a phone are not merged by phone alone. Country prefixes
are not guessed. Existing customer IDs, notes, addresses and marketing consent
are preserved. Checkout never opts a new customer into product marketing.

New IDs include a readable name/mobile reference and an identity suffix. Search
accepts name, mobile, customer ID and added date. The customer account shows its
added date, bill count, sold units and totals billed/paid/due separately for each
currency. Its dated bills include saved product names and specifications, with a
link to open each bill. History uses bill snapshots rather than current catalog
prices or descriptions.

## Original and Duplicate PDFs

WhatsApp, Print original and Save PDF generate only the **Original**. They never
append the owner's document. WhatsApp opens a sharing draft/recipient chooser;
the seller still chooses the recipient and sends it.

A separate A5 **Duplicate**, clearly marked in the corner/header and footer, is
archived locally when the saved bill is opened. It is a first-write snapshot;
reopening the bill cannot silently replace it. Save duplicate PDF exports that
archive as an ordinary PDF. A failed archive shows a retry action while the sale
itself remains saved. Archives remain available through local backup/restore.

PDFs include customer name, mobile, optional address, readable customer ID, bill
reference/date, item quantities, specifications and units, unit selling prices,
line amounts, total, paid amount and balance. They exclude purchase costs and
profit margins. Amounts retain two decimal places; there is no additional
whole-rupee rounding. Calculated bill component measurements are copied onto the
saved line, excluding internal pricing inputs such as costs, margins and rates.
Manual product specifications remain available for all product types.

Specification rows can paginate even when a single product has many long
parameters. Optional damaged legacy branding images do not prevent bill export.
The Duplicate uses smaller embedded images and lossless zlib storage only when
compression saves bytes. The final two-line fixture is **6,556 bytes** as a PDF
and **3,735 bytes** in the archive: **43.0% less storage**, with an exact byte-for-
byte PDF round trip. Savings vary by document; incompressible files remain raw.

## Business branding

Open **Settings → Bill appearance**, or **Bill appearance** on a saved bill.
Configure business name, phone, address, optional tax ID, footer, header alignment
and size, logo and signature. The signature appears below the totals. A business
name can be saved without configuring UPI, and saving UPI later preserves the
latest branding.

Image picking supports PNG, JPEG and WebP with previews and removal/replacement.
Input size and pixel counts are bounded, images are resized without upscaling,
and invalid or animated files are rejected. The shared image-codec path works on
Android and Flutter web. Async configuration and customer operations check the
account again before writing or updating the screen.

## Storage and installation

Business schema **10** adds indexed contact identity matching and the per-bill
compressed document archive. Upgrades preserve existing customer IDs and all
prices, payments, product parameters and stock records. Usable contact details
on previously unlinked bills are connected automatically in bounded pages;
anonymous or malformed historical contacts stay unlinked and unchanged. Legacy
duplicate customer IDs and their existing links are preserved.

Schema 8/9 business backups and the earlier backup format remain supported.
Restore is atomic and validates archive size, encoding, checksum and bill
references. Compressed decoding is bounded during inflation at five MiB. Each
account keeps a separate database; another account's backup is rejected.

Install the new APK over the current `com.hyner.hyner` app; do not uninstall or
clear its data. No Firebase database changes are needed for these local features.
Settings → Business backup remains the transfer mechanism. QuickPrice records
are still stored separately and are not included in business backups.

## Verification

- Host regression suite: **607 passed**, two opt-in visual tests skipped.
- Chrome calculator, configuration and customer UI suite: **48 passed**.
- Opt-in visual export: **1 passed**; calculator, saved-bill actions, business
  branding and customer product history inspected.
- Original and Duplicate PDFs rendered and inspected, including sizes, decimal
  totals and signature position. Separate tests cover 100-line invoices, long
  single-item specifications and malformed optional images.
- Real SQLite tests cover migration from older schemas, contact linking,
  transaction rollback, idempotency, isolation, archive integrity and backup
  recovery. Final archive fixture was rechecked after rendering.
- Static analysis: no issues. Formatting check and build details recorded below.

Verification logs and screenshots are under `build/verification/`, with visual
artifacts in `build/verification/ux-0.5.0/`.

No physical Android phone or emulator is connected. Actual installation,
WhatsApp/WhatsApp Business attachment handoff, printing, document-provider saves
and affordable-phone performance remain unmeasured. Successful host/browser
checks and builds do not constitute those device tests.

Automatic cloud business sync, backend staff permissions, paid entitlement
workflows, advanced QuickPrice project estimates/comparison/customer presentation
and automatic QuickPrice-to-quotation/bill conversion remain separate pending
work. This update preserves the current QuickPrice calculator and business
register features; it does not claim all flagship acceptance criteria are done.

## Release artifact

- Android release build: passed; APK signature scheme v2 verified.
- Web release build and Wasm compatibility dry run: passed.
- Final formatting check: 178 files, no changes. Static analysis: no issues.
- APK: `build/app/outputs/flutter-apk/hyner-0.5.0.apk`.
- Size: **76,476,086 bytes**.
- Package: `com.hyner.hyner`, version **0.5.0**, version code **7**.
- Android API **24+**; ARM64, ARMv7 and x86_64 app, Flutter and SQLite
  native libraries verified in the APK.
- Same development signer as the previous APK; this is an in-place update.
- SHA-256: `5acd78c8e06ed11396ba8077fa0aef91c5f0c271a94cf0419c5c7594c909c1e8`.

The plugin toolchain emits a future Kotlin Gradle migration warning; this build
completed successfully. No Firebase rules, remote records or services were
changed by the build.
