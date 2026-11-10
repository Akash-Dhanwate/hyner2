# Module 06A — pricing domain and persistence

This repository is a new Hyner application, created at the user's direction.
There were no existing auth, business, inventory, quotation, entitlement or
billing modules in this workspace. Their integration is explicitly deferred.
No production credentials, default merchant rates or sample published cards
are installed. Test prices are fixtures only.

## Domain boundaries

`features/pricing/domain` is independent of Flutter, storage and network APIs.
`PricingEngine.calculate` is synchronous and has no API calls. Load a stable
`PublishedRateCard` once, then pass immutable `PricingInput` values. Reusing the
same `Dimensions` when changing category preserves entered measurements. A
missing variant, rate, dimension, weight, fitting stock size, or effective rate
card fails explicitly; there is no fallback to a zero or stale final price.

The domain supports piece, square foot, square metre, running foot, metre,
cubic metre and kilogram base methods. Running length uses the height axis;
volume uses height × width × depth; weight is explicitly entered in kilograms.
Canonical lengths are metres; entered units remain in the dimension snapshot.
Feet/inches are separate inputs, with inches in [0,12). Quantity is an integer
from 1 through 1,000,000; fractional measured quantities remain exact.

Quantity-tier base rates, dimension-band base prices, formula parsing and
composite component evaluation have reserved method identifiers. They cannot
be published or evaluated in engine `quickprice-1`. Their typed policies and
evaluators belong to the advanced pricing module. The existing quantity
threshold applies only to automatic discounts, not to tiered base-rate pricing.
There is no expression evaluation, JavaScript execution or unsafe formula stub.

## Exact calculation contract

`Exact` is a reduced BigInt numerator/denominator. Decimal inputs are parsed
from strings and conversions are exact. No money is computed with `double`.
Exact snapshot values are strings such as `150`, `1/3` or `127/5000`.
Integer metadata is normalized within JavaScript's safe integer range so
native Dart and web produce identical canonical JSON. Objects use sorted keys;
arrays preserve their meaningful order. Minor-unit money uses BigInt strings.

The calculation order is:

1. Check rate effective dates, active category/variant, rule and inputs.
2. Validate measured dimension ranges and minimum quantity (reject, never inflate quantity).
3. Calculate measured area/length/volume/weight from canonical dimensions.
4. Round dimensions upward if configured; select the smallest fitting stocked
   measure if configured, with canonical JSON as a stable tie-break. Validate
   the resulting billable dimensions against allowed ranges again.
5. Apply minimum billable measure, then upward measure increment.
6. Multiply by the rule rate; apply minimum per-item price; multiply by quantity.
7. Add required/included/explicitly selected add-ons. Percentage add-ons use
   the base price before other add-ons and discounts. Area/length add-ons use
   billable dimensions, not an unrelated base-method minimum measure. A
   quantity add-on uses its own explicit count. Included accessories add zero.
8. Apply the published automatic percentage discount, then fixed line discount,
   if its quantity threshold is met. Excessive discounts fail instead of
   becoming negative totals. Seller input cannot override rates or discounts.
9. Apply the validated business tax policy. Inclusive rates/add-ons/discounts
   are in gross terms; exclusive rates are net. All charges in this first
   engine use the rule's single tax policy. Exempt rules require a zero rate
   and an explicit approved reference. No jurisdictional tax rate is supplied.
10. Round only at monetary output boundaries with the profile's half-up,
    half-even or toward-zero policy and currency precision. Round total and
    net independently, then allocate their residual to tax. Round subtotal
    independently and allocate its difference from net to discount. Thus
    subtotal − discount = net and net + tax = total in minor units.

The exact tax/discount values are retained alongside rounded allocations.
`unitBasePrice` is explicitly before extras, discounts and taxes; the final
line total is authoritative. Every applied billable-size policy is returned
with both measured and billable dimensions. No hidden area rounding occurs.

`perOrder` add-ons currently describe one standalone calculation/order. Module
06D must group order-scoped charges and apply them once across an estimate;
it must not simply sum per-order charges from independent calculations.
`defaultSelected` is a UI default. The input carries explicit optional selections
so the user can deselect a default; required/included add-ons always apply.

## Persistence and migration

`PricingDatabase` is Drift/SQLite with foreign keys enabled. Version 1 is the
profiles/drafts baseline preserved as a frozen SQL fixture. Version 2 adds
normalized publication tables, indexes and audit history without dropping
baseline tables. This is a migration test baseline for this new app, not a
claim of compatibility with any previous Hyner application's schema.

Profiles have mutable lifecycle metadata. Drafts contain editable deterministic
JSON plus an optimistic revision. A publication transaction validates the full
draft and business tax policies, writes the version manifest and related
category, variant, rule and add-on rows, then seals the version and appends an
audit event. Foreign keys include business, profile and version identity.
Published child entities preserve names and attributes as well as rates.
Rule/add-on relationships are normalized in a join table.

SQLite triggers reject updates/deletes of sealed versions, updates/deletes or
late inserts of their related records, and audit mutation. Publication advances
the draft revision, so duplicate taps and stale saves cannot create extra
versions. Editing drafts does not affect published versions. Archive disables
new active-card lookups but retains history for reading and export.

Active versions are resolved with an indexed, bounded query by effective date
and version. Future versions remain scheduled; an expired latest applicable
version fails explicitly instead of falling back to an older rate. New
effective dates cannot precede the last published effective date. History and
profile lists use cursors and page limits of 1–100. Local snapshots have a
2,000,000-character cap, with further entity-count limits in the domain.

On Android, `openLocalPricingDatabase` opens a durable file through Drift on a
background isolate. App bootstrap must own a single database instance and close
it at shutdown. The shell deliberately does not invent a business session.
Host tests exercise actual SQLite files and close/reopen persistence.

## Security and integration contracts

`PricingSession` comes from a trusted local-owner or authenticated business
session adapter. Repository calls never accept a business ID from a pricing
form. Every query and mutation includes the bound scope. Recreate scoped
repositories and clear in-memory cards when accounts or businesses change.
The permission enum includes all twelve requested pricing keys. Default cashier
permissions permit calculate/view/create-estimate/share-estimate only. Sale
conversion also needs its own billing permission and is not enabled here.

These guards enforce application behavior for a local business. They are not
a substitute for backend authorization and do not protect against editing a
local database with an external SQL tool. `PublishedRateCard` is a data value,
not cryptographic proof of approval. Construct it only from a trusted repository
in app flows. The arithmetic engine is intentionally usable in preview/tests.

`BusinessTaxPolicies.isApproved` must compare ownership and the complete policy
against the validated business configuration. There is no production allow-all
adapter. Tests inject a limited fake; the app must not use it.

Future cloud adapters implement `RateCardRepository` and retain the same logical
relationships under business-scoped Firestore paths. Server-side membership,
permissions, entitlements, revision checks, effective dates and immutable
publication must be enforced by the owning backend. Clients must never grant
themselves roles or write publication/audit records. Large cards must be split
into version manifests and bounded child collections, respecting Firestore's
document limits; do not copy the local 2 MB draft blob into one document.
No Firestore connection or permissive rules are shipped in this module.

Web builds the shell and passes pure domain tests. `openLocalPricingDatabase`
explicitly rejects web usage. The web repository will use authorized cloud
data; browser-local state is not presented as permanent business storage.
Cloud freshness, revocation and provisional-offline policies remain deferred.

Future estimates persist immutable `PriceBreakdown.snapshotJson`, including the
engine/version identity, currency, measured/billable dimensions, tax, discount,
add-on definitions and amounts. Quotations and bills must consume these
snapshots; never reconstruct a historical price from today's rate card. A
customer-safe projection must allowlist public selling fields before sharing.

No estimates, inventory movements, invoices or stock deductions are created by
this module. Optional catalog IDs are references only. Modules 06D–06F will add
estimate storage, quotation adapters and authorized idempotent billing through
the owning business modules. They must preserve prices, validate tracked stock,
and apply per-order charges only once. No duplicate billing engine is included.

## Next module

06B adds guided owner configuration, preview and publishing UI using these
repositories. 06C adds the fast seller workflow and customer display. 06D adds
estimates and comparison. 06E adds paid rules, tiers, permissions/approvals and
quotation integration. 06F adds billing integration and production validation.
Entitlements, minimum margins, private tiers and production readiness are not
claimed by this foundation.
