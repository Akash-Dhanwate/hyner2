# HYNER UI/UX Redesign Report

**Date:** 2026-11-14
**Repository:** `/Users/akash/hyner2`
**Scope:** Presentation and navigation improvements to the existing Flutter application. No business calculations, database schemas, authentication rules, authorization rules, or repository implementations were changed.

## 1. Original design problems

The source audit found several places where an existing user could reach the right feature but had to infer its place in the app:

- Mobile navigation prioritized Home, Inventory, Sales, and Reports. QuickPrice was only a toolbar shortcut, and “More” did not list quotations or a direct bill-history entry.
- Home led with all-time business metrics, customer count, and charts. Today’s sales, current customer dues, common actions, and recent bills were not the first things presented.
- The calculator toolbar exposed several adjacent setup and information actions at the same level.
- The bill detail began with customer identity and showed its total and payment summary further down.
- Inventory rows had a separate outline around each record. The active filter was labeled “Active” even though it showed the full active catalogue.
- Customer directory rows repeated details better suited to customer detail.
- A user composing a bill had persistent navigation controls that could navigate away from the draft.

The code already had substantial useful behavior: four color presets, light/dark/system appearance, financial typography, searchable and paginated bill history, recent bills, dynamic QuickPrice inputs, estimate item actions, customer and payment validation, stock history, bill PDF actions, and confirmation/permission safeguards. These were retained.

## 2. New design principles

- Lead with the next common task and the financial information needed to act.
- Use five stable mobile destinations and grouped secondary navigation.
- Reduce repeated borders and equal-weight toolbar actions.
- Use the current semantic theme, typography, and financial display components.
- Keep destructive and financial behavior attached to its existing confirmation and data layer.
- Protect a bill draft from casual navigation while preserving guarded Back behavior.
- Adapt summary layouts to narrow widths and larger text instead of reducing text scaling.

## 3. Navigation changes

`lib/features/workspace/presentation/workspace_shell.dart` now maps mobile navigation to:

| Destination | Route | Purpose |
|---|---|---|
| Home | `/dashboard` | Today’s sales, current dues, attention items, recent bills |
| Price | `/quickprice` | Existing QuickPrice workflow |
| Bill | `/sales` | Existing new-bill workflow |
| Stock | `/inventory` | Existing catalogue and stock workflow |
| More | Modal navigation sheet | Secondary business, insight, communication, and preference routes |

More retains bill history, customers, purchases, expenses, quotations, purchase orders, accounting, reports, pending payments, WhatsApp updates, Settings, and Profile. The `/quickprice` route is still allowed by the existing public-access redirect and is now wrapped by the navigation shell. On wider layouts the existing side navigation remains in use.

While `/sales` is the active bill editor, the shell hides the persistent drawer, side navigation, and bottom bar. Its Back control uses the router’s pop path so the existing `SaleEditorScreen` `PopScope` can ask before discarding. A Saved bills shortcut remains in the shell. Profile and QuickPrice shortcuts retain their existing push behavior.

## 4. Screens redesigned

### Home

`lib/features/dashboard/presentation/dashboard_screen.dart` now presents:

1. A short greeting and local-workspace note where applicable.
2. Today’s billed sales and current outstanding dues.
3. New bill and Quick price actions.
4. Low-stock and outstanding-bill attention links when the currently available data reports them.
5. Up to three recent bills with customer, amount, and payment status, with View all.
6. A Reports shortcut.
7. An expandable business summary for earnings and activity charts.

Today’s sales use the today report. Outstanding dues use the all-time report’s open balance; they are not labeled as money received. The existing all-time earnings and chart functions remain available below the initial content.

### QuickPrice and estimate

`lib/features/pricing/presentation/quickprice_screen.dart` retains the visible estimate shortcut and groups calculator/rate setup, saved quotations, and information in **Calculator options**. Product selection, configured measurement inputs, live calculations, saved estimate items, and rate history remain on their existing paths.

The estimate screen already supported item edit/duplicate/remove, quotation PDF, checkout, copy, and share. No estimate calculation or persistence code was changed.

### Bill creation and bill detail

`lib/features/sales/presentation/sale_editor_screen.dart` labels the existing product, customer, and payment stages as 1, 2, and 3. Existing required customer information, optional address, quantity/price controls, full/advance/later choices, QR request behavior, save retry handling, and stock mutation are unchanged.

`lib/features/sales/presentation/sale_detail_screen.dart` presents reference and payment status, bill total, received and remaining amounts, then customer information and existing detail actions. Payment confirmation, PDF/print/WhatsApp actions, customer-contact edit eligibility, deletion confirmation, and follow-up behavior still use the original functions.

### Inventory and customers

`lib/features/inventory/presentation/inventory_screen.dart` labels the active catalogue filter **All**, retains Archived, and replaces separate outlined product containers with simpler divided rows. The same product, SKU/category, stock quantity, price, and low-stock status remain available.

`lib/features/customers/presentation/customers_screen.dart` shortens directory subtitles to a phone number or customer reference. Address, notes, consent, and bill history remain on customer detail.

### More, Settings, and retained modules

More now groups secondary modules and includes bill history and pending payments. `lib/features/settings/presentation/settings_screen.dart` adds Business, Appearance, and Data & device headings around existing UPI, bill-preference, theme, appearance-mode, notification, backup, and profile controls.

Purchases, expenses, reports, quotations, customer detail, profile, WhatsApp, and bill-appearance forms continue to use their existing screens and services. This pass did not rewrite them.

## 5. Screen-by-screen component inventory

| Screen | Purpose | Primary action | Secondary actions | Visible information | Optional/expandable information | Navigation | Files changed | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|
| Home | See what happened today and what needs attention | New bill | Quick price, View all, Open reports | Today’s billed sales, current dues, recent three bills | Business summary, earnings, charts | `/sales`, `/quickprice`, `/sales/history`, `/reports`, `/inventory`, `/sales/remaining` | `dashboard_screen.dart` | dashboard widget + navigation tests | PARTIAL |
| Mobile workspace shell | Reach five primary tasks and grouped secondary tools | Select a primary destination | More groups, profile, QuickPrice, saved bills | Home/Price/Bill/Stock/More | More sheet; side navigation at wide widths | Preserves existing routes | `workspace_shell.dart`, `app_router.dart` | app navigation, combined workspace | COMPLETE |
| QuickPrice | Calculate from configured products and rules | Add to Estimate | View estimate; Calculator options; supported share/breakdown | Selected product, configured inputs, current price | Calculator/rate management and explanation | Existing nested calculator and quotation flow | `quickprice_screen.dart`, `app_router.dart` | combined workspace, quotation flow, visual layout | COMPLETE |
| Estimate | Review and manage calculated lines | Continue to Sales | Quotation PDF, copy/share; per-line menu | Products, quantities, line totals, grand total | Per-line edit/duplicate/remove | Existing calculator, quotation, and sale routes | No change | quotation flow | COMPLETE (existing screen verified) |
| Bill editor | Create a sale with products, customer and payment request | Generate bill | Bill preferences, Saved bills, existing line editing | Products, prices, quantities, customer, total, payment choice | Existing item details and additional products | `/bill-settings`, `/sales/history`, saved sale | `sale_editor_screen.dart`, `workspace_shell.dart` | sales screen, app navigation | PARTIAL |
| Bill history | Find saved bills | Open a bill | New bill, search, remaining payments, preferences, refresh/load more | Customer, reference, date, total, payment status | Search and paginated history | `/sales/:id`, `/sales`, `/sales/remaining` | No change | sales screen, navigation | COMPLETE (existing screen verified) |
| Bill detail | Review a bill, payment, and documents | Record payment when due | Save PDF, print, WhatsApp/share, contact edit, delete, follow-up | Reference/status, totals, customer, payment history, items | Payment reminder and extra document options | Customer history, preferences, PDF/share system | `sale_detail_screen.dart` | sales screen | PARTIAL |
| Inventory list | Browse and search products | Add product | All/Archived, search by name or code, refresh, load more | Product, SKU/category, quantity, price, low-stock state | Product detail | `/inventory/add`, `/inventory/:sku` | `inventory_screen.dart` | inventory screen, dashboard inventory widget | PARTIAL |
| Product detail/form | Edit product data separately from stock adjustment | Edit product / Adjust stock | Archive/restore, history pagination | Quantity, price, attributes, movement history | Existing product parameters/pricing settings | Existing editor and stock adjustment routes | No change | inventory screen | PARTIAL (existing behavior retained) |
| Customers | Find customer records | Add customer | Search, customer detail | Name, phone or customer reference | Address/notes/history/consent on detail | `/customers/:id` | `customers_screen.dart` | app navigation, existing customer tests | COMPLETE for compact directory |
| Customer detail | Review customer and bills | Build bill for customer | WhatsApp consent, bill history | Contact, account history, totals | Existing notes and consent detail | `/sales/new?customerId=...`, `/sales/:id` | No change | Existing customer tests | PARTIAL (not restyled) |
| Purchases | Record supplier purchases and review purchase history | Record purchase | Add supplier, open purchase, load more | Supplier, amount, date, payment status | Existing purchase detail/return actions | `/purchases/new`, `/purchases/:id`, More | No change | No redesign-specific run | PARTIAL (existing screen retained) |
| Expenses | Record and review operating costs | Record expense | Expense actions/delete confirmation | Description, category, amount, date | Existing expense dialog | Existing expense route | No change | Not run in this redesign set | PARTIAL (existing screen retained) |
| Reports | Review period and financial performance | Select period/currency | PDF save/print, history links | Sales, collections, dues, earnings, charts | Profit/stock detail | Bill history and existing report actions | No change | Existing report UI covered indirectly | PARTIAL (not restyled) |
| Settings | Configure business and application preferences | Existing setting-specific save/action | Bill preferences, theme/mode, notifications, backup, profile | Existing settings grouped by headings | Notification/backup and appearance mode sections | `/bill-settings`, `/profile`, OS file/permission actions | `settings_screen.dart` | theme presets, bill settings, app navigation | PARTIAL |
| Bill preferences | Set invoice identity/layout and preview | Save changes | Templates, logo/signature, preview | Existing business/document fields | Image editor and PDF preview | Settings, bill detail/quotation | No change | bill settings tests | PARTIAL (existing screen retained) |

## 6. Exact buttons and their functions

| Control | Action |
|---|---|
| Home → New bill | Opens the existing `/sales` bill editor. |
| Home → Quick price | Opens the existing `/quickprice` route. |
| Home → View all | Opens saved bill history. |
| Home → Open reports | Opens the existing reports screen. |
| Home attention row | Opens Inventory or Remaining payments, according to the alert. |
| Recent bill row | Opens that saved bill’s detail by its existing ID. |
| Navigation → Price | Opens the existing QuickPrice route. |
| Navigation → Bill | Opens the existing bill editor route. |
| More → Bill history | Opens `/sales/history`. |
| Calculator options → Calculators and rates | Opens existing rate-card/calculator management. |
| Calculator options → Edit selling rates | Opens the existing simple rate editor for the current or a new calculator profile. |
| Calculator options → Saved quotations | Opens existing quotation history when wired. |
| Bill editor → Saved bills | Opens existing sales history while retaining the draft route underneath. |
| Bill editor → Back | Uses the existing router pop and bill-editor discard guard. |
| Inventory product row | Opens the existing product detail route. |
| Customer row | Opens the existing customer detail route. |

Existing edit, delete, save, PDF, print, WhatsApp, quotation, payment, stock-adjustment, and export controls were retained with their current handlers. The calculator toolbar’s less frequent actions were moved into a menu; none were deleted.

## 7. Files changed

| File | Change |
|---|---|
| `lib/app/routing/app_router.dart` | Wrap public QuickPrice in the workspace shell while retaining its public route behavior. |
| `lib/features/workspace/presentation/workspace_shell.dart` | Five mobile destinations, grouped More links, bill-history link, and guarded Bill-editor navigation presentation. |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | Home hierarchy, today/current-balance metrics, shortcuts, attention items, recent bills, expandable summary. |
| `lib/features/pricing/presentation/quickprice_screen.dart` | Group infrequent calculator actions in Calculator options. |
| `lib/features/sales/presentation/sale_editor_screen.dart` | Number the existing product/customer/payment stages. |
| `lib/features/sales/presentation/sale_detail_screen.dart` | Improve bill reference/status and financial/customer information order. |
| `lib/features/inventory/presentation/inventory_screen.dart` | Simpler catalogue rows and clearer All label. |
| `lib/features/customers/presentation/customers_screen.dart` | Compact customer directory subtitle. |
| `lib/features/settings/presentation/settings_screen.dart` | Business, Appearance, and Data & device headings. |
| `test/business/app_navigation_test.dart` | Verify new destinations, bill history access, and navigation/back behavior. |
| `test/business/combined_workspace_test.dart` | Verify grouped calculator actions and updated labels. |
| `test/dashboard_inventory_widget_test.dart` | Verify new Home hierarchy and responsive behavior. |
| `test/quotation_flow_test.dart` | Verify saved quotations are reachable from Calculator options. |
| `docs/APP_MASTER_DOCUMENTATION.md` | Add the verified UI/navigation addendum in section 27. |

No application database/configuration changes or new package dependencies were made.

## 8. Components reused or created

Reused shared components include `PageContent`, `SliverPageContent`, `FinancialAmount`, `RecordFact`, `DisclosureSection`, `ResponsivePair`, and `InlineNotice` from `lib/core/widgets/`. Existing semantic color tokens, four theme presets, and System/Light/Dark appearance handling remain in `lib/app/theme/` and Settings.

Home now has private presentation widgets (`_TodaySummary`, `_FinancialFigure`, `_AttentionItems`, `_AttentionRow`, `_RecentBillRow`, `_EmptyRecentBills`, and `_RetryMessage`) in `dashboard_screen.dart`. They do not contain database writes or pricing logic. No duplicate shared package or icon library was added.

## 9. Theme and typography decisions

The redesign continues to use Slate Blue, Sage Green, Warm Copper, and Muted Violet through the current theme controller. Light, Dark, and System remain separate from the color preset. Financial amounts use the existing `FinancialAmount` component and `formatBigMoney`/`formatMoney` functions. No invoice PDF branding or stored number formatting was changed.

## 10. Accessibility improvements

- Important Home values use the existing financial component and retain currency text.
- Recent bill rows expose a combined semantic description and remain tappable.
- Navigation destinations retain text labels and standard Material icons.
- Bill composition keeps existing `PopScope` discard protection while removing casual persistent navigation from that route.
- Home summaries stack at narrow widths or larger text scales. Recent-bill title/actions also stack at large text.
- Existing test coverage exercises 280–390 dp layouts, 2.5–3.0 text scaling for Home, 320 dp large-text sales screens in light/dark themes, and 320 dp theme-picker layouts.

Screen-reader manual testing, Android TalkBack, keyboard-only hardware testing, and orientation changes on a physical device were not performed.

## 11. Performance impact

No before/after timing or memory measurement was made, so no numerical performance improvement is claimed. Home no longer requests the complete customer directory just to show its count, but it now watches today’s report, all-time report, recent bills, and the default inventory page to render its requested summary. The trade-off has not been benchmarked with a large merchant dataset. No polling, animation loop, background service, or dependency was introduced.

Home’s low-stock alert only reflects products in the currently loaded inventory page. Scanning every page on Home would add potentially large reads and was not introduced. A proper low-stock query/filter remains a possible future improvement if implemented with repository pagination and tested against large catalogues.

## 12. Tests executed and results

Final validation command:

```sh
flutter analyze
flutter test \
  test/business/app_navigation_test.dart \
  test/business/sales_screen_test.dart \
  test/business/inventory_screen_test.dart \
  test/business/combined_workspace_test.dart \
  test/quotation_flow_test.dart \
  test/dashboard_inventory_widget_test.dart \
  test/business/bill_settings_screen_test.dart \
  test/theme_presets_test.dart \
  test/ux_redesign_visual_test.dart
```

Results: **analysis clean**; **108 tests passed**. The tests cover route access and Android Back behavior, bill draft safeguards/payment/document behavior, catalogue behavior, calculator and quotation paths, Home responsive layout, Settings/bill preferences, themes, and UI layout assertions. After the last menu-state cleanup, analysis and the combined-workspace/quotation tests were rerun; all four tests passed.

The Flutter test output included existing PDF font notices that Helvetica lacks Unicode glyph coverage; these did not fail the tests and are not caused by this presentation change.

## 13. Screenshots or visual verification evidence

Widget-level layout verification passed through `test/dashboard_inventory_widget_test.dart`, `test/business/sales_screen_test.dart`, `test/theme_presets_test.dart`, and `test/ux_redesign_visual_test.dart`.

No PNG screenshot artifact is included. The repository’s capture tests require `HYNER_TEST_FONT_DIR`; that variable is unavailable in this environment. The test harness was run without capture mode where supported. No physical Android screenshot or device validation is claimed.

## 14. Known limitations

- The Inventory screen has All and Archived filters; a correct low-stock filter is not available from the existing repository query API and was not approximated using only one page.
- The Home low-stock attention link can only detect low-stock products in its currently loaded inventory page.
- Home now makes several independent provider reads; performance at large record counts was not measured.
- Billing, bill detail, purchasing, expenses, reports, profile, and bill appearance retain substantial existing layouts. This pass improves hierarchy and access but does not replace every screen with a new visual design.
- Android device rendering, TalkBack, real printer, real file picker, WhatsApp handoff, and physical QR scanning were not tested.
- Screenshot capture is not verified in this environment.

## 15. Remaining recommendations

1. Add a repository-level paginated low-stock query before adding a reliable low-stock filter or business-wide Home count.
2. Capture and review screenshots at compact, standard, large-text, light, and dark configurations when `HYNER_TEST_FONT_DIR` is available.
3. Perform designated Android device checks for the workspace shell, PDF save/print/share, UPI QR presentation, WhatsApp handoff, and TalkBack labels.
4. Measure Home startup/query latency against representative synthetic large catalogues before tuning data access.
5. Continue screen-specific redesign only after inspecting each existing form and its existing functional tests.

## 16. Confirmation of preserved functionality

No application feature, route, database record, or existing UI action was deleted. Calculator actions were grouped in a menu but remain reachable. Bill history remains reachable from Home, More, and the bill editor. Existing calculations, stock movement behavior, payments, PDFs, customer consent, bill deletion confirmations, authentication, and authorization were left in their existing implementation. No database schema or migration changed.

There are no functionality removals awaiting approval. The remaining UI limitations are listed above.

## 17. QuickPrice inventory and daily summary follow-up (2026-11-14)

This follow-up responds to the request to avoid configuring a hardware product in QuickPrice and then re-entering it in inventory.

### Behavior added

- Simple calculator setup now has an **Inventory and costs** section with inventory tracking enabled by default, opening quantity default 50, low-stock threshold default 5, editable purchase cost, and a standard inventory selling price. The values are editable before saving.
- When tracking is enabled, setup links one active exact-name inventory match or creates an inventory product. A matched product keeps its existing stock and cost. Duplicate active names, archived matches, and currency mismatches are reported for the merchant to resolve; the feature does not merge or delete records.
- The optional stock link is saved with the calculator product. QuickPrice estimates carry it into checkout. Linked bill quantity is checked against and deducted from inventory by the existing sales transaction, and the sale retains a purchase-cost snapshot where cost was known. Bill deletion follows the existing stock reversal path.
- Home now displays today’s billed sales, cost of items sold, gross profit before expenses, and outstanding dues. This does not relabel a payment request as money received; the sales figure follows sale date, and profit excludes sales with unknown cost.

### Exact implementation files

`lib/features/pricing/presentation/simple_calculator_screen.dart`, `lib/features/pricing/application/product_setup.dart`, `lib/features/pricing/application/simple_calculator.dart`, `lib/features/pricing/domain/universal/rate_card.dart`, `lib/features/pricing/presentation/pricing_widgets.dart`, `lib/features/pricing/application/calculator_session.dart`, `lib/features/pricing/application/estimate_builder.dart`, `lib/features/sales/domain/sale.dart`, `lib/features/sales/data/local_sales_repository.dart`, `lib/features/sales/data/sale_codec.dart`, `lib/features/sales/presentation/sale_detail_screen.dart`, `lib/features/sales/presentation/sale_editor_screen.dart`, `lib/features/reports/data/local_reports_repository.dart`, and `lib/features/dashboard/presentation/dashboard_screen.dart`.

### Tests and boundaries

`flutter analyze` passed. The focused tests for QuickPrice sale storage/reporting, estimate persistence and conversion, setup defaults and same-name linking, responsive dashboard, bill deletion, and sales checkout passed (64 tests total). The suite displayed a non-failing Drift warning about multiple pricing database instances in a test executor. No database schema/migration or new dependency was introduced.

Varieties share their parent calculator's one inventory record; no variety-level stock is modeled. Measured dimensions do not imply stock-unit conversion: the recorded bill quantity is the amount deducted. Purchase cost zero is treated as unknown for gross profit. Existing unlinked calculator products are not backfilled until setup is opened and saved. Physical Android device testing and Firebase sign-in testing were not performed as part of this change.
