# Universal pricing — Stage B

Implemented in the existing Flutter project. This stage adds local rate-card
persistence, not the merchant setup wizard or calculator screens. The APK still
opens the existing development shell. A usable calculator needs Stages C and D.

## Data contract

`domain/universal/rate_card.dart` defines profiles/drafts, category hierarchies,
priceable products/variants, immutable published cards, and the repository
interface. A priceable product is a pricing definition; it is not a new inventory
record. Business, category, currency, rule and product identities are validated.
Empty drafts can be saved, but cannot be published. No rates are seeded.

`data/local_universal_rate_card_repository.dart` implements the interface using
the existing Drift database. The trusted session supplies the business and actor
IDs and permissions; repository operations never accept an arbitrary business
ID from a form. Local ownership and cloud membership must be supplied by their
own future adapters. Firebase initialization does not authorize either.

Database v3 adds `universal_pricing_*` tables for profiles, drafts, published
versions, categories, priceable products/variants, input definitions, selling
rates, product unit systems/conversions, dimension policies, add-ons and audit
events. Versioned rule JSON holds the strategy tree, size/package/quantity rules,
discount and tax references. Full deterministic snapshots accompany normalized
queryable records. Decimal/rational amounts remain strings.

The separate universal table namespace prevents old `quickprice-1` snapshots
from acquiring new meanings. No catalog, customer, billing or stock table is
duplicated. Universal estimates and their snapshots belong to Stage E.

## Publication and reads

- Draft edits use revision checks; publishing also consumes a revision, so
  duplicate requests cannot produce duplicate publications.
- Publication validates business scope, configured rules and the approved tax
  policy through the existing `BusinessTaxPolicies` interface.
- The repository assigns the new version and effective/expiry timestamps to
  every rule. Time eligibility uses UTC milliseconds consistently with SQLite.
- The entire publication, normalized children, draft revision and audit event
  commit together. A failure rolls them all back.
- Sealed publications, children and audit events have SQL immutability guards.
  Rate changes create a new publication and preserve old calculation snapshots.
- Active reads use the latest effective version. An expired latest version never
  falls back to an older superseded rate. Archiving prevents active use while
  preserving history for authorized reads.
- Queries bind business/profile scope and use indexed, bounded pagination
  (1–50 results). Drafts allow at most 250 categories, 500 priceable products and
  a 1 MiB serialized local card. These are technical limits, not entitlements.
- No network calls or inventory movements occur in this repository. The engine
  continues to calculate using an in-memory published rule.

## Migration and verification

The migration is additive from v1 or v2 to v3. The v2 SQL fixture was captured
before this change. Tests exercise both upgrade paths, preservation of original
drafts/publications and unrelated inventory records, and foreign-key validity.

- Native suite: 317 tests passed (305 existing + 12 new persistence tests).
- Formatting: 31 Dart files checked with no pending formatting changes.
- Flutter analysis: passed, no issues.
- Web release build: passed, including Wasm compatibility dry run.
- Android debug APK: passed; `build/app/outputs/flutter-apk/app-debug.apk`.

New tests cover exact calculation after persistence, empty configuration,
historical stability, stale/duplicate publication, cashier restrictions,
business isolation, tax rejection, transaction rollback, effective dates and
expiry, archiving, SQL immutability, query bounds, actual on-disk reopening, and
the v2 upgrade. Existing v1 migration and pricing tests still pass.

Known non-failing warnings remain: Drift's multiple independent test database
instances and the upstream Firebase plugin's Kotlin Gradle migration notice.
No physical Android device was connected. No real-device speed, runtime UI,
Firebase sign-in or live cloud-sync result is claimed.

## Remaining boundary

Stages C and D must connect this repository to owner configuration and the
dynamic calculator. A local-only workspace needs an explicitly local owner
session; a cloud workspace needs real authentication, membership and server
authorization. Do not grant a cloud business role from a client preference.
No Firestore rules, indexes, authentication settings or production data were
changed by this stage.
