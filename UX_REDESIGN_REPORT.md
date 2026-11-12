# Hyner UI/UX redesign

## Phase A — Product and UX audit

Inspected 31 screen source files, the workspace shell/router, shared widgets and both themes, with related forms, menus/dialogs, repositories/controllers and existing workflow tests. Product: an offline-first merchant workspace for product/stock registers, measured pricing, estimates, customer billing and manually verified payments. The door, panel and hardware workflows and INR defaults indicate shop owners and trade sellers are a primary audience; other templates/currencies remain supported. This is repository evidence, not user research.

Core journeys:

- Configure product rates/varieties → enter measurements and quantity → agree customer rate → add independent estimate items → choose customer/payment → generate bill → verify payment → share/print.
- Add inventory → receive supplier purchases → bill stock → inspect adjustments/returns/reorder state.
- Open customer → inspect all past bills and balances → start another bill or prepare a follow-up.
- Review business totals → inspect charts/expenses/products → export report.
- Configure UPI/business branding → export/restore records; manage local/account identity and WhatsApp recipients.

Screen inventory (all existing capabilities must remain):

- Entry: splash, welcome, sign-in/account setup; profile view/edit/password/photo dialogs.
- Workspace: Home/dashboard; responsive shell, drawer/More menu and desktop navigation.
- Pricing: workspace loader; QuickPrice; simple calculator setup/edit; rate-card catalogue/profile editor/history/publish; advanced product-setup wizard/sample preview; multi-item estimate/edit/duplicate/reorder; checkout loader into Sales.
- Inventory: catalogue/search/filter; product detail/adjust/archive/restore/history; product editor with metadata and measured-price formula.
- Sales: stock/estimate bill builder/product picker/measurement/customer dialogs; bill history; outstanding balances; saved bill, QR/manual confirmation/reminders/documents.
- Customers: directory/search/add/edit dialog; customer account and full bill/product history.
- Supply: purchase register/supplier dialog; purchase editor; purchase detail/payment/return dialog; purchase-order register/editor.
- Finance: expenses/register/date/category/dialog; accounting register/entry dialog; quotations register/editor; reports/currency/period/charts/PDF.
- Communication: WhatsApp composition/product/link, customer opt-in/recipient selection, manual sending queue and due follow-ups.
- Settings: backup/restore confirmation, theme/notifications/UPI; separate bill appearance (business identity, colours/layout/logo/signature); account/profile.

Source inventory with per-file control counts/labels: `build/ux-redesign/before/screen-inventory.json`. Counts are source declarations, not simultaneous runtime controls.

Priorities and evidence:

1. **P0 — Coherent shared system:** `app/theme/app_theme.dart` and `pricing/presentation/pricing_widgets.dart` implement divergent palettes/fonts/controls. Shared input styling is missing in the business theme. Unify identity and readable control states before per-screen changes.
2. **P0 — Main selling flow:** `quickprice_screen.dart` repeats breakdown access and gives Add, View estimate, Copy and Share a large persistent area. `sale_editor_screen.dart` repeats section titles/help and shows reset-price actions even before rates change. Retain direct primary actions and current negotiation/variety controls; demote context actions.
3. **P1 — Product entry:** `product_editor_screen.dart` places category, custom parameter tools and formula setup before cost/selling price/stock. Group the required commercial fields first; keep measured-price enablement discoverable and specifications optional. Do not reset controllers or skip validation when a section closes.
4. **P1 — Home and reports:** home duplicates large report charts; three forced metric columns can become difficult with enlarged text. Reports present every profit/purchase detail in one stream with separate full-width filter fields. Preserve data and chart access, prioritize summaries and make optional analysis explicit.
5. **P1 — Bill/settings:** saved-bill document actions have five peer buttons; branding has seven colour editors inline. Keep payment, WhatsApp and printing direct. Group less frequent document/branding options.
6. **P1 — Navigation:** `workspace_shell.dart` repeats the full module list in drawer/More/desktop. Group tools by merchant task, preserve routes/Back/account isolation and the four current primary destinations. Avoid new routing state or navigation layers.
7. **P1 — Accessibility:** custom chart painters lack data semantics; fixed metric/chart/value rows need adaptive layouts at large text sizes. Maintain 48 logical-pixel targets, labelled controls, visible focus, error text and light/dark contrast; do not claim WCAG conformance solely from widget tests.
8. **P2 — Secondary registers:** accounting, expenses, quotations, orders, suppliers and customer dialogs share repetitive typography/form chrome. Improve their common visual system without rewriting data handlers. Existing lazy registers, local persistence, confirmation dialogs and retry/uncertain-save protection are strengths to retain.

## Phase B — Design direction

Visual thesis: a precise merchant's ledger, using warm paper-like neutrals, deep green action colour and charcoal type; calm, practical and legible during a customer conversation.

Content plan: identify the task → show the current record/amount → ask for required input → one clear next action → confirmation and continuation. No marketing hero, stock photography, decorative charts or onboarding slides are appropriate for these working surfaces.

Interaction thesis: retain short navigation fades; use native section expansion for optional controls with reduced-motion support; use clear save/validation feedback rather than entrance effects. No ornamental animations or new dependencies.

- One Manrope family; 14/16-pixel body text, restrained 20–28-pixel headings, tabular amounts. No forced text-scale clamp.
- Spacing rhythm 4/8/12/16/24/32; 16-pixel narrow-mobile gutters, larger desktop gutters, bounded reading/forms widths.
- Radius 8–12 for interactive surfaces; flat page sections and fine dividers instead of a card around every datum. One filled primary action, quiet secondary actions.
- Deep green links/actions, neutral surfaces and distinct error/due states with explicit text/icons; matching dark mode.
- Frequent actions stay direct: calculator variety, customer rate, Add to Estimate, view estimate, new bill, manual payment verification, WhatsApp/print. Advanced policy, measurements configuration, metadata, typography and duplicates use clear optional sections.
- Phone layout stacks at large text sizes; desktop uses additional columns only when controls remain comfortably readable. Keep keyboard/safe-area behavior and Back protections.

Implementation and verified before/after evidence will be recorded below. No engagement, task-time or performance improvements are assumed before measurement.

## Phase C — Implemented experience

Release **0.7.0+10**, 12 November 2026. The existing Flutter/Riverpod/GoRouter structure is retained. There are no application dependency, database-schema, API, permission, authentication or pricing-engine changes in this redesign. Earlier billing/history/WhatsApp/measurement/colour and variety/negotiated-rate functionality remains included.

### Screen-by-screen outcome

- **Splash and launch:** existing Hyner mark geometry retained; Android day/night splash colours and adaptive/legacy icons now match the green interface. No added startup animation.
- **Welcome:** removed the large decorative patterned panel and generic promotional copy. A short task explanation leads to local use, sign-in/account creation or QuickPrice. One filled action when local mode is offered; no onboarding carousel.
- **Sign-in/account setup:** shared typography, fields, focus, errors and button system. Google/email/local access, reset-password behavior, configuration gates and profile synchronization remain intact.
- **Home:** direct QuickPrice and Build a bill actions; all-time scope stated explicitly. Customer/sale/revenue facts use open layout instead of three cards. Balance due and useful next destinations are visible. Charts remain one tap away under Activity details. Empty plots no longer dominate the first screen. At large text sizes the facts stack; desktop actions share a row.
- **Workspace shell:** four existing primary destinations remain. Desktop/drawer pin Home, Inventory, Sales and Reports; secondary tools are grouped under Sell & collect, Stock & suppliers, and Money & reports. More omits redundant copies of the primary tabs. Desktop uses its sidebar without a second hamburger drawer. Outstanding-payment pages now correctly highlight Sales.
- **QuickPrice workspace loader:** existing loading/retry and account-isolation behavior retained, using the shared visual system.
- **QuickPrice calculator:** selected variety precedes dimensions; a single-product chip becomes plain context. Measurement units, dimensions, quantity and Customer rate stay directly editable. The result and Add to Estimate have the strongest weight. Copy, breakdown and share are quiet secondary actions; breakdown has one entry rather than different duplicated placements. Large-text secondary actions stack to avoid broken words. Estimate access remains available from the toolbar and beside the item action for convenient continuation.
- **Simple calculator setup/edit:** consistent field and action language, varieties/rates remain visible. Existing-rate edits now require confirmation before Back discards them; Keep editing preserves entered values. New-setup draft persistence and publication/version semantics are unchanged.
- **Calculator catalogue/rate cards:** new shared theme, control styling and rounded-interaction scale. Create, edit, archive, publish, permissions and immutable version history retain their existing interactions.
- **Advanced product setup/sample preview:** existing staged editor and progressive settings remain; consistent labels, borders, contrast and controls. No strategy, tax, formula, unit conversion or publishing policy was rewritten.
- **Estimate:** shared typography, amount hierarchy and controls. Add, edit, duplicate, reorder, copy/share and checkout retain their existing saved-snapshot behavior.
- **QuickPrice checkout loader:** existing account checks, stale/converted-estimate behavior and loading/error guidance retained.
- **Inventory catalogue:** shared theme, clear button hierarchy and readable field states. Existing active/archive controls, prefix search mode, refresh, pagination and workspace-scope guidance are preserved.
- **Add/edit inventory product:** required identity and commercial fields appear first. Cost and selling price pair on wide screens and stack on phones/large text. Category and custom parameters are grouped under Product specifications; existing specifications start open. Measured-price enablement remains directly discoverable. Removed unnecessary counters and the nested measured-pricing card; added a label to the measurement-delete icon. Controllers, validation, uncertain-save protection and stock logic are preserved.
- **Inventory product detail:** shared surface/typography/control improvements. Adjust, archive/restore, stock history and revision behavior remain unchanged.
- **Build a bill:** price and quantity remain direct. Inventory-price reset appears when a price actually differs or is invalid. Optional per-line specification editing is grouped under Item details, with values retained while folded. Measured-price editing stays direct. For ordinary stock bills, customer details now precede payment choices. Removed the duplicate large title beneath the standalone app bar. Calculations, contact requirements, payment modes, stock deductions and retry identity are unchanged.
- **Sales history:** shared list/form/button system; New bill, outstanding payments, refresh, paging and saved records preserved.
- **Outstanding payments:** shared typography and visual hierarchy; existing due amounts and bill links preserved.
- **Saved bill:** payment comes before document actions. WhatsApp PDF, Print original and Save PDF remain direct. Duplicate export and Bill appearance live under More document options. Money facts stack before large values collide with labels. Manual verification, UPI amounts, reminders, archive immutability, retry and corrupt-archive fallback remain unchanged.
- **Customer directory:** unified fields, dialogs, touch/focus styling and readable list content. Existing search/reference/date matching, contact editing and opt-in preferences remain intact.
- **Customer account/history:** shared theme throughout contact details, totals and every past bill/product. No history was hidden, limited or replaced by only the recent bill.
- **Purchases register/suppliers:** shared list/dialog styling; record purchase, supplier entry and paid/unpaid records preserved.
- **Purchase editor:** shared form field/keyboard/action treatment; supplier, item costs, quantities and saved stock effects preserved.
- **Purchase detail/returns:** shared controls/amount styling; payment confirmations, return quantities/reason and stock/cost effects preserved.
- **Expenses:** shared field/dialog/list styling; amount/date/category validation, delete confirmation and save feedback preserved.
- **Accounting:** shared theme and form controls; existing manual entry and tax/category semantics preserved.
- **Quotations:** shared register/editor visual system; saved amount/tax/state behavior preserved.
- **Purchase orders:** shared register/editor visual system; supplier, scope, expected total and history preserved.
- **Reports:** filters pair on wide screens and stack on phones/large text; selector overflow fixed. Financial facts stack before amounts collide. Charts have less container chrome, smaller legends, semantic amounts and an expandable text view of activity. Profit/stock and purchase/expense details use optional sections. Monthly wording is used only for the monthly selection; other scopes say Period highlights / Download report PDF. Error state now offers Retry reports. No query or reporting calculation changed.
- **WhatsApp updates:** unified fields, recipients, action and feedback styling. Existing product/general composition, link, opt-in switches, selected recipients, manual send queue and scheduled follow-ups remain intact. No messages were sent during the work.
- **Settings:** UPI/bill setup comes first. App appearance, notifications and backup use clear optional groups; profile remains reachable. Existing persistence and restore confirmation are unchanged.
- **Bill appearance:** business name/phone/address stay visible. Additional details, seven section colours/title/layout controls, and logo/signature tools form three optional groups. Invalid colour edits reopen the typography section. Phone input uses the phone keyboard/autofill hint. Image-provider stability and saved branding values are preserved when sections close. The standard phone capture now fits the primary fields, optional-section entries and Save together.
- **Profile:** unified form, text and control styling; account photo/password linking, profile save, cleanup, sign-out and error handling remain unchanged.

Secondary registers deliberately reuse the common system rather than receiving unrelated new workflows. This preserves their established behavior and keeps the redesign focused on the busiest selling, inventory, reporting and settings paths.

### Shared components and design rules

- `HynerTheme.build`: one palette/font system for business, launcher fallback and standalone QuickPrice. Distinct dark surfaces; explicit input focus/error borders; 48-pixel minimum icon/text/outlined targets and 52-pixel primary buttons; restrained 10-pixel control corners and flat cards where existing cards remain appropriate.
- `DisclosureSection`: state retained for editable forms, validation-triggered reopening, short expansion honoring reduced motion. Stateless analytics opt out of retained child state so closed sections are not built unnecessarily.
- `ResponsivePair`: pairs wide controls/actions and stacks them at narrow widths or enlarged text.
- `RecordFact`: labels, supporting detail and amounts align on wider screens and stack on constrained screens.
- `PageContent`: bounded width and narrow-phone gutters; existing sliver registers remain lazy.
- `DetailHint`: the requested red eye help control is retained, with theme-aware error red and descriptive tooltip. Important errors remain visible rather than being relegated to optional help.
- `MessageLine`: calculator validation messages are live regions. Totals retain their existing live announcement.
- Existing pricing/theme helpers delegate to the same system. No second UI framework or font package was introduced.
- Brand PNGs are rendered from the existing mark geometry by `tool/render_brand_icons.py` using Python's standard library, with no external rendering dependency. App icon, splash and web metadata match the app identity.

### Trade-offs

Home adds useful direct billing/balance/report destinations while removing dominant default chart panels; the objective is fewer detours, not a blanket reduction in control count. Optional specifications, backup/preferences, typography and duplicate export now need a deliberate expansion. These are clearly labelled and stay within one extra disclosure step. Frequent variety selection, negotiated rates, estimate continuation, payment verification, WhatsApp and original printing remain direct. At very large text sizes the screen necessarily requires more scrolling; no font scaling is suppressed to make a screenshot fit.

## Phase D — Verification and refinements

**698 Flutter tests passed; four opt-in tests skipped.** The full suite includes the prior business/pricing/storage tests and eight additional redesign checks. Final font-loaded visual/calc verification passed seven tests separately. Static analysis reports **No issues found**; formatting and `git diff --check` pass. The Python helper compiles. Android release builds for ARM32, ARM64, x86_64 and universal pass; web release compilation and its Wasm dry run pass.

New checks cover:

- Light/dark text-token contrast at least 4.5:1, and input-boundary contrast at least 3:1 for the tested theme pairs.
- Common theme identity across entry points; folded form input retained; validation reopens a folded section.
- Unsaved rate edits protected by Back, with the saved rate unchanged until Save.
- Inventory specification state retained across folding.
- Chart semantic labels containing the numerical amounts; optional financial details remain reachable.
- Report period changes update the wording; desktop and phone layouts remain functional.
- Flutter Android tap-target and labelled-target guidelines on the captured Home surface. This is a scoped automated check, not certification of every screen.

Existing tests continue to cover varieties/negotiation, exact arithmetic, immutable quotes, estimate-to-sale transfer, payments, stock, customer history, font colours, offline persistence, backup/restore, account changes, archive behavior, permissions/navigation and error/retry states. Large-text tests exercise 280/320/390/760 widths and scaling up to 3x in selected scenarios; showcase captures cover 390×844, 1024×900 and dark 320×740 at 1.8x. Existing calculator tests include keyboard-inset layouts.

Review exposed and corrected a Reports selector overflow, large-font footer word wrapping, a frequently used desktop destination slipping below the initial menu area, and the possibility of a specification section reopening because its initial state was incorrectly derived from live edits. Existing tests were updated to open intentional optional sections; their saved-data, financial and archive assertions were retained.

### Accessibility basis and limits

The contrast checks follow the [W3C contrast criterion](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum). Native target defaults follow [Flutter's accessibility guidance](https://docs.flutter.dev/ui/accessibility). WCAG 2.2 AA's [web target-size criterion](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum) has a 24-CSS-pixel minimum with exceptions; it should not be confused with this app's more generous 48-logical-pixel native target policy.

Controls retain standard Flutter keyboard focus/semantics, labelled icons and text errors; charts also expose amounts without relying on colour. Explicit route transitions and optional sections respect reduced motion, including reverse navigation and theme changes. This is not a full WCAG audit or a claim of legal conformance: TalkBack/VoiceOver, browser keyboard traversal, high-contrast/colour-vision simulations and physical-device interaction still require manual assessment.

### Performance and preservation

No decorative effects, polling, chart library, new font or production dependency was added. Existing lazy sliver lists remain; stateless optional chart/detail sections are built on demand. Form sections retain their existing controller state rather than rebuilding drafts on every expansion. Existing bounded branding caches and archive generation remain untouched.

The pre-redesign diff was recorded in `build/ux-redesign/before/prior-work.diff`, with UI source snapshots under `before/source/`. A comparison confirmed that all seven previously modified non-UI domain/application/storage patch sections stayed unchanged. Database version remains 12. No database/API/security migration, remote deployment, merchant data access or message sending occurred.

These structural safeguards are not measured FPS/RAM/battery results. No physical Android device is connected; no claim is made about engagement, task-completion speed, peak memory, 60 FPS or energy savings. Release file size remains approximately 27.78 MB for ARM64. Actual device profiling remains necessary, particularly on 2 GB Android hardware.

## Before/after evidence

These are rendered Flutter-test screenshots with real app fonts and synthetic records, not photographs of an installed phone. The paired captures use the same fixtures and viewport. The filled dashboard/report/tablet captures use a separately labelled synthetic fixture; their numbers are not merchant performance measurements.

- Home: [before](docs/ux-redesign/before/dashboard-390.png) → [after](docs/ux-redesign/after/dashboard-390.png).
- Calculator: [before](docs/ux-redesign/before/calculator-390.png) → [after](docs/ux-redesign/after/calculator-390.png).
- Large-text dark calculator: [before](docs/ux-redesign/before/calculator-dark-large-320.png) → [after](docs/ux-redesign/after/calculator-dark-large-320.png).
- Bill appearance: [before](docs/ux-redesign/before/bill-appearance-390.png) → [after](docs/ux-redesign/after/bill-appearance-390.png); [current Save view](docs/ux-redesign/after/bill-appearance-bottom-390.png).
- Saved bill/payment: [before](docs/ux-redesign/before/saved-bill-actions.png) → [after](docs/ux-redesign/after/saved-bill-actions.png).
- Additional current screens: [inventory entry](docs/ux-redesign/after/product-entry-390.png), [reports](docs/ux-redesign/after/reports-390.png), [More](docs/ux-redesign/after/more-390.png), [desktop Home](docs/ux-redesign/after/home-1024.png), [desktop reports](docs/ux-redesign/after/reports-1024.png), [large-text dark reports](docs/ux-redesign/after/reports-dark-large-320.png).

The images are copied under `docs/ux-redesign/` so they survive build cleanup. Raw captures and logs remain under `build/ux-redesign/`.

## Release artifacts and reproducibility

Package `com.hyner.hyner`, **0.7.0**, version code **10**, min SDK 24 / target SDK 36. Existing signing certificate retained: `abdc309aa793adb3e76226fd8a6a980a00bdc393022c95ef8956c8a8d10a8517`. No installation or publication was performed. Update using the matching ABI without uninstalling or clearing records; universal is the compatibility fallback.

- [ARM64 APK](build/app/outputs/flutter-apk/hyner-0.7.0-ux-redesign-arm64-v8a.apk): **27,775,899 bytes / 27.78 decimal MB**.
- [ARM32 APK](build/app/outputs/flutter-apk/hyner-0.7.0-ux-redesign-armeabi-v7a.apk): **25,889,765 bytes / 25.89 MB**.
- [x86_64 APK](build/app/outputs/flutter-apk/hyner-0.7.0-ux-redesign-x86_64.apk): **29,355,836 bytes / 29.36 MB**.
- [Universal APK](build/app/outputs/flutter-apk/hyner-0.7.0-ux-redesign-universal.apk): **77,312,570 bytes / 77.31 MB**.

SHA-256 sidecars accompany each APK. Package, version, ABI/library coverage, ZIP integrity, signature continuity, size budgets and absence of opt-in profiling are verified. All artifacts match the current Dart source hash; the new UI labels are verified inside every shipping ABI. These are APK file sizes, not installed footprint or Play download size. No new AAB/store upload was requested or performed.

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
dart format --output=none --set-exit-if-changed lib test
python3 tool/render_brand_icons.py
python3 tool/build_android.py --format split --no-pub --label ux-redesign
python3 tool/build_android.py --format universal --no-pub --label ux-redesign
flutter build web --release --no-pub
```

For synthetic screenshot capture, set `HYNER_TEST_FONT_DIR` to Flutter's `bin/cache/artifacts/material_fonts`, then run `test/ux_redesign_visual_test.dart` with `CAPTURE_REDESIGN=true` and `test/ux_visual_verification_test.dart` with `CAPTURE_UX_QA=true`.

Evidence: `all-tests.log`, `final-analyze.log`, `final-format.log`, `final-capture.log`, `selling-flow-tests.log`, `build-{split,universal}.log`, `web-build.log`, `final-artifacts.json` under `build/ux-redesign/`, plus `build/optimization/artifacts-ux-redesign-{split,universal}.json`.

## Technical change inventory

Presentation changes: `lib/app/theme/app_theme.dart`, `lib/app/hyner_app.dart`, `lib/app/routing/app_router.dart`; shared `lib/core/widgets/{page_content,workspace_components,hyner_mark}.dart`; dashboard, workspace shell, onboarding welcome, inventory editor, pricing widgets/calculator/simple setup, sales editor/detail, reports/charts and settings presentation files. Domain calculations, repositories, controllers and storage behavior were not changed by this redesign.

Assets/configuration: existing mark SVG/PNG, Android colour/vector/launcher resources, web icons/manifest/title, and version labels in `pubspec.yaml`/Settings. The manifest is no longer locked to portrait when installed as a web app; web workflow limitations remain unchanged.

Verification changes: new `test/ux_redesign_test.dart`, `test/ux_redesign_visual_test.dart`, `test/support/design_fixture.dart`; updated dashboard, calculator, navigation, saved-bill and branding tests for intentional hierarchy changes. `tool/render_brand_icons.py` supplies repeatable icon rendering. README and this report document the release.

Previous work is preserved in the working tree; no commit/push was performed. For a UI rollback, restore the captured pre-redesign UI files, restore the previous branding resources using the recorded repository baseline, retain schema-12 and signing compatibility, and build a reviewed forward version. Do not reset unrelated prior changes, force an application-data downgrade or uninstall as a rollback shortcut.

## Remaining limitations and useful next measurements

- Physical Android install/update, TalkBack, native sharing/printing/pickers, low-memory lifecycle, keyboard behavior on real IMEs, large business datasets and frame/memory/energy traces remain unverified.
- Web compiles and responsive widgets are exercised, but browser assistive technology/keyboard testing and the pre-existing business-workflow parity gaps remain. No iOS host project is present.
- Secondary registers, advanced policy editors and several account/modal editing workflows deliberately retain their established interaction patterns; they received the shared visual system rather than a new workflow. Their density and cancel/back expectations should be checked with actual sellers before adding further disclosure or steps.
- Home's all-time aggregate/customer loads and long customer histories remain architectural opportunities from the earlier optimization audit. This UI task did not silently implement deferred data projections, pagination or auth/cache changes.
- Translated labels, RTL layouts and long international product names require further content testing. No accessibility or business research outcome is assumed from English synthetic fixtures.
- Recommended usability comparison: run the same measured-door order on 0.6.1 and 0.7.0, including variety switching, negotiated rate, two estimate items, customer details, partial payment and PDF handoff. Observe completion time, taps, corrected input errors, failed discoveries and any lost-input incidents. Separately ask users to find duplicate export, bill colours, product specifications and backup. These are proposed measures, not collected results.
