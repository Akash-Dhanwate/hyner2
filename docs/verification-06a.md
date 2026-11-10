# Module 06A verification — 2026-11-08

Executed on the development Mac using the installed Flutter/Dart SDK.

- Drift code generation: passed.
- Dart format check: passed, no changes required.
- Flutter analysis: passed, no issues.
- Native Flutter test suite: 225 tests passed.
- Chrome domain/value/engine suite: 209 tests passed. This is the web execution
  of the domain tests, not 209 additional distinct acceptance scenarios.
- Android debug APK: passed; `build/app/outputs/flutter-apk/app-debug.apk`.
- Web release build: passed; `build/web` (including compiler Wasm dry run).

Tests cover unit conversions, mixed feet/inches, exact area/volume, all seven
implemented base pricing methods, category/variant selection, quantity bounds,
minimum measures/prices/quantities, dimension increments and ranges, stocked
sizes, all add-on modes, automatic discounts, arbitrary configured inclusive/
exclusive/exempt tax, deterministic rounding, snapshot stability and replay.

Persistence tests use actual Drift/SQLite, including a file-backed database
closed and reopened, migration of a frozen v1 schema into v2 while preserving
unrelated records, optimistic draft revisions, concurrent duplicate publication,
immutable publication triggers, tax approval rollback, scheduled/expired cards,
archive/history, bounded profile lists, cashier restrictions and business isolation.

The first native runs and Android build were blocked by upstream binary download
HTTP 504 responses. SQLite's hash verification rejected the HTML error payload.
The final build compiles verified official SQLite source included in the repo;
no checksum verification was bypassed. A first Chrome run caught integer JSON
metadata differences between Dart VM and JavaScript. Whole metadata values now
normalize consistently and both final suites pass. Money remains exact strings.

Drift emits a debug warning in persistence tests that deliberately construct
separate in-memory and file-backed database instances. They use independent
executors and paths, and all are closed. Production bootstrap must own one
database instance. The fresh app currently does not bootstrap a business session.

Not performed or not in scope:

- Physical affordable Android hardware, measured category-switch latency,
  startup timing, counter usability, or the ten-second workflow target.
- Seller/configuration screens, customer-safe view, 320 dp/accessibility UX,
  estimate navigation/restart recovery, comparison, quotation/PDF matching.
- Actual backend/Firestore authorization or synchronization, subscription gates,
  private tiers, discount approvals or margin enforcement.
- Stock deduction or invoice conversion/idempotency. The tested duplicate-tap
  guard concerns rate publication only; it is not an invoice test.
- Production signing, release APK, store deployment, web cloud persistence or
  full production acceptance. The APK and website show the development shell.

Module 06B has not been started. See `module-06a.md` for integration contracts.
