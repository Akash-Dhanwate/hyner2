# QuickPrice quotations, PDF styles and image editing — 0.8.0+12

The existing app logo and palette are unchanged. This build includes the
0.7.1 sales/report refinements, calculator varieties and negotiated rates.

## Using quotations

1. Add the products, sizes, varieties and quantities to the QuickPrice estimate.
2. Select **Quotation PDF** in the estimate, or **Quotation** in the calculator
   where Copy price used to be. With an empty estimate, Quotation first saves
   the completed current calculation as an item. Otherwise it uses the saved
   estimate items; add or update any unfinished item before quoting it.
3. Enter the customer name, mobile and optional address, then generate the quote.
4. Preview, download, copy the PDF on Android, or open WhatsApp with the PDF.

Quotations keep the exact saved prices, dimensions, quantities, varieties, tax
and discounts. They do not create a sale, change stock, record a payment, modify
customer profiles or mark the calculator estimate as converted. Repeated PDF
actions do not create additional quotations. Returning to QuickPrice preserves
the estimate for further work or eventual checkout to Sales.

**Saved quotations** is available from QuickPrice's folder button. The More
menu no longer contains Quotations. Existing records, the existing manual-entry
workflow and existing deep links remain available through quotation history.
History reads 30 compact records per page; full item snapshots are loaded only
when opening a detailed quote. Legacy plain-text descriptions remain readable.

## Documents and appearance

- Quotations show **QUOTATION**, business details, customer contact/address,
  customer reference, date/time, item specifications, quantity, unit prices and
  total. Paid/balance/payment-status sections are omitted.
- Newly generated bills and quotations omit repeated Original/Duplicate badges,
  the large bill reference and the separate BILL heading above the customer.
  Date/time is larger and follows the customer block/ID. A small reference
  remains for matching the document to its saved record.
- Bill appearance offers **Classic** (right-aligned business header), **Studio**
  (centered header and shaded table heading), and **Ledger** (left header and
  ruled table). Three previews allow selection; **Preview selected PDF** opens
  the full document using current unsaved form values. Save bill details commits
  the style. Existing per-section font colours, title size, business details,
  logo, signature and footer controls remain available.
- The same chosen style applies to bills and quotations. Existing immutable
  archived duplicate PDFs retain their original bytes; newly generated customer
  copies use the updated design. Compact duplicate generation remains available.

## Photos, logos and signatures

Uploading an image opens a real crop editor before the form accepts it. It offers
rotation, drag/pinch positioning, a zoom slider, accessible directional controls,
reset and an explicit Use this image action. Profiles use a circular preview and
export a square crop; logos/signatures offer Square, Wide and Full image options.
The signature's wide preview matches the proportions of its document placement.
Transparent image pixels remain transparent in exported PNGs.

Profile forms show an image preview and crop/replace/remove controls instead of
an image URL/path field. New profile crops are persisted when Save profile is
selected. Logo/signature crops are committed by Save bill details. Existing image
URLs remain supported for displaying previously saved profile photos. Existing
logos and signatures can be cropped again without choosing a new file.

Images retain the existing input limits: PNG/JPEG/WebP, up to 8 MB and 24 MP.
Decoded editing images are bounded to 1,024 pixels on the long edge; profile
exports are at most 512 pixels. Codecs, temporary rendered images and page-owned
branding caches are disposed. Account changes hide and dismiss image/PDF routes
from the prior workspace.

## Storage and compatibility

No production dependency, database table, database schema version or backup
format changed. Detailed quotation snapshots use a versioned payload in the
existing quotations table. Reads check item snapshots and stored totals; retries
use the same saved reference and reject attempts to replace different content.
Schema remains 12 and export format remains 10. SQL pagination does not require
SQLite JSON functions, preserving older Android compatibility.

Android Copy PDF places a content URI on the clipboard, rather than copying text
or displaying a private file path. Pasting depends on the receiving application
supporting PDF/file clipboard data. Download and sharing remain alternatives.
WhatsApp/WhatsApp Business receive a PDF attachment and a best-effort customer
number hint. WhatsApp controls recipient selection and the final Send action;
the application does not silently send messages or claim delivery. The system
share sheet remains the fallback if targeted sharing is unavailable.

The crop UI and PDF generation compile for web. New cropped profile-photo
persistence uses native app storage on Android/iOS; browser upload persistence
is not implemented in this release. Existing web HTTPS profile images remain
readable. Android file clipboard support is intentionally not offered on other
platforms. No iOS build or hardware certification was performed.

## Verification

Evidence is in `build/quotation-release/`:

- `analyze-final.log`: no issues.
- `all-tests-final.log`: **730 Flutter tests passed**, four existing opt-in tests
  skipped. Calculator, checkout, inventory, payment, account and earlier sales
  refinement tests are included.
- Real SQLite tests verify a ten-item quotation round-trips without any writes
  to sales, stock movements, customers or bill documents; retries are idempotent;
  backup/restore retains exact items; cross-account reads fail; corrupt totals
  and conflicting references are rejected. A 65-record fixture verifies compact
  paginated history with no duplicate/missing references.
- Integrated widget tests create a ten-item quotation, validate customer input,
  preserve input when canceling navigation, download/copy/share its PDF, reopen
  its history and confirm the calculator remains unconverted.
- Image tests verify actual rotated/cropped pixels and dimensions, small-screen
  large-text behavior in both themes, upload-to-profile/signature persistence,
  previews without visible paths, and account changes during editing.
- Three bill styles and three quotation styles were generated and rendered with
  Poppler. All fixture pages were inspected; long-invoice tests also exercise
  every style and both original/compact variants. Existing PDF font limitations
  for unsupported writing systems remain; no new font package was introduced.
- `screens/` contains inspected real-font quotation, profile and appearance
  captures at 390dp and 320dp/1.8x text. The host has no Printing raster plugin,
  so style-card captures show the supported schematic fallback; the generated
  PDF files were independently rendered to inspect the real layouts.
- Android release APKs and web release built successfully. Source fingerprint,
  ABI, package/version, certificate continuity, archive integrity, size limits
  and absence of profiling markers are checked by `tool/build_android.py`.

No Android device was connected. Real WhatsApp recipient handling, final send,
clipboard compatibility with other applications, system file pickers, printing,
installation/update and physical-device performance still need phone testing.
Build/plugin deprecation notices remain; dependency migrations were out of scope.

## Update and recovery

Install the matching APK over the existing Hyner application. Do not uninstall
or clear application data. The package and existing signing identity are retained.
ARM64 suits most current phones; ARM32 and universal variants are also provided.

Starting source and prior-work snapshots are in `build/quotation-release/before/`.
For a code rollback, retain the new quotation reader/metadata adapter so saved
snapshot-based quotations remain readable, and build with a higher Android
version code. Do not delete quotation rows or rewrite archived duplicate PDFs.
Export a backup before manual recovery. Older APK installation is not a safe
in-place downgrade strategy.

API references used for the Android handoff design:
[Android content-URI clipboard](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste),
[secure file sharing](https://developer.android.com/training/secure-file-sharing),
[WhatsApp click-to-chat behavior](https://faq.whatsapp.com/5913398998672934).
