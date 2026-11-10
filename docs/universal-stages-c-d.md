# Universal QuickPrice — Stages C and D

Build: 0.2.0+4. Package: `com.hyner.hyner`. Engine: `universal-1`.

## Implemented

The Android entry point is a real calculator, replacing the development shell.
A fresh installation starts with **Create calculator** and never invents prices.
The three-step product setup flow supports all ten domain strategy types: unit,
area, length, weight, volume, packaging, size bands, quantity tiers, components and
safe custom arithmetic. Industry structures include doors, glass, plywood, pipes,
steel, tiles and general hardware. Rates and tax treatment require owner entry.

Owners can define typed input fields and conditional visibility, permitted units,
rate selectors, minimums, billable increments, wastage, component extras, discounts
and product-specific package conversions. Arithmetic uses the existing typed AST
and exact engine, never executable merchant code. Preview and publication use the
same calculation code. Publishing requires valid previews and an explicit rate
and tax confirmation; published versions remain immutable. Draft editing,
deactivation by archiving, and version metadata/history use Stage B repositories.

Publishing now returns through the configuration routes directly to QuickPrice
and selects the published calculator. This fixes the prior navigation gap where
publishing left the user in the editor. Ordinary calculator entry never waits for
Firebase SDK initialization. An unavailable database shows a retry state without
discarding saved records. No device-specific startup freeze has been reproduced.

The calculator renders controls from the selected product schema, preserves
compatible measurements and quantity across product changes, and recalculates
locally. Missing required data or invalid dimensions removes the final price.
Quantity cannot be stepped below one. Mixed feet/inches input normalizes exactly.
Explicit unit selection applies the selected unit to the entered number; the UI
states this behavior. Pricing policy warnings and measured/billable differences
are available in the result/breakdown. Copy and Android sharing use an allowlisted
customer-safe string, not a serialized rule or private rate schedule.

## Persistence and authorization boundary

Drift schema v4 adds `pricing_device_workspace`, `pricing_workspace_values`, and
`pricing_local_tax_approvals`. The migration is additive. A generated local
business ID scopes all new local records; it is not a Firebase business ID.
Saved editor state and calculator inputs use serialized writes and canonical
JSON. SQL storage tests reopen the file and check workspace identity, draft
retention, tax approval isolation, published snapshots and prior records.

This is an explicitly local, single-owner workspace. It does not establish staff
authorization or cloud membership. The native Firebase configuration belongs to
the existing `hyner-541ad` project, but no Firestore synchronization or Firebase
sign-in is implemented. Web uses a clearly labeled temporary in-memory preview;
closing the page loses those changes.

The feature does not create a sale, move inventory or change existing invoices.
No quotation or billing subsystem has been duplicated.

## Design and interaction

Visual thesis: a quiet counter tool with a forest-green action color, clear
numeric typography and a strong total on a warm neutral surface.
Content plan: product selection, only relevant measurements, quantity, total;
technical detail stays in the expandable breakdown. Setup is Product → Pricing
→ Preview. Interaction uses platform page transitions, expanding configuration
sections and immediate selected-product feedback with Android haptics.

At 320 dp and normal text size, height and width share a row; enlarged text stacks
fields. Inputs and the total remain independently scrollable when the keyboard or
text scale reduces available height. Touch controls use Material sizing.

## Verification

- Static analysis: no issues.
- Native full suite: 346 passed; the optional screenshot exporter is skipped in
  the ordinary run and executed separately.
- Full first-use widget flow: create calculator, configure a real entered rate,
  preview, save, explicitly publish, reach QuickPrice and calculate the same total.
- Controller tests cover compatible switching, additional required fields,
  invalid inputs, quantity, mixed units, restoration and safe shared output.
- Calculator widget tests cover 320 dp light/dark themes, 2× text and keyboard insets.
- Financial/domain and additive migration regression tests remain included.

- Chrome targeted suite: 38 passed, including the complete fresh-start flow.
- Optional screenshot/benchmark run: 1 passed; all four renders inspected.
- Formatting: 51 Dart files checked, zero changes required.
- Web release: passed, including the Wasm compatibility dry run.
- Android release: passed, 59.3 MB reported by Flutter; version 0.2.0+4,
  minimum API 24, target API 36; ARM64, ARMv7 and x86_64 native libraries included.
- APK signature verification: passed, same development certificate as 0.1.0+3.
- Non-failing upstream warning: `firebase_core` still applies the Kotlin Gradle
  plugin; a future Flutter upgrade will require plugin migration. Dependencies
  were not upgraded during this change. Existing Drift multiple-test-database
  warnings did not fail the regression suite.

APK: `build/app/outputs/flutter-apk/hyner-quickprice-0.2.0.apk` (a named copy of
`app-release.apk`). SHA-256:
`e1940a24031b8bbc9f67c13f8fd7cfbd52bbfa1b3d7c99a9ce5ff89dfebfb74d`.

Actual Flutter render captures are under `build/verification/`. A warmed host-only
category-switch benchmark records 1,000 engine samples in
`build/verification/category-switch-host.json`. It excludes rendering and device
storage and is not evidence of Android frame latency or the under-10-second
first-use target. No Android device is attached; physical performance, platform
share-sheet behavior and installation/startup on the user's phone remain untested.

Latest macOS host calculation sample: median 40 µs, p95 84 µs, maximum 314 µs.
These numbers are not Android performance results.

## Remaining stages and release limits

Stages E–G remain: multi-item estimates, duplication/editing, comparison, protected
customer presentation, branded quotation output, catalog/billing/stock integration,
cloud authorization/sync, team approvals and paid entitlements. The local wizard
does not expose every future advanced policy (such as a dedicated stocked-size
picker, percentage add-ons or margin approval workflows). It is not a production
release of the complete specification.

The APK uses the existing development signing certificate so it can update the
previous development build. Production distribution needs managed release signing.
Do not uninstall to update; uninstalling clears local rates and drafts.
