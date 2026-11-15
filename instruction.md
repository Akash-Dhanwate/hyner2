# Hyner Codebase Guide: What to Change and Where

This guide is a practical map of the Hyner source code for developers who want to change the app themselves. It describes the repository as it exists now. The app version in `pubspec.yaml` is **0.8.4+16**.

For a deeper architecture, database, security and feature audit, read [`docs/APP_MASTER_DOCUMENTATION.md`](docs/APP_MASTER_DOCUMENTATION.md). This file is the quicker “which file do I edit?” guide.

## 1. Start Here

The app is Flutter/Dart. The Android app starts in `lib/main.dart`, opens local/device or account services in `lib/app/bootstrap/bootstrap.dart`, then shows the business app in `lib/app/hyner_app.dart`. Screens are connected by `lib/app/routing/app_router.dart`.

There are two related QuickPrice entry paths:

- The main business workspace is the signed-in/local business app, with Inventory, Sales, Customers, Reports, Settings and other modules.
- QuickPrice is also available as a calculator workspace. Its saved calculators are called pricing profiles/rate cards in the code. The “Your calculators” list is `lib/features/pricing/presentation/rate_cards_screen.dart`.

When you are unsure where code lives, search by the text shown in the app or by a class/function name:

```sh
rg -n "Text shown in the app" lib
rg -n "SomeClassOrFunction" lib
```

## 2. Project Folder Map

```text
hyner2/
├── android/                 Android project, manifest, Kotlin host and Gradle build files
├── assets/                  App logo/branding and Manrope font
├── docs/                    Master architecture report, release notes and design captures
├── lib/                      Flutter/Dart application source
│   ├── app/                  App startup, dependency setup, routing and app-wide themes
│   ├── core/                 Shared storage, errors, widgets, notifications and helpers
│   └── features/             Screens and logic grouped by product feature
├── test/                     Unit, widget, repository, integration-style and visual tests
├── third_party/sqlite/       SQLite C source used by the native build
├── tool/                     Build, performance and artifact-verification scripts
├── web/                      Web bootstrap and icons
├── pubspec.yaml              Package name, app version, Dart constraints, dependencies/assets
├── pubspec.lock              Exact resolved package versions
├── analysis_options.yaml     Dart analyzer and lint rules
├── README.md                 Project overview and build/install notes
├── instruction.md            This file
└── docs/APP_MASTER_DOCUMENTATION.md  Full technical reference
```

Generated or machine-created files include `lib/core/storage/pricing_database.g.dart`, `.dart_tool/`, Android Gradle caches and `build/`. Do not hand-edit generated output. Edit its source/schema and use the project’s build tools when regeneration is required.

### `lib/app/`

| File/folder | What it controls | Change it when… |
|---|---|---|
| `lib/main.dart` | Process entry, startup and separate QuickPrice launcher | Changing how Flutter starts or opens the app |
| `lib/app/bootstrap/bootstrap.dart` | Creates real app services and loads startup preferences | Changing app initialization or service setup |
| `lib/app/bootstrap/app_dependencies.dart` | App-wide dependency/provider declarations and theme state | Adding or changing an app-level service/provider |
| `lib/app/hyner_app.dart` | Main `MaterialApp.router`, light/dark themes and router wiring | Changing app shell-level behavior |
| `lib/app/routing/app_router.dart` | URL/path routes and route-to-screen mapping | Adding a screen route or changing navigation paths |
| `lib/app/routing/workspace_navigation.dart` | Shared helper for opening workspace pages | Changing how feature pages are opened |
| `lib/app/theme/app_theme.dart` | Semantic Material theme construction | Changing shared colors, component styles or typography defaults |
| `lib/app/theme/theme_preset.dart` | Slate Blue, Sage Green, Warm Copper, Muted Violet tokens | Changing preset colors or adding a preset |
| `lib/app/theme/appearance_repository.dart` | Saved theme preset and light/dark preference | Changing appearance preference persistence |

### `lib/core/`

Shared code used by multiple features. Changes here can affect many screens.

| File/folder | What it contains | Change it when… |
|---|---|---|
| `lib/core/storage/local_business_database.dart` | Business database open/migrations | Changing the business database structure |
| `lib/core/storage/pricing_database.dart` | Drift pricing database open/migrations/guards | Changing pricing database structure or safeguards |
| `lib/core/storage/pricing.drift` | Pricing database table/index definitions | Adding/changing pricing tables or columns |
| `lib/core/storage/pricing_database.g.dart` | Generated Drift code | Do not edit directly; regenerate from Drift schema |
| `lib/core/storage/backup_service.dart` | Business backup and restore | Changing backup contents or restore behavior |
| `lib/core/errors/app_failure.dart` | Errors translated to user-facing messages | Changing shared error presentation |
| `lib/core/widgets/workspace_components.dart` | Reusable labels, hints, disclosures and workspace UI | Changing shared UI patterns used in multiple screens |
| `lib/core/widgets/page_content.dart` | Shared page spacing and content constraints | Changing common page layout |
| `lib/core/widgets/financial_amount.dart` | Consistent display-only money styling | Changing how amounts look (not how they are calculated) |
| `lib/core/widgets/document_action_button.dart` | Shared PDF/document action button appearance | Changing document action styling |
| `lib/core/images/` | Image editing and profile photo storage | Changing logo/profile photo editing or storage |
| `lib/core/notifications/` | Android/local notifications | Changing in-app notification behavior |

### `lib/features/`

Feature folders usually use these roles:

- `presentation/`: screens, dialogs and widgets. Change this for layout, labels, controls and screen interactions.
- `domain/`: app data models, validation, calculations and repository contracts. Change this for business rules or model definitions.
- `data/`: local database/API adapters and serialization. Change this for persistence or external-service behavior.
- `application/`: workflow coordination/use cases. Change this when a feature’s steps need to change across UI and data layers.

Not every feature has all four folders. Follow the structure already used in that feature.

| Feature folder | Contains |
|---|---|
| `lib/features/auth/` | Sign-in, session state, Firebase and local/device access |
| `lib/features/onboarding/` | Splash, welcome and first-use screens |
| `lib/features/workspace/` | Main workspace navigation and module catalog |
| `lib/features/dashboard/` | Home/dashboard summaries and entry points |
| `lib/features/inventory/` | Products, stock, product forms and inventory persistence |
| `lib/features/pricing/` | QuickPrice calculators, pricing rules, calculator products and estimates |
| `lib/features/sales/` | Bill creation/history/details, payments, PDFs and bill deletion |
| `lib/features/quotations/` | Quotation creation, saved quotation history and PDFs |
| `lib/features/customers/` | Customer list, details and purchase/sales history |
| `lib/features/purchases/` | Supplier purchases, details and returns |
| `lib/features/purchase_orders/` | Purchase order register |
| `lib/features/expenses/` | Operating expense records |
| `lib/features/accounting/` | Manual accounting register |
| `lib/features/reports/` | Business reports, charts and report PDF |
| `lib/features/settings/` | Bill preferences, payment settings, themes and settings persistence |
| `lib/features/profile/` | User profile details and photo |
| `lib/features/whatsapp/` | WhatsApp handoff/follow-up screens |

## 3. Common Changes: File-to-Task Lookup

| If you want to change… | Start with… | Also check… |
|---|---|---|
| A screen’s wording or layout | That feature’s `presentation/` screen | Related widget tests in `test/` |
| Add a page or change navigation | `lib/app/routing/app_router.dart` | `lib/features/workspace/presentation/module_catalog.dart`, workspace shell and navigation tests |
| Main drawer/sidebar modules | `lib/features/workspace/presentation/module_catalog.dart` | `workspace_shell.dart`, route file, navigation tests |
| App-wide colors or theme preset | `lib/app/theme/app_theme.dart`, `theme_preset.dart` | `theme_preset_picker.dart`, theme tests |
| Theme picker/settings | `lib/features/settings/presentation/settings_screen.dart`, `theme_preset_picker.dart` | `appearance_repository.dart`, bootstrap and theme tests |
| Shared spacing, hints or common buttons | `lib/core/widgets/workspace_components.dart` or the matching shared widget | All screens importing it, UI regression tests |
| Product fields or validation | `lib/features/inventory/domain/product.dart` | Product editor, inventory codec/repository, backup and product tests |
| Inventory screen or product entry form | `lib/features/inventory/presentation/inventory_screen.dart`, `product_editor_screen.dart` | Controller, repository, domain model and inventory tests |
| Stock calculations or movement rules | `lib/features/inventory/data/local_inventory_repository.dart` and `domain/` | Sales/purchases repositories, stock history and transaction tests |
| Sales bill entry form | `lib/features/sales/presentation/sale_editor_screen.dart` | `sale.dart`, sales controller/repository, inventory deduction tests |
| Saved bill history | `lib/features/sales/presentation/sales_screen.dart`, `bill_summary.dart` | `sales_controller.dart`, `sale_search.dart`, screen tests |
| Saved bill details, payment or contact edit | `lib/features/sales/presentation/sale_detail_screen.dart` | Contact/delete dialogs, repository methods and sales tests |
| Bill PDF layout/text/amount styling | `lib/features/sales/data/bill_pdf_service.dart` | `payment_settings.dart`, PDF tests and archived-PDF rules |
| Bill PDF save/share/print mechanics | `lib/features/sales/data/bill_pdf_actions.dart` | Android native handler and document-action tests |
| Bill appearance settings | `lib/features/settings/presentation/settings_screen.dart`, `bill_template_selector.dart` | `payment_settings.dart`, settings repository/controller and PDF preview tests |
| QuickPrice calculator screen | `lib/features/pricing/presentation/quickprice_screen.dart` | `calculator_session.dart`, calculator UI tests |
| Calculator list, rename or remove | `lib/features/pricing/presentation/rate_cards_screen.dart` | `local_universal_rate_card_repository.dart`, `rate_card.dart`, calculator management tests |
| Simple calculator setup/rates | `lib/features/pricing/presentation/simple_calculator_screen.dart` | `simple_calculator.dart`, product setup, repository and variety tests |
| Advanced pricing editor | `lib/features/pricing/presentation/rate_cards_screen.dart`, `rule_editors.dart` | `domain/universal/`, repository and pricing tests |
| Pricing formula or money rounding | `lib/features/pricing/domain/exact.dart`, `domain/universal/engine.dart`, `strategies.dart` | Pricing engine tests and bill/estimate snapshot tests |
| Product setup wizard | `lib/features/pricing/presentation/product_setup_screen.dart` | `application/product_setup.dart`, fields/rules and product setup tests |
| Estimate items or checkout handoff | `lib/features/pricing/application/estimate_builder.dart`, `presentation/estimate_screen.dart` | `quickprice_checkout_screen.dart`, sale seed, estimate/checkout tests |
| Quotation screen or PDF | `lib/features/quotations/presentation/quotation_screen.dart` | Quotation domain/repository and `bill_pdf_service.dart`, quotation tests |
| Reports or charts | `lib/features/reports/presentation/reports_screen.dart`, `report_charts.dart` | Report controller/repository/PDF, report tests |
| Customers and history | `lib/features/customers/presentation/` | Customer repository, sales history and customer tests |
| Purchases or supplier returns | `lib/features/purchases/presentation/` | `purchase.dart`, purchase repository, inventory stock and return tests |
| Profile details/photo | `lib/features/profile/presentation/profile_screen.dart` | `profile/data/`, image storage and profile tests |
| Login/session behavior | `lib/features/auth/presentation/session_controller.dart` | Auth repositories and route guards; test account switching/sign-out |
| Business database field/table | `lib/core/storage/local_business_database.dart` or feature repository | Migration, codec, backup/restore and migration tests |
| Pricing database field/table | `lib/core/storage/pricing.drift` and `pricing_database.dart` | Drift-generated code, schema version/migration and repository tests |
| APK version | `pubspec.yaml` (`version: name+buildNumber`) | Settings version label, README, docs and Android build verification |

## 4. How a Screen Usually Works

For a feature screen, trace it in this order:

1. **Route:** `lib/app/routing/app_router.dart` connects a path to a screen.
2. **Screen:** the feature’s `presentation/` folder displays controls and handles taps.
3. **Controller/application:** coordinates loading, state and workflow, if that feature has one.
4. **Domain:** validates data and defines the business operation/repository interface.
5. **Data repository:** reads/writes SQLite or calls an integration.
6. **UI refresh:** controller/provider reloads or updates state so the screen shows the result.
7. **Tests:** find the related test by screen/module name under `test/`.

Example: a sale created from QuickPrice starts in the calculator/estimate flow, reaches `lib/features/sales/presentation/quickprice_checkout_screen.dart`, becomes a `SaleDraft`, then is written by the sales repository. Inventory and sales storage coordinate stock and the saved sale. PDF layout is a separate path in `bill_pdf_service.dart`.

## 5. Calculator Rename and Delete Behavior

The list of saved calculators is **Your calculators**, in `lib/features/pricing/presentation/rate_cards_screen.dart`.

- **Rename calculator:** use the row’s options menu. It saves the changed name using the existing revision-checked `saveDraft` method. Products, prices, currency, and setup data remain part of that calculator. It does not automatically publish new rates.
- **Delete calculator:** confirm the prompt. The UI uses the repository’s existing archive operation. The calculator disappears from active lists and cannot be used for new calculations. Published history and existing bill/estimate snapshots are retained. This avoids unsafe deletion of immutable pricing/audit records.
- **Change how rates are edited:** `lib/features/pricing/presentation/simple_calculator_screen.dart` for the simpler editor; `rate_cards_screen.dart` and `rule_editors.dart` for advanced rules.

If you change these actions, keep permission checks and revision checks in the repository. Do not replace archive with direct SQL deletes: pricing history and audit rows have protected relationships.

## 6. Database and Business-Rule Cautions

- The app has separate local business and pricing databases. Business records use `lib/core/storage/local_business_database.dart` and repositories in feature `data/` folders. Pricing tables are defined in `lib/core/storage/pricing.drift` and opened by `pricing_database.dart`.
- A schema change needs a migration path for users who already have data. Add migration tests. Never only edit a generated `.g.dart` file.
- Bills and estimates keep snapshots. Changing a product or calculator later should not rewrite a saved bill/estimate.
- Money is stored/calculated using integer minor units and exact pricing types. Do not replace formulas with floating-point math or change rounding while doing a visual edit.
- Sales changes can affect stock, payments, customer history, reports, reminders, backups and PDFs. Trace all of those before changing behavior.
- The calculator Delete menu archives rather than physically erasing data. This protects published history and audit relationships.
- Authentication/session and account-scope behavior is spread across `lib/features/auth/`, app routing and repository scope checks. Be careful not to show one account’s pending form or data after an account switch.
- Never put real passwords, API keys, tokens, signing keys or customer records into source control or documentation.

## 7. How to Make and Check a Change

1. Search the visible text or function name with `rg` to locate the real source.
2. Read the screen and the class/repository it calls before editing.
3. Change the narrowest correct layer. A visual change usually belongs in `presentation/`; a formula belongs in `domain/`; persistence belongs in `data/` and may require a migration.
4. Preserve existing routes, permissions, calculations and snapshots unless the requested feature explicitly changes them.
5. Format Dart files you changed:

   ```sh
   dart format lib/path/to/changed_file.dart test/path/to/changed_test.dart
   ```

6. Analyze and run the focused existing tests:

   ```sh
   flutter analyze --no-pub
   flutter test --no-pub test/path/to/relevant_test.dart
   ```

7. Check whitespace and inspect the diff:

   ```sh
   git diff --check
   git status --short
   git diff
   ```

For an Android release artifact, update `pubspec.yaml` with a new build number and use the existing verified build script:

```sh
python3 tool/build_android.py --label my-change --no-pub
```

The script writes verified APKs under `build/app/outputs/flutter-apk/` and a checksum report under `build/optimization/`. Use `--format universal` if a single APK that carries all configured ABIs is needed. `build/` files are generated outputs; do not hand-edit them.

## 8. Tests and Useful Commands

Tests are organized by concern under `test/`:

- `test/business/`: business repositories, navigation, billing, inventory and UI behavior.
- `test/*_test.dart`: pricing, calculators, quotations, profile/media, reporting and app-level behavior.
- `test/fixtures/`: fixed schema/PDF inputs.
- `test/support/` and `test/business/support/`: reusable fakes and fixtures.
- `test/performance/`: performance recorder and resource checks.

Examples:

```sh
flutter analyze --no-pub
flutter test --no-pub test/calculator_management_test.dart
flutter test --no-pub test/business/sales_screen_test.dart
flutter test --no-pub test/business/bill_pdf_service_test.dart
```

Do not install new dependencies just to make a small UI change. Check `pubspec.yaml` first and prefer existing Flutter/Material components.

## 9. Platform and Configuration Folders

- `android/`: Android manifest, Kotlin `MainActivity`, Gradle wrapper and app build settings. Change only for platform behavior or build setup, then rebuild/test Android.
- `web/`: web bootstrapping and icons. The browser QuickPrice preview is transient; successful web compilation does not mean every local database feature works in a browser.
- `assets/branding/`: app branding assets. `assets/fonts/`: Manrope font registration is in `pubspec.yaml`.
- `third_party/sqlite/`: upstream SQLite C source. Avoid changing it unless deliberately updating that dependency/source.
- `tool/`: `build_android.py` and related verification/analysis scripts. Prefer these scripts over manually copying or renaming build products.

## 10. Best First Reading Order

If you are new to this app, read:

1. `README.md` for the current app and build instructions.
2. `lib/main.dart`, `lib/app/bootstrap/bootstrap.dart` and `lib/app/hyner_app.dart` for startup.
3. `lib/app/routing/app_router.dart` and `lib/features/workspace/presentation/module_catalog.dart` for navigation.
4. The feature’s `presentation/` screen, then its controller/application and domain/data files.
5. The related tests under `test/`.
6. `docs/APP_MASTER_DOCUMENTATION.md` for schema, data flow, security, known limitations and architecture details.

Always inspect the current implementation before editing. This guide is a map, not a substitute for reading the code around the feature you are changing.
