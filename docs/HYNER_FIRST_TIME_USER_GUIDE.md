# Hyner First-Time User Guide

**Applies to source snapshot:** 2026-11-14  
This guide describes the onboarding and Help that are implemented in this repository. Menu names and route paths below were checked against the source.

## Welcome

When a workspace has no records in the checked local business tables and the guide has not been completed, Home shows:

> Welcome to Hyner  
> Set up your shop and start managing your business.

- **Get started** opens the optional checklist.
- **Explore on my own** closes the welcome prompt and records that the guide was dismissed.

The guide is not shown just because the app was updated. The first-use check looks for records in the workspace's products, sales, customers, settings, purchases, operating expenses, and quotations tables. Existing local business data suppresses the first-use prompt. Guide state is held in local SharedPreferences using workspace-scoped keys; it does not hold merchant records.

## Setup checklist

Open it from the welcome prompt, or later from **More → Take a tour** or **Settings → Help → Take a tour**.

| Step | What it does | Destination |
|---|---|---|
| Shop details | Opens the existing business/bill settings so shop details can be added for invoices. | `/bill-settings` |
| First product | Opens the existing stocked-product editor. The checklist also offers QuickPrice for shops that price configured products. | `/inventory/add`, `/quickprice` |
| First bill | Opens the existing bill flow; a QuickPrice option is also available. | `/sales`, `/quickprice` |
| Keep a backup | Explains that business records are local and that Google sign-in does not sync them, then opens existing settings/backup. | `/settings` |

Each task may be marked complete manually. This is guide progress, not proof that a record was saved. **Finish setup** and **Skip for now** both return to normal app use. No sample products, customers, or bills are created. Returning to the checklist does not change business data.

## Find a task later

Open **More → How do I...?** or **Settings → Help → How do I...?**. Search by task or browse these entries:

| Task | Opens | Next action |
|---|---|---|
| Change shop details | Bill/business settings | Edit supported business identity and contact fields. |
| Edit bill appearance | Bill appearance settings | Change supported PDF appearance and preview it. |
| Change product price | Inventory | Select a product, then use its existing Edit product action. |
| Adjust stock | Inventory | Select a product, then use Adjust stock. Do not use product editing to record stock movements. |
| Edit calculator rates | QuickPrice rate management | Choose a calculator and edit its existing rates/configuration. Published-history rules remain in effect. |
| Rename a calculator | QuickPrice calculator management | Open the existing calculator actions and rename it where that calculator supports it. |
| Download a bill | Sales/bill history | Open a saved bill and use the document action. |
| Record a payment | Saved bill/payment screen | Open the bill with a balance and use its existing payment action. |
| Change app theme | Settings | Choose an existing color preset or appearance mode. |
| Create a backup | Settings | Use the existing backup action and follow its prompts. |

The Help screen is a shortcut list; it does not automatically choose a product or modify a record. Where an exact item is unknown, the user selects it on the destination screen. It only points to existing capabilities.

## Data and sign-in

The current architecture stores business records in local databases on the device. Signing into Google/Firebase authenticates an account; it does **not** by itself synchronize the local business register to a cloud database. Use the existing backup function and keep a copy somewhere safe. The exact backup coverage and platform behavior are documented separately in the master documentation and business-readiness report; do not assume backup includes files unless the current backup implementation says it does.

## Calculator products and Inventory

Calculator products with varieties appear as separate Inventory items, named with the product and variety. Each item's selling price comes from its configured calculator rate; set purchase cost per variety or use the shared product cost. Products without varieties create one item. New linked items default to 100 stock units with a low-stock alert at 10. Stock counts whole units; calculator dimensions such as area or weight do not automatically convert to stock consumption.

When Inventory is opened, Hyner checks active calculator drafts and adds any unlinked product varieties. Opening a calculator in rate-card management also retries this sync. An old single Inventory link is reused for the first variety; new variety rows use the configured opening quantity default, so review their actual counts before selling. Existing exact-name Inventory items are reused; calculator selling rates update their prices while current stock is preserved. Use **Preview & publish** so future bills use the variant stock link. Existing saved bills and published versions are preserved.

## Help limitations

The current guide is a short checklist and searchable destination list. It does not display coach marks anchored to buttons, infer task completion from a saved product/bill, or provide an interactive tutorial inside every form. Use the actual screen labels and existing validation when changing business data. Finalized bills follow their existing correction restrictions.

## Source references

- Welcome and setup: `lib/features/onboarding/presentation/welcome_screen.dart`, `lib/features/onboarding/presentation/first_time_user_guide_screen.dart`
- Guide state: `lib/features/onboarding/data/onboarding_preferences.dart`
- Task Help: `lib/features/onboarding/presentation/help_screen.dart`
- Routes: `lib/app/routing/app_router.dart`
- Access points: `lib/features/workspace/presentation/workspace_shell.dart`, `lib/features/settings/presentation/settings_screen.dart`
- Empty-workspace first-use check: `firstTimeGuideProvider` in `first_time_user_guide_screen.dart`
