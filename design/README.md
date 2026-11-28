# Hyner app design references

These SVGs are static, Figma-importable references of the current Flutter app. They use the app's existing Material 3 sage-green theme, Manrope typography, 390 × 844 mobile framing, 20 px page gutters, 10 px control radius, and the current route labels.

## Import into Figma

Open a new Figma Design file, then drag any SVG onto the canvas. Right-click the imported artwork and choose **Ungroup**. Each file is intentionally self-contained so individual screens can be redesigned without affecting the others.

## Included routes

- `01-dashboard.svg` — `/dashboard`, the home page
- `02-quickprice.svg` — `/quickprice`
- `03-inventory.svg` — `/inventory`
- `04-sales.svg` — `/sales/history`
- `05-customers.svg` — `/customers`
- `06-reports.svg` — `/reports`
- `07-purchases.svg` — `/purchases`
- `08-settings.svg` — `/settings`
- `09-workspace-navigation.svg` — the shared drawer/navigation surface
- `10-secondary-routes.svg` — compact references for Expenses, Accounting, Quotations, Purchase Orders, WhatsApp, Profile, and onboarding/help surfaces

The source app is data-driven, so rows and totals vary with saved data. The references use representative populated-state content while retaining the implemented component hierarchy and wording. The Flutter source remains the implementation authority for behavior and responsive layout.
