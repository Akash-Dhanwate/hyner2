# Hyner Premium Product Experience Report

**Review date:** 2026-11-14  
**Repository:** `/Users/akash/hyner2`  
**Branch / base commit:** `test2` / `ee06c23`  
**Scope:** Continue the existing UI polish incrementally. This report distinguishes previous staged UI work from the onboarding, Help, and PDF filename changes in this pass. The repository already had staged edits before this pass; they were preserved. No database schema or financial rules were changed by the onboarding and filename work described here.

## 1. Screens audited

Reviewed the current application documentation and UI report, routing, welcome/sign-in, workspace navigation, dashboard, pricing and calculator management, estimates/quotations, sales editor/history/detail, inventory/editor/detail, customers, purchases, expenses, reports, settings, profile, document actions, Android manifest/activity/build configuration, and relevant tests.

The existing UI report (`HYNER_UI_UX_REDESIGN_REPORT.md`) records the earlier navigation and screen hierarchy changes. This pass adds a first-use guide and searchable task help. It does not constitute a full visual rebuild of every feature screen.

## 2. Original design problems and language

Prior source review found that common routes were not equally discoverable, Home had more information than a new shopkeeper needed at first glance, calculator setup competed with the calculation task, and the locations for settings/edit help were not self-evident. The earlier UI report documents the five-destination navigation, grouped More destinations, more direct Home summary, and bill/inventory hierarchy changes.

This pass shortens Welcome to “Welcome to Hyner” and “Set up your shop and start managing your business.” Setup labels use direct task names. Help rows use task language. It does not broadly rewrite all application copy; many feature screens still need a separate copy and accessibility review.

## 3. Navigation and first-time user experience

Existing mobile navigation remains Home, Price, Bill, Stock, and More, with secondary modules retained in More. A “How do I...?” entry is now in More and Settings. “Take a tour” opens the short setup checklist at `/getting-started`.

On an empty local workspace, Home offers “Get started” and “Explore on my own.” “Get started” opens the checklist. The checklist links to existing Business/Bill Settings, Add Product, Sales, QuickPrice, and Backup/Settings routes. It is skippable; each task checkbox records guide progress only. It does not create sample records.

The guide checks the current workspace's existing tables (`products`, `sales`, `customers`, `settings`, `purchases`, `operating_expenses`, `quotations`) before offering a first-time prompt. A workspace with existing business records is not classified as new simply because the guide was added. Guide state is stored as workspace-keyed SharedPreferences booleans; it does not contain business data. Existing account/profile records are not copied or migrated.

## 4. Contextual guidance and Help

Added `/help`, a searchable “How do I...?” list with destinations for:

- Change shop details and bill appearance.
- Change a product price and adjust stock.
- Edit calculator rates or rename a calculator.
- Download a bill.
- Record a payment.
- Change the app theme.
- Create a backup.

The list opens existing screens; its descriptions direct the user to the next actual selection/action. It does not fabricate edit capabilities or change their authorization rules.

**Not implemented in this pass:** anchored coach marks that highlight controls inside Inventory, product detail, QuickPrice, rate editing, and bill detail. The Help list is a practical alternative entry point, but it does not satisfy the full requested contextual overlay experience. Reopening the whole tour is supported from More and Settings; acknowledgement of individual contextual hints does not exist yet.

## 5. Theme, typography, buttons, motion

Existing four color presets, appearance mode, semantic tokens, and financial typography remain in place. No second theme engine or theme migration was introduced. No new animation system was introduced. Existing screen-specific controls remain in their original interaction implementation. A full inventory of focus/pressed/disabled states and reduced-motion behavior remains unverified.

## 6. Bill PDF filename logic

Added one Dart helper, `lib/features/sales/data/bill_pdf_filename.dart`, for exported bill filenames. It trims and sanitizes customer names, strips path/control/reserved characters, preserves readable Unicode, normalizes a mobile to digits, caps name length, uses a short bill reference when name or phone is missing, distinguishes duplicate copies, and always appends `.pdf`. If the merchant disables mobile inclusion or a valid phone is unavailable, the short bill reference distinguishes otherwise similar exports. The optional preference is workspace-scoped and defaults to the requested `CustomerName_MobileNumber.pdf` convention.

The preference is exposed in Settings as “Include customer mobile in bill filenames” with a privacy explanation. Original and duplicate bill save use the helper. Share/WhatsApp handoff and print use the same bill name. Android native filename validation is centralized in `PdfFilename.sanitize`; the native save flow still uses Android's document picker. The quotation helper uses `Quotation_CustomerName_shortReference.pdf` and omits phone numbers.

The naming change affects only user-visible names. It does not alter internal sale IDs, references, saved snapshots, bill bytes, payments, or stock. It does not rewrite archived files. Android's document picker handles an existing destination name by offering a collision-safe alternate; physical picker/share behavior has not been tested on a device in this pass.

## 7. Changed files in this pass

| File | Change |
|---|---|
| `lib/features/onboarding/data/onboarding_preferences.dart` | Workspace-scoped local guide completion and task state. |
| `lib/features/onboarding/presentation/first_time_user_guide_screen.dart` | Empty-workspace prompt and optional setup checklist linked to current features. |
| `lib/features/onboarding/presentation/help_screen.dart` | Searchable guide to existing tasks and screens. |
| `lib/features/onboarding/presentation/welcome_screen.dart` | Short, direct welcome copy. |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | First-use prompt on Home. |
| `lib/features/workspace/presentation/workspace_shell.dart` | More entry point for Help and tour. |
| `lib/features/settings/presentation/settings_screen.dart` | Help/tour destination and phone-in-filename setting. |
| `lib/app/routing/app_router.dart` | `/getting-started` and `/help` routes. |
| `lib/features/sales/data/bill_pdf_filename.dart` | Central bill/quotation name generation and local preference. |
| `lib/features/sales/presentation/sale_detail_screen.dart` | Apply bill name to print, share/WhatsApp, original and duplicate saves. |
| `lib/features/quotations/presentation/quotation_screen.dart` | Apply separate quotation name. |
| `android/app/src/main/kotlin/com/hyner/hyner/PdfFilename.kt` | Native filename sanitization and PDF extension validation. |
| `android/app/src/main/kotlin/com/hyner/hyner/MainActivity.kt` | Apply safe filename to native save/share handoff. |
| `test/onboarding/onboarding_preferences_test.dart` | Workspace scope, existing-data suppression, and skippable prompt tests. |
| `test/sales/bill_pdf_filename_test.dart` | Filename behavior tests. |
| `android/app/src/test/kotlin/com/hyner/hyner/PdfFilenameTest.kt` | Android filename safety tests. |

The current working tree also contains other staged changes from work predating this pass; see the master documentation and existing UI report for those. They were not reverted or flattened into this change summary.

## 8. Tests and visual verification

- `flutter analyze --no-pub`: **passed**, no issues found.
- Focused Flutter suite for bill filenames, onboarding, navigation, dashboard/inventory layout, and existing UI redesign tests: **all passed** on the final run (47 passed, 1 skipped; Flutter reports the skipped widget case as `~1`).
- Android `:app:testDebugUnitTest`: **passed**, 8 native tests, including filename sanitization tests. Gradle/Kotlin/notification API deprecation warnings remain.
- `python3 tool/build_android.py --format split --no-pub --label premium-ui`: **passed**; generated ABI-specific release APKs and SHA-256 sidecars. The arm64 APK is 28.3 MB, package `com.hyner.hyner`, version `0.8.4` / code `16`, target SDK 36 / min SDK 24. `apksigner verify` succeeded. These artifacts use the current debug signing configuration and are for sideload testing, not Play publication. The build tool verified package/ABI metadata and checksums; no device install was performed.
- `git diff --check`: passed after removing two trailing spaces from the prior `docs/HYNER_UI_UX_REDESIGN_REPORT.md` header. The existing staged/index version remains untouched; no staging or commit was performed.
- Screenshot/device verification: **not run**. This environment did not perform a physical Android install, TalkBack review, Android document-picker test, print test, WhatsApp handoff, or reduced-motion device test.

## 9. Performance and accessibility

The guide uses existing Flutter widgets and local preference reads; it adds no package, network request, polling loop, background service, or business database table. The first-use check performs bounded `SELECT 1 ... LIMIT 1` queries on the current workspace tables. It runs when the dashboard prompt is built and is an area to measure on low-end devices if startup profiling shows delay. Onboarding preferences store only booleans.

Large text, TalkBack, focus traversal, coach-mark geometry, and narrow-device visual screenshots were not fully verified for the new guide. A guide route can be opened through normal navigation; small-screen and orientation behavior still needs device review.

## 10. Feature closure

### Feature: First-time setup guide

**Purpose:** Help a genuinely empty workspace find existing setup and daily tasks.  
**User can:** Start, skip, explore directly, mark setup tasks, open existing business/product/calculator/bill/backup screens, and revisit from More or Settings.  
**User cannot:** Have sample business records created or receive automatic cloud sync through Google sign-in.  
**Files:** Onboarding preference, prompt, checklist, Help, routing, Home, More, Settings, Welcome, tests (listed above).  
**Database changes:** None.  
**Integrations:** Existing product editor, business settings, QuickPrice, Sales, and backup screen.  
**Tests passed:** Empty-versus-existing local data logic, scoped state, skip prompt, navigation suite.  
**Tests not run:** Physical-device new-install/upgrade path and accessibility device pass.  
**Known limitations:** No anchored coach marks; setup task completion is user-marked rather than inferred from business events.  
**Final status:** **PARTIAL** (core optional guide works; contextual coaching is outstanding).

### Feature: Readable bill PDF names

**Purpose:** Make bill exports recognizable without exposing an internal UUID as the ordinary name.  
**User can:** Save, share, WhatsApp-handoff, or print using a customer-oriented name; opt out of the mobile number.  
**User cannot:** Change a bill's internal ID or historical document contents through this setting.  
**Files:** Central Dart helper, sale/quotation UI calls, settings toggle, Kotlin sanitizer/bridge, tests.  
**Database changes:** None; preference stored locally.  
**Integrations:** Bill PDF action bridge, Android create-document/share, quote export.  
**Tests passed:** Dart formatting/sanitization/fallback/duplicate/quote naming and Android helper unit tests.  
**Tests not run:** Real Android filename chooser, third-party share-target behavior, multiple-bill overwrite interaction.  
**Known limitations:** External apps may choose how to display an incoming shared attachment name. Android document providers may add their own duplicate suffix.  
**Final status:** **PARTIAL** (name generation and unit coverage complete; device export paths not verified).

## 11. Remaining recommendations

1. Add anchored, dismissible guidance for controls only after device-size and accessibility geometry tests are available.
2. Run a clean-install and app-upgrade walkthrough on a designated Android device with existing synthetic data.
3. Verify PDF save, duplicate export collision handling, print, WhatsApp, and generic Android shares on device.
4. Capture screenshots at compact, standard, large-text, light, and dark configurations. No screenshots are claimed as evidence here.
5. Continue the remaining screen-by-screen copy, touch-target, focus, and reduced-motion review before calling the complete redesign done.

## 12. Calculator product visibility in Inventory (follow-up)

The advanced and simple calculator product setups now offer Inventory linking. Each configured base-rate variety maps to a distinct Inventory product with the variety in its name, calculator selling rate, and optional per-variety purchase cost. A product without varieties maps to one Inventory product. New records default to 100 units and low-stock threshold 10. No measured-to-piece conversion or pricing formula change was introduced.

When Inventory opens, it scans active calculator drafts and adds unlinked varieties. Opening a calculator's rate-card editor also retries the sync. A matching exact-name Inventory item is reused; calculator rates and saved costs update its item details while on-hand stock is preserved. Duplicate names, archived matches, and currency mismatches require review. A previous single-SKU calculator link is reused for the first variety; additional variants receive the configured 100-unit starting quantity and alert threshold 10, so merchants should verify actual quantities. A saved stock-linked draft must still go through the existing Preview & publish flow for new bills to use its link. Existing published versions and saved bills are unchanged. A sync failure leaves Inventory usable and displays a retry message. Automatic draft sync runs only against the local Inventory repository.

`CalculatorInventoryLinker` uses a deterministic inventory SKU and opening-movement ID so a retry across the separate pricing and business databases does not repeat the opening quantity. Changes to an already linked product update its Inventory name, cost, selling price, and threshold while preserving current quantity. Removing a calculator product does not delete or archive its Inventory product.

Files: `lib/features/pricing/application/calculator_inventory_link.dart`, `lib/features/pricing/application/pricing_workspace_provider.dart`, `lib/features/pricing/application/product_setup.dart`, `lib/features/pricing/presentation/product_setup_screen.dart`, `lib/features/pricing/presentation/rate_cards_screen.dart`, `lib/features/inventory/presentation/inventory_controller.dart`, `lib/features/inventory/presentation/inventory_screen.dart`, and `test/business/calculator_inventory_link_test.dart`. The quotation flow test expectation now checks the separate readable quotation filename convention.

Verification for this follow-up: `flutter analyze --no-pub` passed and a focused regression suite passed 68 tests, including per-variety prices, estimate SKU persistence, variant-only stock deduction, retry idempotency, and the rename/search case. Split APKs were built at `build/app/outputs/flutter-apk/hyner-0.8.4-variety-inventory-{arm64-v8a,armeabi-v7a,x86_64}.apk`; arm64 is 28,317,911 bytes with SHA-256 `ec450340a3c04c1268809d41416d90f16947ffdd97ce2b01cf6a9258b2a57b85`. `apksigner verify` passed. The artifacts are debug-signed for sideload testing. Physical device install and notification delivery remain unverified.
