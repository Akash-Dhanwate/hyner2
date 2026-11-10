# Universal hardware pricing — Stage A

Implemented on 2026-11-08 in the existing Hyner app. This stage changes the pure
Dart domain only, with tests and documentation. It does not add database tables,
screens, estimates, authorization endpoints, billing or stock operations.

## Entry points and compatibility

Import `features/pricing/domain/universal/universal_pricing.dart`.

- `UniversalPricingRule` validates a complete versioned definition in memory.
- `UniversalPricingRequest` carries typed values and the separate order quantity.
- `UniversalPricingEngine.calculate(rule, request, at: time)` calculates locally.
- `PricingResult` exposes exact amounts, rounded minor amounts, the resolved
  rule, rates, original inputs, normalized and billable inputs, extras, policy
  warnings and a deterministic replay snapshot.

The old `PricingEngine` with engine ID `quickprice-1`, its models, persisted
schema and tests are preserved. Its previously unsupported strategy identifiers
remain unsupported: an old snapshot must not silently acquire new semantics.
New definitions use `universal-1` and JSON schema version 1. Stage B must add an
explicit engine discriminator and publication/storage adapter for these models.
Do not store universal JSON in a legacy draft and assume it will deserialize.

A rule value is a calculation definition, not proof of approval. The future
repository must supply the authorized business scope, approved tax configuration,
entitlements, immutable published version and allowed selling tiers. The current
engine is usable in both configuration previews and tests. It does not grant
permissions or synchronize changes.

## Units and product conversions

Dimensions are exact exponent maps: length, mass, currency, and distinct
commercial count/package kinds. Area is length squared and volume is length
cubed. Arithmetic propagates and checks these dimensions.

Standard units include metres, centimetres, millimetres, feet, inches and yards;
square metres/feet/inches/centimetres; cubic metres/feet, litres and millilitres;
kilograms, grams, tonnes and pounds; pieces/items, pairs and sets; bags, boxes,
cartons, rolls, buckets and packs. Fields specify the subset actually enabled.
Custom units can be added with a positive canonical factor. Standard physical
unit identifiers cannot be redefined by an imported configuration.

Physical conversions use exact rational constants, not binary floating point.
Pairs, sets and package types are distinct commercial dimensions. There is no
global assumption that a pair contains two inventory pieces, a box contains a
particular count, or a bag has a particular weight.

`ProductUnitSystem` validates explicit product-scoped conversion edges. Edges
can bridge a commercial count/package to its declared count, length, area,
volume or weight. Direct unrelated physical conversions such as metres to kg
are rejected; a physical derivation requires an explicit typed formula.
All graph paths must agree exactly, including inverse conversions and cycles.
Optional selling/purchase/inventory/display role units must be connected.
Missing, nonpositive, conflicting and cross-product conversion rules fail.
These definitions do not move inventory or duplicate a product catalog.
Selling units can differ from rate units when explicitly connected: a pair can
use a piece rate, and whole boxes can use a carton rate. The engine rounds the
chosen selling package before converting it to the rate unit; it never silently
rounds a partial carton when the merchant sells individual boxes.

## Dynamic input contract

`InputDefinition` stores ID, label, type, dimension, default/permitted units,
required status, default value, lower/upper bounds, precision, visibility
condition, display order, choice options and an optional multiple constraint.
Supported types are decimal, integer, choice and boolean. Order quantity is a
reserved separate integer control (1–1,000,000).

Bounds and multiples use the default unit; precision applies to the entered
unit. Values normalize exactly into canonical dimensions. A package may be an
allowed area/weight/etc. input only when an explicit product conversion exists.
An optional field without a value is absent, never implicitly zero. Formulas
that require an absent field fail clearly. Defaults are validated at definition
creation. Unknown fields and wrong value types fail.

Visibility supports equality against a choice or boolean field. Dependencies
are validated and evaluated in topological order. Cyclic/unknown dependencies
fail. Hidden values cannot influence prices; supplied hidden values are ignored
with a warning. Display order is stable with ID as a tie-break.

`InputSchema.preserveFrom` carries compatible IDs/types/dimensions between
products, preserving entered units when valid. Otherwise it converts exactly
and revalidates target precision/ranges. It drops incompatible fields. Package
counts are not transferred across products implicitly. When the same product's
pack size changes, physical coverage is preserved instead of reinterpreting an
old count. The caller preserves the separate quantity control.

This is the schema and preservation API for Stage D. Flutter controls are not
generated in Stage A. The legacy feet-and-inches helper remains available for
future compound input controls; the universal numeric model receives the
resulting exact measurement and an allowed unit.

## Pricing strategies and rate selection

Every strategy supports validation, exact local calculation and JSON encoding.
The strategy discriminator selects a closed, known implementation; configuration
cannot load classes, invoke functions, or execute arbitrary code.

1. Per-unit prices a measured piece/item, pair or set with an approved unit rate.
2. Area accepts a typed area field or an expression such as height × width.
3. Linear accepts a typed length or derived length.
4. Weight accepts enabled mass units or a formula producing mass.
5. Volume accepts measured or derived volume, including liquid volume units.
6. Packaging converts requested coverage/count/etc. using the product graph,
   applies waste/minimum/increment rules, then bills whole packages upward.
   The result retains both requested measurement/unit and billed package/unit.
7. Size slabs match configured numeric ranges, including multiple dimensions.
   Intervals are **[minimum, maximum)**; touching ranges are allowed, overlaps
   are rejected, and gaps produce an explicit unavailable-size error. Slabs
   use a configured flat selling amount per scalar unit.
8. Quantity tiers select the highest threshold at or below order quantity and
   apply its strategy to all items. Tiers start at one and have unique thresholds.
   This is all-units pricing, not a progressive/marginal tier schedule.
9. Components sum nested configured strategies for materials, kits and services.
   Components can be per item or once per order, and can depend on a boolean
   input. Once-per-order contributions are not multiplied by item quantity.
10. Custom formulas return money in the profile currency using typed arithmetic
    and approved rates. Their output is a per-item selling amount; the shared
    engine applies order quantity. Use the typed `quantity` symbol only where
    the merchant's per-item formula explicitly depends on order size.

`SellingRate` has a stable ID/key, exact amount, rate unit and optional choice
selectors (for example material, brand or finish). Lookup prefers the most
specific matching approved rate. A broad fallback exists only if configured.
Overlapping equal-specificity rules are rejected. Missing matches, mismatched
rate dimensions and unknown selectors fail. Customer/private tiers and their
authorization are Stage G work, not inferred from a seller-provided value.

The test suite provides serialized, replayable configuration examples for all
ten strategies. They include a door area example, linear material, measured
weight, liquid volume, tile coverage by boxes, size ranges, bulk quantities,
a kit with once-per-order installation, and glass with a custom cutting formula.
These are test fixtures only, never seeded merchant prices. A test adds a new
input and rate by editing JSON and recalculates without changing engine code.

## Safe formula contract

Expressions are `Literal`, `Reference` or `Arithmetic` nodes. Approved operations
are add, subtract, multiply, divide, minimum, maximum and ceil-to-increment.
No source-code string evaluator, reflection, network call, loop or function call
is available. Unknown node/operator/version identifiers fail.

References name numeric schema fields, the scalar `quantity`, approved rates
as `rate:key`, or named formula definitions. Rates normalize to currency divided
by their measurement dimension. Choice/boolean fields cannot enter arithmetic.
Named definitions form a validated dependency graph: unknown references,
shadowing, cycles and dimensional mismatches fail. Addition/subtraction/min/max
and ceil-to require matching dimensions; multiply/divide compose dimensions.
Price formulas must return the configured currency dimension.

Constant zero divisors and nonpositive constant increments fail validation.
Input-dependent zero divisors and invalid results fail during calculation.
Negative final selling contributions are rejected. Formula trees are bounded
to depth 32, programs to 1,024 nodes and 64 named definitions; decoded individual
expressions are limited to 256 nodes. Arithmetic results are bounded to 4,096-bit
numerators/denominators. Strategy composition is limited to depth 16 and 256
nodes, with further component, rate, field and unit limits.

## Calculation and rounding

All arithmetic reuses the existing `Exact` BigInt rational value object.
Money is never computed with `double`. Exact values serialize as strings;
minor-unit amounts are BigInt strings. The pure domain has no Flutter, database,
I/O or network dependencies. Ordinary recalculation needs no server request.

Calculation order:

1. Validate rule eligibility at the caller-supplied time and typed inputs.
2. Normalize units and retain the measured values.
3. Apply explicit per-input minimum/increment billing rules; reject billable
   dimensions above the field's maximum and retain both measured/billable values.
4. Resolve the strategy and applicable rate. For measured strategies, apply
   wastage, minimum billable quantity and an explicit upward increment, then
   the rate and minimum charge. Without an increment there is no rounding.
5. Combine per-item and once-per-order base/component amounts; apply quantity
   only to the per-item contributions. Add selected/required configured extras.
6. Apply the approved automatic percentage discount followed by the fixed
   discount if the configured quantity threshold is met. Reject over-discounting.
7. Apply the supplied approved inclusive/exclusive/exempt tax policy. The first
   universal engine uses one tax policy per rule, including its components.
8. Round monetary outputs using currency precision and half-up, half-even or
   toward-zero. Round net and total independently, allocate their difference to
   tax; round subtotal independently and allocate its difference from net to
   discount. Subtotal − discount = net and net + tax = total in minor units.

No intermediate money or measure is rounded without explicit policy. Warnings
describe applied billing policies and changed dimensions. `unitBaseAmount` is
before extras, discounts and tax; `orderBaseAmount` contains once-per-order base
components. The final total is authoritative; there is no implicit division of
order charges into rounded per-item prices.

## Snapshots and future integrations

The internal snapshot includes engine/schema version, calculation time, full
rule definition, input schema, unit conversions, selected rate contributions,
request/default-resolved values, measured/billable quantities, policy warnings,
exact amounts and rounded amounts. Replaying an expired historical calculation
uses its original eligibility time; calculating a new price with an expired
rule fails. A rate or schema update cannot mutate an existing result.

This snapshot contains internal configuration and alternative rates. It is not
a customer-share payload. Stage E must build a strict public projection for
customer display/comparison/sharing and store immutable estimate snapshots.
Multi-line estimates must deduplicate/group once-per-order services at the
estimate boundary, not sum independent standalone order charges blindly.

Stage B must persist input/strategy/rate/conversion/dimension/package definitions
under business-scoped immutable versions, with migrations preserving existing
v2 records. It must use the trusted session and backend rules for cloud writes.
Stage C builds the merchant wizard and visual expression builder. Stage D builds
the dynamic calculator. Stage E adds estimates/customer display/comparison.
Stage F connects authoritative catalog/quotation/billing/stock adapters. Stage G
adds paid entitlements, staff approvals, margins and measured performance.

The existing database, catalog references and sales behavior are unchanged.
No universal configuration is silently published or persisted in this stage;
no stock is deducted, sale finalized, invoice created or customer duplicated.
The app still displays its development shell until the UI stages.

## Verification — 2026-11-08

- Flutter analysis: passed with no issues.
- Dart format check: passed (26 files checked, no changes required).
- Native Flutter suite: **296 tests passed**, including all 225 pre-existing
  tests and 71 new universal-domain tests.
- Chrome domain suite: **280 tests passed**, including 209 pre-existing domain
  tests and the same 71 new universal-domain tests. These are platform runs of
  the same cases, not separate product acceptance scenarios.
- Android debug APK: passed; `build/app/outputs/flutter-apk/app-debug.apk`.
- Web release build: passed; `build/web`, including the compiler's Wasm dry run.

Verification covers all ten strategies, JSON-only configuration changes, exact
unit and product-pack conversions, commercial role mapping, invalid conversion
cycles, schema visibility/defaults/precision/ranges, compatible switching,
formula dependency/type/dimension/operator validation, division by zero,
complexity limits, rate ambiguity and absence, quantity boundaries, size slabs,
billable dimensions, wastage, per-order components/extras, discounts, taxes,
financial reconciliation, expiry and historical snapshot replay.

The existing database persistence/migration/permission tests still pass. Their
known Drift debug warning about independent test database instances remains
unchanged; no production database or schema migration was modified here.

No physical Android device profiling, counter usability study, accessibility
screen test, or under-100-ms performance claim was made. Those require the later
calculator UI and Stage G measurements. Backend authorization, cloud sync,
estimates, PDFs and finalized sales have not been verified as universal flows.

**Stage A stop point reached. Stage B has not been started.**
