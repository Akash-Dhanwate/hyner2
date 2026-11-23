# Hyner UI design system

Status: design contract for the presentation-only redesign. This document is based on the repository wireframe captures in `docs/ux-redesign/after/`, the current `HynerTheme`, existing brand assets, and the existing UX audit. It does not change application behavior.

## Product direction

Hyner is a practical merchant workspace for pricing measured products, stock, bills, customers, purchases, expenses, and reports. The visual language is a calm, precise ledger: warm paper surfaces, deep green actions, charcoal type, and quiet dividers. The interface should feel trustworthy during a live customer conversation, not promotional.

The design hierarchy is:

1. Identify the current task or record.
2. Show the current amount/status clearly.
3. Ask only for the required input.
4. Give one obvious primary action.
5. Keep confirmation, retry, empty, and secondary actions visible and plain.

## Source-of-truth logic boundary

The following are immutable contracts during UI work:

- Riverpod providers, controllers, repositories, services, hooks, and async lifecycles.
- Existing state variables, `TextEditingController`s, validators, calculations, and data bindings.
- Existing callbacks, event handlers, save/delete/export/share/print/payment actions, and confirmation guards.
- Existing GoRouter route paths, redirect rules, route parameters, query parameters, `extra` values, and back behavior.
- Existing loading, empty, error, retry, account-scope, and uncertain-save behavior.
- Existing domain models, persistence, Firebase integrations, PDF generation, notifications, image picking, and pricing logic.

UI changes may rearrange widgets, extract presentational widgets, apply theme tokens, and improve responsive layout. They must re-bind to the same functions and values without changing their meaning or timing.

## Color tokens

The default wireframe is Sage Green in light appearance. Theme presets remain supported; these tokens describe the default visual role rather than replacing the existing preset controller.

| Token | Hex | Use |
|---|---:|---|
| `ink` | `#222D27` | Primary text, headings, high-emphasis values |
| `ink-muted` | `#526157` | Supporting text, labels, navigation icons |
| `forest` | `#175C46` | Primary action, selected navigation, links, positive emphasis |
| `forest-soft` | `#E5F1EB` | Selected navigation indicator, soft positive surfaces |
| `paper` | `#F8F9F5` | Light page background |
| `paper-raised` | `#FFFEFB` | Input/control surfaces and quiet elevated regions |
| `line` | `#DCE3DA` | Dividers, unfocused boundaries, card outlines |
| `line-strong` | `#76877B` | Input boundaries and secondary control outlines |
| `success` | `#246447` | Saved/paid/healthy state |
| `warning` | `#80541D` | Due/attention state |
| `error` | Theme error role | Validation and destructive failure; always paired with text/icon |

Dark appearance keeps the same semantic roles with the existing dark preset surfaces: deep green-black page surface, light ink, muted sage support text, and the preset's light primary for actions. Do not hard-code light colors inside screen widgets.

## Typography

Typeface: `Manrope`, already bundled at `assets/fonts/Manrope.ttf`. Use one family throughout the product.

| Role | Size | Weight | Line height | Guidance |
|---|---:|---:|---:|---|
| Display / greeting | 28–32 px | 700 | 1.15 | One strong page-level statement; left aligned |
| Screen title | 23–26 px | 700 | 1.2 | Use for major screen headings |
| Section title | 18–20 px | 700 | 1.25 | Use for task groups and summaries |
| Control title | 16 px | 600 | 1.35 | Buttons, list rows, field labels |
| Body | 14–16 px | 400–500 | 1.45–1.5 | Plain, conversational copy |
| Supporting / metadata | 12 px | 400–600 | 1.5 | Secondary context; never the only label |
| Financial amount | 20–32 px | 700 | 1.1–1.2 | Use existing `FinancialAmount`/money formatting |

Use sentence case. Do not introduce tracked-out all-caps labels. Keep normal text lines below roughly 80 characters. Do not clamp user text scaling.

## Spacing scale

Use a 4 px base rhythm:

`4, 8, 12, 16, 20, 24, 32, 40, 48`

- Phone page gutter: 16 px; wireframe content gutter may use 20–24 px for focused forms.
- Desktop content gutter: 24 px; bounded content max width: 960 px unless a data table needs more room.
- Section separation: 24–32 px.
- Label to control: 8 px.
- Related control spacing: 8–12 px.
- Primary action height: 52 px.
- Standard touch target: minimum 48 × 48 px.
- Bottom navigation safe-area content: preserve platform safe-area padding.

## Shape, borders, and elevation

- Standard control radius: 10 px.
- Compact chip/range radius: 8 px.
- Selected navigation indicator: pill radius 20 px.
- Full cards are reserved for grouped records, dialogs, and meaningful summaries. Do not wrap every datum in a card.
- Default surfaces are flat. Prefer a 1 px `line` divider over a shadow.
- If elevation is required for a modal/action sheet, use a low, neutral shadow: `0 8px 24px rgba(25, 45, 35, 0.12)` equivalent in Flutter.
- Focused fields use a 2 px primary boundary. Error fields use a 2 px error boundary plus visible error copy.

## Layout and responsive behavior

### Breakpoints

- Compact phone: `< 360 dp` — single column, stack all paired fields/actions.
- Phone: `360–719 dp` — single-column content, bottom navigation, 16–20 dp gutters.
- Wide/tablet: `720–1023 dp` — persistent navigation rail/sidebar, paired fields where readable.
- Desktop: `>= 1024 dp` — 224 px workspace sidebar, bounded main content, two-column action rows when both controls remain comfortable.

Responsive layout must also react to text scale. If enlarged text causes a pair to become cramped, stack it even when the width breakpoint would otherwise allow two columns.

### Workspace shell

Phone uses the existing five-destination bottom navigation: Home, Inventory, Sales, Reports, More. Wide layouts use the existing sidebar and keep secondary modules grouped by merchant task. The shell may be visually refined but route selection, drawer behavior, and back-stack behavior are unchanged.

### Screen composition

```text
PHONE                         WIDE
┌──────────────────┐          ┌────────────┬─────────────────────┐
│ app bar           │          │ workspace  │ app bar             │
│ task / title      │          │ navigation │ task / title        │
│ primary action    │          │            │ primary action row  │
│ current facts     │          │            │ current facts       │
│ optional details  │          │            │ optional details    │
│                  │          │            │                     │
│ bottom nav        │          │            │                     │
└──────────────────┘          └────────────┴─────────────────────┘
```

Align text and amounts to a stable left edge. Use right alignment only for numeric values in a repeated row or clearly paired financial facts. Avoid decorative hero panels, gratuitous gradients, and dense card grids.

## Components and interaction states

- Primary action: one filled deep-green button per task group; label the result, e.g. `Save product`, `Add to estimate`, `Build a bill`.
- Secondary action: outlined or text button; do not give every action equal visual weight.
- Inputs: filled `paper-raised` surface, visible outline, 16 px horizontal padding, 48 px minimum height, explicit focused/disabled/error states.
- Lists: compact but breathable rows with a clear title, supporting line, and trailing amount/status where applicable.
- Disclosure: use for optional/advanced settings. Preserve child state while closed and reopen when validation identifies an error.
- Loading: retain the current loading message/progress behavior; avoid layout jumps where practical.
- Empty: explain what is absent and give the existing creation/import action.
- Error: say what failed, preserve entered values, and expose the existing retry or recovery handler.
- Success: use existing confirmation/snackbar behavior and keep wording aligned with the completed action.
- Focus: use visible primary-color focus boundaries; never rely on color alone for state.

## Screen-specific visual priorities

- Home: greeting → QuickPrice/build bill → business snapshot → balance due → activity details.
- QuickPrice: product/variety context → measurements → quantity/rate → current total → Add to Estimate.
- Bill editor: product lines and customer/payment stages; keep pricing and payment actions direct.
- Inventory: search/filter → catalogue rows → stock state; keep add/edit/adjust actions findable.
- Reports: period/currency filters → key financial facts → optional charts/details → export.
- Settings: business/payment setup first; appearance, notifications, backup, and profile in clear groups.

## Accessibility and quality bar

- Preserve at least 48 dp hit targets and semantic labels/tooltips on icon-only actions.
- Maintain readable contrast in all four presets and both brightness modes.
- Respect `MediaQuery.disableAnimations` and reduced-motion behavior.
- Never remove a handler to simplify a layout. If an action moves into a menu/disclosure, it must remain reachable and use the same callback.
- Verify narrow widths, large text, light/dark modes, keyboard insets, loading, empty, error, and retry states before considering a screen complete.

