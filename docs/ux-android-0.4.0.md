# Hyner Android 0.4.0+6 — counter workflow refinement

## Calculator

The default rate setup is one form: choose a template, enter product names and
selling rates, save and use. It no longer requires editing an input schema,
advancing through a pricing wizard, entering a sample size, then separately
publishing. Door templates use height/width in inches and selling rates per ft².
Other templates retain suitable area/length/weight/package/piece methods.

Tax is off for new simple calculators unless the owner enables it in Optional
settings. No percentage or selling rate is invented. New simple calculations
round final money half-up to currency minor units. Existing rates retain their
approved tax, dimensions, discounts, accessories and billing policies when the
simple rate editor is used. The full advanced builder remains reachable through
calculator options for merchants who need it.

Saving activates a new immutable published version. Earlier versions remain
unchanged. Editor metadata is updated alongside changed base rates so opening
the advanced builder cannot accidentally restore an old base rate. Interrupted
new setup text is saved locally and can be reopened.

Saved calculators appear in the calculator management list and as selectable
chips when more than one exists. Reopening QuickPrice restores the selected
calculator, compatible measurements and quantity. Edit selling rates updates the
saved profile; Change price for this calculation is a clearly marked temporary
base-rate override. A new product or published rule version clears that override.

The shared length selector offers inches, feet, mm, cm and metres where allowed.
Use the same unit is initially selected; unchecking it exposes separate unit
selectors. Unit changes convert physical values instead of reinterpreting digits.
Repeating converted values are marked approximately in the display; the exact
finite source measurement still drives the price until the user edits it.
Unit state, exact source measurements and calculator inputs survive supported
navigation/restarts. No server request is used for ordinary recalculation.

## Dashboard and inventory

Customers, Sales and Revenue occupy three equal columns in one row. Values wrap
inside their columns for enlarged accessibility text. Revenue/expense and payment
charts remain below; the duplicated business-module list was removed. Navigation
retains those tools, and the prominent QuickPrice shortcut remains.

Inventory refreshes on entry and when returning from product creation. Search and
pagination now use consistent SQLite sort/case behavior, and SQL prefix wildcards
are treated literally. Empty search/archive results have distinct messages and a
clear-filter action. Device/account scope is shown explicitly; optional older
cloud import failures have per-account notices and an explicit retry path.
Records are not copied between unrelated accounts or fabricated to fill a list.
QuickPrice configurations do not automatically manufacture stock records.

## Sales, contacts and PDFs

Products come first. Customer selection/contact entry is at the end. New contact
entry requires name and a valid mobile number; address is optional. An existing
customer missing a mobile can supply it for this bill without rewriting old
invoices or silently changing the directory. Customer/contact/address snapshots
are stored with the sale. Database schema 8→9 adds address fields and preserves
historical anonymous bills, stock movements and totals; older backups remain
supported.

The empty-bill Advance crash was caused by reading the first product's currency
when the product list was empty. The form now guards that state and keeps
Generate bill disabled until products exist.

The saved bill offers WhatsApp PDF, Print copies and Save PDF near the top.
Sharing targets installed WhatsApp / WhatsApp Business, with a system-share
fallback. It opens an attachment draft/recipient picker, not an automatic send.
Save PDF uses Android's document picker and URI permissions, without a broad
storage permission. Customer and seller copies show the saved contact/address
and exact bill total. Retrying/canceling any document action cannot create a
second sale or stock movement.

## Verification

Final results and APK digest are recorded below after the build. Automated host
checks are distinct from physical Android installation, WhatsApp handoff,
printing and real-device latency. No attached physical phone is available here.
The feature is still local-first; cloud sync and automatic QuickPrice estimate
conversion into transactions remain outside this release.

Verified results on the final source:

- Flutter analysis: no issues.
- Native-host regression suite: **551 passed**, two opt-in visual tests skipped.
- Chrome calculator and workspace suite: **55 passed**.
- Opt-in UX visual/PDF export: **1 passed**; setup, calculator, 320 dp dark
  enlarged-text layout, dashboard and saved-bill controls inspected.
- Rendered bill PDF: two A4 copies; customer name/mobile/address and INR 6300.00
  totals verified in both. Visual output is in `build/verification/ux-0.4.0/`.
- Android APK build and signature verification passed.
- APK: `build/app/outputs/flutter-apk/hyner-0.4.0.apk`, 76,050,078 bytes.
- Package `com.hyner.hyner`, version code 6, Android API 24+. ARM64, ARMv7,
  x86_64 app/Flutter/SQLite libraries verified.
- Same development signer as the previous APK; update in place.
- SHA-256: `ae869bbfc91ef5a78f37508d3a0d1901ca0005f203929af3b40e86d5457ee941`.
- Physical Android runtime, actual WhatsApp/printing/document-provider handoffs
  and phone performance remain unmeasured; no phone was connected.
- Final web release build, Wasm compatibility dry run and formatting check passed.
