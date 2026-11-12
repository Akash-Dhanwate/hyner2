# Flutter Optimization Audit

**Application:** Hyner 0.6.0+8 · `com.hyner.hyner`  
**Audit date:** 10 November 2026, Asia/Kolkata  
**Source baseline:** Git commit `094766cc145b7b8586153e403c733a96a18a9692` (`all asset files are added`)  
**Status:** AUDIT COMPLETE — IMPLEMENTATION NOT AUTHORIZED

Only this report is added to the application repository. No application source, configuration, dependencies, schemas, user data, or production services were changed. Diagnostic builds, synthetic data, logs, and downloaded measurement tooling were placed in `/private/tmp/hyner-optimization-audit-mtgkl9fk`, outside this repository. No APK was installed, no store upload occurred, and no account messages were sent. Temporary build outputs are measurements, not an approved optimized release.

All sizes below use **decimal MB = 1,000,000 bytes** unless explicitly marked MiB. APK file size, AAB upload size, compressed device delivery, installed storage, and process RAM are different metrics.

Evidence labels:

- **Measured (M):** tool output observed during this audit. A synthetic host measurement is identified as such and is not a phone benchmark.
- **High-confidence estimate (H):** supported by code structure, bounds, or an unchanged-source build comparison; remaining implementation effects are unmeasured.
- **Tentative estimate (T):** planning assumption requiring validation.
- **Unknown (U):** unavailable in this environment; no numeric improvement is claimed.

## Section A: Executive Summary

### Engineering conclusion

**The ≤50 MB Android delivery target is realistic without removing functionality.** The currently supplied universal APK is **77.16 MB**. Native libraries for three ABIs account for **96.11%** of its file bytes. An unchanged-source ARM64 size-analysis build is **27.95 MB**, a **63.78% file-size reduction** relative to the universal APK. This is a distribution comparison, not evidence that application code or RAM use became 63.78% more efficient.

An unchanged-source AAB is **75.68 MB as an upload artifact**. Bundletool 1.18.3 estimates **13.43 MB compressed delivery** for ARM64/API 35/420 dpi/English and **13.21 MB** for ARM32/API 24/320 dpi/English. These are local estimates for specified configurations, not measured Play Console downloads. The app has not been uploaded. AAB delivery is a separate distribution alternative to ABI-specific sideload APKs; their savings must not be added together.

**Runtime health is promising for ordinary workloads, but 2 GB operation and stable 60 FPS are unproven.** There is no connected Android device, no iOS SDK, no iOS host project, and no device traces or heap recordings. The application has sensible foundations: local transactional business storage, exact pricing, immutable published pricing versions, idempotent operations, generation guards, and several correctly paginated registers. Static analysis passes, and **674 tests pass with three opt-in screenshot tests skipped**. These establish a correctness baseline, not performance certification.

The largest credible runtime risks are:

1. **Dashboard work grows with the entire ledger.** The dashboard requests the all-time full report, which loads and decodes historical sale/purchase JSON and retains record lists even though the dashboard needs only totals and chart buckets.
2. **Several data paths defeat otherwise good pagination.** Customer detail reads all customers; history searches duplicate identities and unlinked bills without a customer index; pending payments decode all sales; WhatsApp loads every product and customer; expenses are unbounded.
3. **UI-thread document and media work.** PDF page layout and image processing precede the package's native serialization isolate. Android profile-photo processing and PDF file writes run in activity/channel callbacks on the Android main thread.
4. **Avoidable retention and repeated work.** Non-auto-disposed workspace families and database-handle maps can retain account workspaces; per-edit draft serialization queues snapshots; repeated image decoding and duplicate-PDF reads create temporary buffers.
5. **A legacy cloud import can restart expensive work.** It loads catalogues and all movement histories before committing, under a two-second budget, then retries after failures. Large accounts may repeatedly fetch the same pages.

**Recommended strategy:** use architecture-aware delivery first, then Plan B's targeted changes to data access, document work, draft persistence, and resource ownership. Keep exact arithmetic, replay validation at trust boundaries, account isolation, durable bill history, and offline operation. Do not perform a broad state-management rewrite or replace the pricing engine.

### Expected combined outcome and uncertainty

- **Size:** the principal gain is already demonstrated by diagnostic packaging: approximately **28 MB ARM64 sideload APK**, or approximately **13–14 MB compressed AAB delivery** for measured configurations. Additional code/asset changes are much smaller opportunities. These are not promises for every ABI, store, or future release.
- **Memory:** bounded queries can replace tens of thousands of simultaneously retained records with one page plus summaries. Absolute PSS/Dart-heap reductions are **unknown**; it would be misleading to promise “50% less RAM.”
- **Startup:** the current first frame does not wait for Firebase, which is good. Time to a *useful populated dashboard* can still grow with ledger size and preference/profile reads. No measured cold/warm-start result exists.
- **Rendering:** removing synchronous layout/serialization/image work from interactive paths should reduce identifiable blocking opportunities. A 60 FPS guarantee requires physical-device frame timings.
- **Network/battery:** there is no general polling loop to eliminate. Biggest plausible gains concern avoiding repeated legacy imports and unnecessary serialization/writes. Battery percentages are unknown.

### Major technical risks

Additive financial summaries can become inconsistent unless backfilled and updated transactionally. Caching mutable pricing objects can weaken replay checks. Deferring writes can lose drafts unless durability barriers are preserved. Isolates can increase peak memory through copies. Cache cleanup can break delayed WhatsApp reads. A new signing key can prevent updating existing installations. Cross-platform parity is incomplete today: web QuickPrice is a transient preview; the native business database and custom Android channels do not establish full web/iOS support.

## Section B: Current Performance Baseline

### Required baseline table

| Metric | Current Measurement | Target | Measurement Status |
|---|---|---|---|
| Android download size | Directly supplied universal APK: **77,164,678 bytes / 77.16 MB / 73.59 MiB**. Local AAB delivery estimate: **13,426,385 bytes / 13.43 MB** on ARM64/API 35/420 dpi/en | ≤50 MB, specify delivery method | **M:** APK bytes; **M tool estimate:** bundletool, not actual Play transfer |
| Installed size | **Unavailable.** ZIP entries total 80,190,210 uncompressed bytes; this is **not** installed size | Reduce where practical | **U:** needs device package/storage measurement, including ART output, DBs and caches |
| iOS app size | **Unavailable; no `ios/` host, archive, IPA, or iPhone SDK** | Optimize when an iOS target exists | **U / target not implemented here** |
| Web initial download | No observed HAR. Fresh default release: app JS **5.14 MB raw / 1.51 MB gzip model**; app+one renderer+selected boot/font files model **3.01–4.52 MB gzip**, depending on renderer | Measure actual first-load transfer, then reduce | **M:** files/gzip; **T:** transfer model; real hosting/cache/CDN behavior **U** |
| Cold startup | Unavailable | <3 seconds to a useful screen where realistic | **U:** no physical device; measure first frame and useful dashboard separately |
| Warm startup | Unavailable | Faster resume without unnecessary reloads | **U:** no activity/process lifecycle trace |
| Typical RAM use | Unavailable: no Dart/native/graphics/PSS sample | Working set appropriate to available app memory | **U:** 2 GB device total RAM is not the app's allocation budget |
| Peak RAM use | Unavailable | No memory-pressure termination during supported worst-case work | **U:** image/PDF/backup paths need measurement |
| Scroll frame time | Unavailable | UI and raster stages within 16.67 ms at 60 Hz; track missed-vsync rate | **U:** widget tests are not FPS benchmarks |
| CPU usage | No on-device CPU profile. Synthetic desktop SQL fetch timings recorded below | Reduce demonstrated expensive work | **M:** host surrogate only; device CPU usage **U** |
| Network usage | No traffic capture; local transactions do not inherently require network | Eliminate avoidable repeats while preserving auth/import semantics | **H:** static request paths; request counts/bytes **U** |
| Battery consumption | No power trace; no app-owned periodic polling/worker/wakelock found | Reduce unnecessary work; verify energy per scenario | **H:** static scheduling inspection; energy/mAh **U** |

### Repository and architecture inventory

- **Toolchain measured:** Flutter **3.47.7 stable**, Dart **3.13.5**, DevTools **2.60.0**. Manifest constraint is Dart `^3.13.5`; source version is `0.6.0+8`.
- **Scope:** 138 Dart library files, including generated Drift code; approximately **32,215 non-generated Dart lines**; 46 `*_test.dart` files. Source/configuration baseline hashes cover 265 files. All library files were included in static analysis and structural scans; detailed review focused on entry points, ownership, data access, document/media work, and platform boundaries. This is not a claim of exhaustive dynamic verification of every branch.
- **Architecture:** feature directories with domain/data/presentation layers; Riverpod dependencies and controllers; GoRouter navigation; an `AppDependencies` bootstrap container. Some accounting/quotation/order screens issue SQL directly rather than using repositories. Extract only the interfaces needed for bounded queries/testing; a wholesale architecture conversion is not justified.
- **Startup:** `lib/main.dart:16` starts a launcher immediately; `lib/app/bootstrap/bootstrap.dart:43` initializes appearance and workspace mode, starts account services in the background, then builds local repositories. The auth wrapper does not wait for cloud readiness to enter the device workspace. Local profile synchronization performs sequential preference reads (`lib/features/profile/data/local_profile_repository.dart:13`).
- **State ownership:** Riverpod future providers are often auto-disposed, while inventory/sales controllers and `pricingWorkspaceProvider` are persistent. Generation/UID guards protect stale async results. `QuickPriceScreen` cancels its expiry timer and listener in `dispose`; session subscriptions and router listeners have cleanup. No retained-heap leak has been proven.
- **Business storage:** account-specific **sqflite** databases, schema **11**; sales, products, movements, customers, purchases, returns, expenses, registers, settings, archived duplicate PDFs. Foreign keys are enabled. Core mutations are transactional; stock and sales operations use stable references/idempotency.
- **Pricing storage:** separate **Drift / sqlite3** databases, schema **4**, through `drift_flutter` with `shareAcrossIsolates: true`. Exact rational arithmetic, immutable published versions, trigger guards, and replayable snapshots are intentional correctness mechanisms. Do not remove them to improve a benchmark.
- **Networking:** Firebase Auth/Google sign-in, optional read-only import of older account inventory from Firestore, and profile avatars. Current bootstrap uses local profile/business repositories; the presence of older Firestore repository classes does not imply live synchronization of every business operation. No application REST client, recurring HTTP poller, Firestore snapshot listener, foreground service, or background worker was found in application source. SDK-internal background behavior remains unmeasured.
- **Android:** implemented host and custom channels for notifications, profile photos, WhatsApp links, PDF share/save, and price-text sharing. Release target **SDK 36**, minimum **SDK 24**, package `com.hyner.hyner`; universal release contains ARM32, ARM64 and x86_64. Release is signed with the existing **development/debug certificate**, not a configured production release key.
- **Web:** default JS release builds successfully; Wasm dry run succeeds but a complete Wasm deployment/browser test was not performed. Conditional `open_workspace_web.dart` returns a **temporary in-memory QuickPrice preview**. The business bootstrap still contains native sqflite/file/channel dependencies; successful compilation does not prove those workflows operate in browsers.
- **iOS/desktop:** no platform host directories in this repository. Dart portability alone does not supply the Android channel implementations, platform entitlements, signing, or storage behavior on iOS. Their performance cannot be audited as implemented targets.
- **Offline/reliability:** device business work and native pricing are local-first. Web preview is intentionally transient. Error messages preserve data, uncertain-save paths reuse operation references, archived-PDF inflate output is capped at 5 MiB, settings-image imports are bounded and downscaled. These are strengths to preserve.

### Android size evidence

Artifact SHA-256 for the supplied universal APK:  
`f4c6453a8f544a709cee6d27f2871c75544c86db47a6cd273ef35edaea8e03a9`

| Component in current universal APK | ZIP/file payload MB | Interpretation |
|---|---:|---|
| ARM64 native libraries | 24.79 | Includes engine, app AOT, bundled SQLite and JNI support |
| ARM32 native libraries | 22.92 | Needed for corresponding Android userspace; not used on an ARM64-only device |
| x86_64 native libraries | 26.45 | Needed for x86_64 targets/emulators; redundant for an ARM phone download |
| DEX | 1.88 compressed; 4.11 uncompressed | Android/SDK code after the release optimizer |
| Flutter assets | 0.231 compressed; 0.383 uncompressed | Images/fonts are a minor share |
| Other resources/manifest/metadata | 0.673 payload | ZIP alignment/signatures/headers explain remaining file overhead |

ARM64 library attribution (uncompressed native entries):

| Entry | Bytes | MB |
|---|---:|---:|
| `libflutter.so` | 11,747,864 | 11.75 |
| `libapp.so` | 11,142,024 | 11.14 |
| `libsqlite3.so` | 1,765,712 | 1.77 |
| `libdartjni.so` | 131,432 | 0.131 |
| `libdatastore_shared_counter.so` | 7,784 | 0.008 |

The ARM64 `--analyze-size` artifact is **27,950,711 bytes**. The engine and app AOT entries have the **same byte lengths** as the corresponding entries in the supplied universal build. Small foreign-ABI JNI entries remain in that diagnostic APK because `--target-platform android-arm64` is not the same command as final `--split-per-abi` delivery. Thus 27.95 MB is the measured diagnostic result; final split outputs and all ABIs still require verification after approval.

Flutter AOT analysis attributes approximately:

| AOT category | Attributed bytes | Meaning |
|---|---:|---|
| Flutter package | 3,632,699 | Framework code retained by this application |
| Hyner application | 1,462,398 | Application code/data |
| `image` | 856,072 | Largest obvious optional implementation area, but required by existing image/PDF paths |
| `dart:mixin_deduplication` | 455,508 | Compiler attribution, not an independently removable feature |
| `dart:core` | 347,883 | Runtime/library attribution |
| `bidi` | 220,915 | Text-direction support; not safe to delete for size |
| `pdf` | 191,276 | Does not include every transitive/image/font cost |
| `riverpod` | 135,777 | No evidence that replacing it would be worthwhile |
| `drift` | 125,966 | Separate from the bundled native SQLite library |
| `archive` | 74,562 | Used for bounded duplicate-PDF compression/storage |

These are compiler attributions within AOT, not isolated package-removal savings; shared code/data and file overhead prevent simple addition/subtraction. Java/native Firebase costs also appear outside Dart package attribution.

**Already working:** icon tree shaking reduces Cupertino icons from 257,628 to **848 bytes**, and Material icons from 1,645,184 to **13,392 bytes** in the measured Android build. The full Manrope font is only **164,700 bytes raw / 68,042 bytes zipped**. Flutter's installed Gradle plugin sets release minification and resource shrinking on by default; inspected source: `FlutterPlugin.kt:216–219` and `FlutterPluginUtils.kt:232` in the Flutter SDK. Release builds produce shrinker outputs. Do **not** sell “enable R8/tree shaking” as a new large saving.

All heavy direct production dependencies are used in reachable app or generated plugin paths. `cupertino_icons` has no application symbol use, but its tree-shaken payload is negligible. `flutter_web_plugins` is explicitly required by generated registration. Build tools, tests, SQLite C source, and the 991 MB development `build/app/outputs` directory are not shipped wholesale in the APK. Removing development artifacts is not an end-user size optimization.

| Measurement | Result | Interpretation |
|---|---:|---|
| Current universal APK | 77.16 MB | Sideload file size |
| ARM64 unchanged-source analysis APK | 27.95 MB | Diagnostic single-target file size |
| Difference | 49.21 MB / **63.78%** | Delivery comparison only |
| AAB upload | 75,680,203 bytes / 75.68 MB | Not a download/install metric |
| Bundletool ARM64 / API 35 / en / 420 dpi | 13,426,385 bytes / **13.43 MB** | Estimated compressed device delivery |
| Bundletool ARM32 / API 24 / en / 320 dpi | 13,209,758 bytes / **13.21 MB** | Estimated compressed device delivery |
| Bundletool x86_64 / API 35 / en / 420 dpi | 13,682,406 bytes / **13.68 MB** | Estimated compressed device delivery |

Flutter distinguishes upload artifacts from device download sizes in its [app-size documentation](https://docs.flutter.dev/perf/app-size). Bundletool's [`get-size total`](https://developer.android.com/tools/bundletool) estimates wire-compressed delivery; Play's final result may differ. The estimates here use synthetic configuration files, not a claim that those phones were connected.

### Web baseline boundaries

The fresh default release build contains **44,713,723 bytes** across deployment files. That directory contains alternative renderer binaries and symbol files; a browser does **not** necessarily download all of them. `main.dart.js` is **5,142,754 raw bytes / 1,505,791 gzip-9 model bytes**. Selected bootstrap, JS, manifest, Manrope and one CanvasKit JS/Wasm pair total:

- Chromium renderer model: **10.84 MB raw / 3.67 MB gzip**.
- General CanvasKit model: **12.69 MB raw / 4.52 MB gzip**.
- WebParagraph renderer model: **9.13 MB raw / 3.01 MB gzip**.

This is an asset accounting model, not an observed cold navigation. It excludes any additional fallback-font/SDK/route requests and HTTP/TLS overhead. Renderer selection and actual content encoding vary. The generated loader defaults renderer resources to Google's versioned CDN unless configured otherwise. No production hosting headers, HAR, browser CPU profile, service-worker behavior, or live site URL was available. This web build uses the documented default command with no account-service defines; it is not evidence of a fully configured authenticated web product. Android Firebase configuration must not be reused as a substitute for a proper web registration.

### Database evidence: synthetic query plans, not Android latency

A read-only experiment against a **synthetic in-memory SQLite 3.53.4 database on macOS ARM64** recreated the application's sales/customer/product table definitions and relevant existing indexes. It contained **50,000 sales**, **5,000 customers**, and **433 bytes of line JSON per sale**. Three full-fetch repetitions were timed; the median is shown. No real customer data was accessed. This is not Android sqflite/Drift throughput, does not include platform-channel serialization or Dart replay cost, and is not an optimized before/after benchmark.

| Current query path | Rows returned before application filtering | Median host fetch | Observed query plan |
|---|---:|---:|---|
| One customer's identity candidates plus all unlinked sales | 2,510 | 51.34 ms | Full sales traversal using `sales_created` |
| Customer directory | 5,000 | 14.00 ms | Name-index scan plus temporary ordering work |
| Pending-payments repository read | 50,000 | 272.60 ms | Full sales traversal using `sales_created` |
| Scheduled follow-ups | 500 | 21.22 ms | Full sales scan and temporary sort |
| Monthly report range | 3,332 | 27.87 ms | Date-index range search; currency filtered afterward |
| All-time report range | 45,000 | 239.11 ms | Date-index range search, most rows qualify |
| Existing sales page | 31 | 0.049 ms | Index traversal bounded by `LIMIT 31` |

The report and pending paths can therefore transport tens of thousands of rows while the existing sales page transports 31. This establishes scaling shape, not a promised speedup factor. Raw sales-line text alone in the 50,000-row pending fixture is **21.65 MB**, before maps, strings, decoded lines, snapshots, and widget objects. Paged summaries could avoid most of that particular transfer; process-wide RAM savings still require measurement. SQLite explains the distinction between full scans and selective searches in its [query-plan documentation](https://www.sqlite.org/eqp.html).

### Runtime and resource observations

- `LocalReportsRepository.load` holds a transaction while it materializes rows, parses JSON, replays custom snapshots, builds record lists, and computes report structures. Under load that can prolong write serialization even though native SQL itself is asynchronous.
- `SalePriceSnapshot.validate` intentionally replays the full snapshot. `SaleDraft.validate` reaches it for seeded custom lines; the editor constructs and validates a preview during `build`. Cost grows with custom lines and rebuild frequency. No measured calculator hotspot justifies replacing `Exact` with floating point.
- `pw.Document.addPage` performs `page.generate` synchronously in installed `pdf` **3.13.1**. Its `save` later offloads low-level serialization on native targets. Merely wrapping `save` in another `compute` would miss upstream work and can introduce redundant copying/workers.
- Settings-image import already validates dimensions, decodes toward a bounded edge, disposes the image and codec, and caps stored bytes. Avatar rendering already uses resize hints. Remaining opportunities are stable preview byte identity and avoiding repeated PDF decode/resize, not indiscriminate quality reduction.
- `_databases` retains handles for every opened business UID until global `close`; `pricingWorkspaceProvider` is a non-auto-disposed family. Both are intentional caching shapes with potential long-session retention, not proof of a leak.
- `DraftWriter` serializes writes but snapshots each edit immediately and keeps an unbounded future chain. Slow storage can retain intermediate drafts. A careless timer debounce would trade away the existing durability intent.
- App notifications are event-driven; rate expiry uses a one-shot timer. Pending activity alerts use unique IDs and can grow during a long uninterrupted foreground session. Low-stock alerts already coalesce by SKU.
- Native photos are sampled to about 1024 pixels and bitmaps are recycled, which is good. However, decode/compress and content-resolver/PDF file I/O are still invoked on Android main callbacks.
- Archived PDFs are durable business records, not disposable cache. Exported temp backups and `cacheDir/share/bill-*` files are separate, reclaimable candidates with a grace period.

## Section C: Optimization Recommendations

Priorities: **P0** establishes measurements/distribution; **P1** addresses strong, material evidence; **P2** is conditional on workload; **P3** is generally deferred. Effort below is engineering time, with shared validation included more accurately at plan level.

| ID | Optimization | Expected Gain | Difficulty | Risk | Priority | Recommendation |
|---|---|---|---|---|---|---|
| OBS-001 | Device/browser performance baseline and regression scenarios | Enables valid RAM/FPS/startup/energy decisions; direct gain U | Medium | Low | P0 | First runtime gate |
| SIZE-001 | ABI-specific APKs or AAB delivery | ARM64 diagnostic 77.16→27.95 MB; AAB model 13.43 MB delivery | Low | Low–medium | P0 | Implement after approval |
| SIZE-002 | Preserve shrinkers and add comparable artifact budgets | Prevent size regressions; no new large immediate saving | Low | Low | P1 | Include |
| SIZE-003 | Investigate narrower image-codec reachability | Recoverable gain U; entire image AOT attribution only 0.856 MB | Medium–high | Medium | P3 | Prototype only if size still matters |
| SIZE-004 | Evaluate a single SQLite driver/backend | Native upper-bound opportunity 1.77 MB on ARM64; actual net U | High | High | P3 | Defer migration unless other benefits justify it |
| DB-001 | Separate dashboard summary from full reports | Remove O(all history) payload/record retention from dashboard | High | Medium–high | P1 | Highest runtime leverage |
| DB-002 | Query-specific additive indexes | Selective history/follow-up/range queries; speedup U | Low–medium | Low–medium | P1 | Verify plans before each index |
| DB-003 | Indexed customer lookup and identity-aware history | Eliminate whole-directory reads; bounded bill detail pages | Medium | Medium | P1 | Preserve duplicate/unlinked history |
| DB-004 | Bounded directories, product pickers and growing registers | O(page) UI/data instead of O(register); exact RAM U | Medium | Medium | P1 | All records remain reachable |
| DB-005 | Filter/project pending bills and follow-ups in storage | Avoid decoding already-paid/unneeded full bills | Medium | Medium | P1 | Depends on authoritative totals |
| DB-006 | Indexed Unicode prefix search | Avoid current unbounded non-ASCII inventory read | Medium | Medium | P2 | Important for Indian-language catalogues |
| CPU-001 | Move PDF layout/image preparation to bounded worker | Shorter main-isolate blocking; elapsed time/PSS U | Medium | Medium | P1 | Account for existing PDF save isolate |
| CPU-002 | Coalesce superseded queued drafts safely | Fewer snapshots/writes under backlog; no fixed percentage | Medium | Medium | P1 | No blind delayed-durability debounce |
| CPU-003 | Reuse deeply immutable verified snapshots | Less repeated replay/JSON in builds; benefit U | High | High | P2 | Only after immutability is established |
| CPU-004 | Background Android media/file work | Remove callback-thread decode/write stalls; time gain U | Medium | Medium | P1 | Preserve single-result/lifecycle safety |
| MEM-001 | Explicit scoped DB/workspace/cache ownership | Bound long-session account resource retention | Medium | Medium | P1 | Use leases/flush barriers |
| MEM-002 | Stable image-preview bytes and prepared-branding reuse | Avoid repeated base64 buffers/cache keys/decodes | Low–medium | Low | P1 | Small targeted improvement |
| MEM-003 | Memory-pressure-aware budgets | Reduce avoidable cache/worker peaks; bytes U | Medium | Medium | P2 | Measure before enabling tiers |
| UI-001 | Isolate high-frequency rebuilds and preview calculation | Reduce per-edit UI work; FPS gain U | Medium | Low–medium | P1 | Trace first; no blanket `const` campaign |
| UI-002 | Lazy large bill/form/picker children | Fewer eagerly created widgets/controllers at scale | Medium | Medium | P2 | Preserve validation/focus/accessibility |
| STOR-001 | Stream and validate large backup/export workflows | Bound large snapshot/JSON/base64 peaks | High | High | P2 | Versioned, tested compatibility required |
| STOR-002 | Expire only obsolete share/backup temp files | Reclaim accumulated generated files; bytes U | Low–medium | Medium | P1 | Never delete durable documents or active shares |
| STOR-003 | Archive metadata lookup and bounded PDF-byte lifetime | Avoid repeated archive inflate/retention on bill opens | Low–medium | Low–medium | P1 | Preserve original duplicate semantics |
| NET-001 | Resumable, bounded, account-scoped legacy import | Avoid repeated catalogue/history downloads on timeout | High | High | P1 for legacy accounts | Stage atomically; preserve conflict policy |
| NET-002 | Lazy remote initialization in device mode; fewer preference round trips | Less optional startup/network work; milliseconds U | Medium | Medium | P2 | Keep account mode/auth semantics intact |
| BAT-001 | Bound notification flush working set without dropping events | Reduce pause-time bursts/foreground retention; energy U | Medium | Medium | P2 | No new polling or background service |
| WEB-001 | Validate compression/cache/CDN/offline delivery | Encoding can shrink modeled transfer materially; live gain U | Medium | Medium | P1 for deployed web | Audit hosting before changing it |
| WEB-002 | Conditional web worker/chunk loading experiments | Reduce long browser tasks/initial code; saving U | High | Medium–high | P2 | Benchmark browsers; preserve availability |
| PLAT-001 | Explicit platform-capability boundaries/parity assessment | Prevent unsupported-path failures; no size gain claimed | Medium–high | Medium | P1 before cross-platform claims | iOS feature work requires separate scope |
| REL-001 | Release-signing/update and reproducibility controls | Preserve update/security path; no RAM gain claimed | Medium | High if mishandled | P0 before public distribution | Distribution decision, not silent key replacement |

Recommendations overlap. DB-001/003/004/005 share data projections; CPU-001/MEM-002/STOR-003 share document preparation; OBS-001/SIZE-002 share tooling. Do not add their savings or efforts independently.

## Section D: Detailed Impact Analysis

The following entries state the current evidence, proposed work, gains and cross-effects, appropriate workloads, effort, dependencies, risks, validation, and rollback for every ID. Numeric device improvements remain unknown unless explicitly measured above.

### OBS-001 — Establish a representative measurement harness

**Problem/evidence/root cause:** No connected device, frame/heap/CPU traces, integration benchmark suite, or production HAR was available. Unit/widget checks in `test/` do not measure phone hardware. The baseline is correctness-tested but not performance-qualified.

**Proposal and expected impact (U):** Add repeatable profile/release scenarios for startup, ledger navigation, calculator edits, PDF generation, import and backup. Record first-frame and useful-screen times, UI/raster percentiles, PSS plus Dart/native/graphics memory, allocations/GC, transfer bytes and energy. This has no direct size/RAM gain; it prevents harmful speculative work. Instrumentation has overhead and must be disabled or separately accounted for in release measurements.

**Use/effort/dependencies:** All platforms; especially slow CPUs, 2 GB Android, large ledgers and long sessions. Approximately 1–2 engineering days for initial harness, plus physical-device runs; access to the test devices is required.

**Risk and mitigation:** Nonrepresentative fixtures, warm caches and instrumentation overhead can produce false wins. Use identical builds/datasets, thermal state, battery state and iteration counts; compare distributions rather than a single best run. Capture no customer PII.

**Validate/rollback:** Follow the protocol in Section F. Store sanitized baseline summaries and tool versions. Roll back instrumentation without touching business data; retain benchmark scripts/results for comparison.

### SIZE-001 — Use architecture-aware distribution

**Problem/evidence/root cause:** `tool/build_android.py:44` calls the universal release build; ZIP inspection finds three engine/AOT/SQLite sets. The 77.16 MB APK contains 74.17 MB of native payload. The unchanged-source ARM64 diagnostic is 27.95 MB. AAB delivery estimates are 13.21–13.68 MB for the three tested configurations.

**Proposal/expected gain (M diagnostic, H delivery):** After approval, supply verified split APKs for each supported ABI or use an AAB for store delivery. Expect roughly 28 MB ARM64 sideload packaging with current features. This is the principal demonstrated size opportunity. Do not add AAB and split-APK savings.

**Positive/cross-effects:** Smaller transfer and potentially less stored package payload. **No intrinsic Dart heap, rendering, battery or engine-startup improvement is established**; Android already selects native code for its runtime ABI. Store/device installation layouts differ.

**Drawbacks/use/effort:** Sideload users must receive a compatible ABI; 2 GB phones may have 32-bit userspace even with a 64-bit CPU. Keep ARM32 available, and retain a universal fallback if needed. Effort 0.5–1 day plus architecture installation checks. AAB requires a store/signing distribution decision; it cannot be sideloaded directly.

**Validation/rollback:** Confirm manifest, certificate, ABI contents and current feature markers; install/update over the prior certificate on each ABI without clearing data. Keep the original universal APK and release recipe. Changing delivery must not change package ID, auth registration or signing key.

### SIZE-002 — Keep existing shrinkers and introduce size budgets

**Problem/evidence/root cause:** `android/app/build.gradle.kts` does not explicitly state shrink flags, but installed Flutter Gradle code enables R8/resource shrinking by default. Build logs prove icon subsetting is active. Future build changes or dependencies can silently regress this working baseline.

**Proposal/expected gain (H prevention, U future bytes):** Record universal, ABI and estimated store-delivery budgets with `--analyze-size` package attribution. Preserve current R8 rules and icon tree shaking. Compare only like-for-like releases with the same ABI/toolchain/configuration. No present “enable shrinking” saving is claimed.

**Effects/trade-offs/use:** Prevents binary bloat and tracks engine versus app changes; useful for all releases. CI build/storage time increases, and SDK upgrades can legitimately alter baselines. Budget exceptions must be reviewed rather than blocking security updates blindly. Font subsetting of Manrope could recover only a fraction of 68 KB zipped and risks language glyph loss; it is not a priority. Removing dev dependencies will not recover shipped bytes.

**Effort/dependencies:** 0.5–1 day after OBS-001/SIZE-001 define artifact types.

**Validation/rollback:** Keep size JSON and checksums, verify runtime reflective/plugin paths under R8, and exercise sign-in, picker, print and share flows. Relax the budget or revert the CI check if invalid; do not turn off optimization or strip keep rules as a shortcut.

### SIZE-003 — Investigate image-codec reachability, without removing supported formats

**Problem/evidence/root cause:** `BillPdfService._safeImage` at `lib/features/sales/data/bill_pdf_service.dart:385` calls generic detection/decode; `settings_image_helper.dart:49` uses generic metadata detection. AOT attributes 856,072 bytes to `image`. The installed PDF package also references generic image decoding, so changing only application calls may save nothing.

**Proposal/gain (T/U):** Only if packaging is insufficient, prototype narrower supported ingress/decoder paths and inspect a fresh AOT diff. The entire 0.856 MB attribution is an upper bound on that category, not a recoverable saving. Actual gain may be zero; no credible multi-megabyte promise is available.

**Benefits/drawbacks/use:** Could modestly reduce Dart code and some decode work. Specialized paths can break legacy branding formats, alpha, EXIF orientation or printed output. Forking PDF/image libraries adds long-term maintenance and compatibility costs. Best suited to a hard store-size constraint after lower-risk work, not the initial ≤50 MB goal.

**Effort/dependencies:** 1–3 days for a feasibility experiment, more for a maintained implementation. Audit accepted legacy formats and transitive decoder reachability first; do not introduce a fork without a revised decision.

**Validation/rollback:** Diff AOT; test PNG/JPEG/WebP, transparency, corrupt/bounded images, legacy fixtures and all PDF layouts. Require meaningful measured saving with no lost format support. Revert codec changes and dependency patches if not beneficial; stored originals stay intact.

### SIZE-004 — Evaluate database-driver consolidation only with a separate migration case

**Problem/evidence/root cause:** `open_pricing_database.dart:23` opens Drift's bundled sqlite3 while business repositories use sqflite. `third_party/sqlite/README.md` documents why a pinned SQLite is bundled. ARM64 `libsqlite3.so` is 1,765,712 bytes; this is not proof it is redundant.

**Proposal/gain (T/U):** Evaluate using one backend only if long-term database architecture also benefits. Removing the bundled native library has at most a 1.77 MB raw per-ABI opportunity before replacement costs. System SQLite version/feature differences and Dart adapters can erase or reverse the gain.

**Effects/trade-offs/use:** One driver may simplify connection policy, but moving business data to bundled SQLite retains the library; moving pricing to system SQLite must preserve UPSERT behavior, triggers, foreign keys and immutable versions across API 24+. Migration, thread-model and web implications are substantial. Database files/ledgers must not be merged merely to reduce library count.

**Effort/dependencies:** 5–10+ days including broad migration/rollback testing; high risk. Not included as an unconditional action in any plan.

**Validation/rollback:** Benchmark the alternative in an isolated branch and test every supported schema/API, cold open, concurrent transactions, publication guards and crash recovery. Require complete private backups of both stores and a forward-compatible rollback build. Do not remove/overwrite old databases until verified; no size target requires this experiment today.

### DB-001 — Separate lightweight dashboard summaries from detailed reporting

**Problem/evidence/root cause:** `dashboard_screen.dart:21` requests all-time `BusinessReport`; `local_reports_repository.dart:13` loads historical rows, parses every line and retains sales/purchase/expense record lists while holding a transaction. The synthetic all-time query fetched 45,000 rows; the existing sales page fetched 31.

**Proposal/gain (H shape, U timing/RAM):** Add a dashboard-specific repository result containing counts, exact totals and bounded chart buckets. Introduce authoritative per-bill totals/projections or a transactionally maintained summary if profiling warrants it; detailed record pages and PDF exports remain separate. A correctly maintained summary can make dashboard reads independent of ledger length, apart from bounded chart ranges. A simple SQL SUM over the whole ledger reduces payload but is still O(N); do not call it constant-time.

**Effects/trade-offs/use:** Less main-isolate JSON/replay work, memory and transaction duration; most useful to long-lived/large/offline businesses and slow phones. Added writes/indexes/backfill increase storage and complexity. SQL integer aggregation can overflow on sufficiently large totals; keep exact BigInt-safe accumulation/checks and never introduce floating monetary arithmetic.

**Effort/dependencies:** 3–6 days plus migration/device validation. Define summary contracts before DB-005 and paged financial totals. Preserve custom-line authoritative totals, paid-zero legacy semantics, costs and mixed currencies.

**Validation/rollback:** Compare summaries with the existing verified computation on ordinary/custom/rounded/tax/partial/refund/legacy fixtures, crash halfway through backfill, and test concurrent writes/restores. Keep raw snapshots and the legacy computation as a guarded fallback. Use a schema-compatible rollback build; do not downgrade database versions.

### DB-002 — Add only indexes demonstrated by actual query plans

**Problem/evidence/root cause:** Existing schema has sales date indexing but no customer/follow-up index; follow-up selection scans/sorts sales. Reports filter currency plus date. `local_business_database.dart:74–134` and `local_sales_repository.dart:52–122` identify the paths. The experiment proves the current follow-up scan and customer-history traversal, not a measured indexed speedup.

**Proposal/gain (H selective access, U latency):** Test candidate composite/partial indexes matching customer/date/id, non-null follow-up/date/id, and currency/date/id for reports. Consider customer name/id and product archived/name/sku collations only when plans justify them. Small full-table scans may be appropriate; avoid indexing every column.

**Effects/trade-offs/use:** Potentially fewer examined rows and sorts with large ledgers; offline latency and CPU can improve. Indexes consume disk, slow inserts/updates, and take time/temporary space to build. An index cannot fix fetching every qualifying row or an all-time report by itself.

**Effort/dependencies:** 0.5–1.5 days plus migration checks. Candidate SQL must match real order/collation and SQLite versions; DB-003 may require a redesigned identity query first.

**Validation/rollback:** Compare EXPLAIN plans and read/write timings on tiny/large/skewed data, include first-run migration space/time, and verify pagination ties. Add indexes in an approved additive migration. Drop only new indexes in a forward migration or retain them while reverting query code; never lower user_version or drop business columns to roll back.

### DB-003 — Use point customer reads and indexed, paged identity-aware history

**Problem/evidence/root cause:** `customers_controller.dart:20` lists the entire directory to find one ID. `LocalSalesRepository.forCustomer` at `local_sales_repository.dart:52` reads all customers, normalizes every identity, then selects duplicate IDs plus all unlinked sales before Dart filtering. In the fixture one target caused 2,510 sales candidates to cross the query boundary.

**Proposal/gain (H):** Add `getById` and indexed persisted canonical/alias identity lookup. Resolve duplicate historical IDs without rewriting saved bills, then page display records while separately returning complete totals. Query or repair unlinked identities incrementally using compatible normalized keys. Replace O(all customers + all unlinked sales) scans with bounded lookups and O(relevant history) work; exact milliseconds/PSS are U.

**Effects/trade-offs/use:** Faster frequent customer navigation and lower data retention, especially with duplicate/legacy records. More identity metadata and backfill rules are required. Incorrect normalization could merge different people or omit historical bills, a serious data/privacy regression.

**Effort/dependencies:** 2–4 days; depends on DB-002 and identity/aggregate contracts. Preserve current name+phone identity rules, original IDs, currencies, historical contact snapshots and all prior bills.

**Validation/rollback:** Test duplicate IDs, whitespace/format differences, invalid/missing phone, changed names, same name/different number, unlinked and dangling records, account switches and stable page ties. Compare full totals with the current method. Keep legacy resolver as fallback; rollback queries without deleting alias metadata or rewriting bill snapshots.

### DB-004 — Bound directory, picker, WhatsApp and manual-register data

**Problem/evidence/root cause:** `local_customer_repository.dart:11`, `local_expense_repository.dart:21`, and `whatsapp_screen.dart:17` materialize complete lists. WhatsApp walks every product page before building a dropdown and repeatedly searches customers per selected ID in `_startCampaign`. Accounting/quotation/order providers cap at 100 and then eagerly build columns; adding only a cap would hide records, not solve completeness.

**Proposal/gain (H structure, U bytes):** Add cursor-backed searchable pickers/directories and paged register APIs with separate full totals. Persist campaign selection as IDs or an account-scoped selection specification and resolve only the next recipient. Use indexed maps for O(N) selection resolution instead of N repeated linear searches. Every record remains reachable; “all customers enabled/selected” semantics and opt-out checks remain intact.

**Effects/trade-offs/use:** O(page) live detail objects can replace O(register); useful for large catalogues, long sessions and low RAM. Additional page fetches increase small local queries; poorly scoped totals or changing selections can be misleading. Added loading controls alter presentation and need approval/accessibility tests.

**Effort/dependencies:** 2–5 days shared with DB-003/005 and UI-002. Define stable sorting, snapshot/selection semantics and repository contracts first; do not load all pages behind a paged UI.

**Validation/rollback:** Verify counts/totals across page boundaries, all-recipient behavior, per-customer exclusions, concurrent edits, account isolation, keyboard/screen-reader navigation and empty/error states. Restore old UI/query adapters as a fallback; retain data and selection state without destructive conversion.

### DB-005 — Filter and project open bills before materializing sale models

**Problem/evidence/root cause:** `local_sales_repository.dart:99` reads and decodes all sales for remaining payments; follow-ups also instantiate full verified bills before filtering. In the fixture, pending selection fetched 50,000 rows although only a subset is unpaid. Replaying each historical custom quote compounds the cost.

**Proposal/gain (H shape, U timings):** Store/query authoritative exact total/paid/remaining projections and request lightweight open-bill rows, then load the full immutable bill only when opened. Filter and page at SQL level using indexes. Page-level totals must not replace complete outstanding balances. Status alone is insufficient without reconciling legacy/custom-bill semantics.

**Effects/trade-offs/use:** Avoid paid-bill JSON transport and replay; helps older businesses with many closed bills and few open ones. Derived data can drift if payment/restore/backfill paths are missed. Additional storage and write logic are the main costs; no remote network dependency is introduced.

**Effort/dependencies:** 1–3 days after DB-001's projection semantics and DB-002; shared implementation/testing may reduce effort.

**Validation/rollback:** Compare partial/full/pay-later/legacy paid-zero states, idempotent payment retry, tax/rounding snapshots, reminder removal and simultaneous payment changes. Update projections in the same transaction as source writes. Revert to full-model filtering if consistency checks fail, preserving projection columns and database version.

### DB-006 — Preserve Unicode search semantics with a bounded indexed path

**Problem/evidence/root cause:** `local_inventory_repository.dart:49–89` detects non-ASCII name searches, drops the SQL LIMIT and filters lowercased names in Dart. An Indian-language query can therefore materialize the whole catalogue despite the normal 30-item paging API.

**Proposal/gain (H):** Add a tested normalized search key/index or another bounded search strategy matching existing prefix semantics, preserving display names. Keep cursor ordering consistent with the normalized key. Current full-catalogue allocations can become page-bounded; the actual search-time gain is U.

**Effects/trade-offs/use:** Most relevant to Marathi/Hindi/multilingual product names and large catalogues; improves memory and CPU predictability. Unicode case folding, normalization, locale and tie ordering are subtle. A simplistic ASCII-only collation or tokenized FTS search can change results and is not an acceptable silent replacement.

**Effort/dependencies:** 1–3 days including key backfill and migration; coordinate with DB-002/004. No new dependency is assumed necessary until normalization requirements are verified.

**Validation/rollback:** Test Indic scripts, composed/decomposed accents, Turkish casing, emoji, escaped `%`/`_`, mixed scripts, duplicate names and non-ASCII pagination. Compare complete results with current behavior. Keep original names and a temporary compatibility search; revert query/key usage without deleting names or changing stored business identities.

### CPU-001 — Offload complete document preparation without redundant isolates

**Problem/evidence/root cause:** `bill_pdf_service.dart:20` calls `addPage` and `_safeImage` before save; `report_pdf_service.dart` constructs tables/charts similarly. Installed `pdf` 3.13.1 generates page layout synchronously in `widgets/document.dart:118`; low-level `PdfDocument.save` already uses `pdfCompute` on native platforms.

**Proposal/gain (H isolation, U speed/RAM):** Measure and move full layout, safe image preparation and applicable archive compression to one bounded worker job with an immutable input DTO. Avoid constructing the whole document on the UI isolate then copying it, and avoid spawning a second serialization worker unnecessarily. Cache only suitably versioned prepared branding. Native UI blocking should fall for heavy documents; total completion time can increase through startup/copy overhead.

**Effects/trade-offs/use:** Helps large bills/reports and weak CPUs; not necessarily tiny documents. Worker heaps/message copies can increase peak memory and CPU overlap. Web `compute` does not provide a separate worker; use chunk/yield or a proper browser-worker design there.

**Effort/dependencies:** 2–4 days with MEM-002/STOR-003, audit library APIs and cancellation/account guards first. No unbounded parallel PDF jobs.

**Validation/rollback:** Time UI isolate stages separately from serialization, record frame timings/PSS, compare every page/text/amount/colour/logo/signature and platform save/share path. Test corrupt inputs, cancellations and UID changes. Retain current synchronous path as a flaggable fallback; no financial data format change is necessary.

### CPU-002 — Coalesce superseded draft writes under backpressure

**Problem/evidence/root cause:** `workspace.dart:60` clones a complete draft for every `DraftWriter.write`; `quickprice_screen.dart:89` triggers it on session changes, and setup screens do similar work. A slow write leaves a chain of intermediate snapshots alive.

**Proposal/gain (H bounded queue, U frequency/latency):** Use one active write plus one replaceable latest pending snapshot per key, preserving explicit flush semantics, revision guards and failure reporting. Serialize at a well-defined immutable boundary. Under an edit burst with backlog, N writes can approach one active plus one final pending write; no backlog means little or no gain. Do not promise a universal percentage.

**Effects/trade-offs/use:** Fewer database writes/canonicalizations and less queue memory can help weak storage, long forms and battery. Intermediate draft states are superseded by the same final state. A blind 250 ms timer debounce creates a new loss window and is not included. Pending final state must be awaited on explicit save/navigation/checkout and lifecycle flush where available; abrupt process death must not be worse than today's queued writes.

**Effort/dependencies:** 1–2 days; coordinate with MEM-001's close policy.

**Validation/rollback:** Stall/fail storage, type rapidly, switch accounts/keys, pause/navigate and reopen; confirm last-state persistence, error recovery, ordering and no edit-after-publish bypass. Compare submitted writes and maximum pending snapshots. Restore FIFO writer implementation if guarantees fail; stored format remains unchanged.

### CPU-003 — Avoid repeat snapshot reconstruction only after deep immutability

**Problem/evidence/root cause:** `sale_price_snapshot.dart:19,124`, `estimate_builder.dart:75,426`, and `sale_editor_screen.dart:555` repeatedly serialize, replay and validate snapshots. `EstimateLine.product` reparses canonical JSON on access. The current result object exposes nested state; the repeated validation therefore has a real correctness purpose.

**Proposal/gain (T/U):** Introduce deeply immutable verified representations and cache display/projection fields within the same verified object lifecycle. Keep full verification at load/import/save/publish boundaries and wherever mutable input can enter. Only then remove proven redundant reconstruction inside a single build. Exact rational arithmetic and snapshot bytes remain authoritative.

**Effects/trade-offs/use:** Potentially substantial for 100-line custom estimates and repeated form edits; no hotspot time has been measured. Retained caches can raise steady-state memory. Incorrect trust reuse could accept modified prices or stale rate versions; this is a high-impact regression risk.

**Effort/dependencies:** 3–5 days plus adversarial tests after OBS-001/UI-001 identify material cost. Depends on a defensible immutability design, not a `validated=true` flag.

**Validation/rollback:** Preserve tamper/replay/version/tax/unit/rounding tests, mutate external input copies, and compare canonical bytes and totals. Measure allocations and edit latency. Keep boundary verification and a fallback replay path; revert caching if gains are small or mutation safety cannot be demonstrated.

### CPU-004 — Move Android file/media work away from the activity thread

**Problem/evidence/root cause:** `MainActivity.kt:174–211` writes selected PDF destinations and calls `saveProfilePhoto` from `onActivityResult`; `shareBillPdf:215` writes files in the method handler; `saveProfilePhoto:249` performs sampled decode and JPEG compression synchronously. The sampling/recycle safeguards are good, but do not make those operations non-blocking.

**Proposal/gain (H threading, U timings):** Use a bounded executor/coroutine appropriate to the existing host, perform I/O/decode off the Android main thread, and post exactly one channel result back on the main thread. Preserve current picker, URI permissions, error codes and one-operation guards. Do not add a persistent background service.

**Effects/trade-offs/use:** Fewer native UI stalls/ANR opportunities with slow document providers or photos. End-to-end I/O is not inherently faster. Pending buffers can remain alive longer, and activity destruction/cancel paths become more complex. Avoid parallel copies of 25 MB PDFs.

**Effort/dependencies:** 1–2 days plus native-device tests; CPU-001 is complementary, not a replacement.

**Validation/rollback:** Test slow/cloud-backed content providers, cancellation, rotation/recreation, backgrounding, unavailable apps, insufficient disk and repeated taps. Inspect Android main-thread trace and memory. Revert the host handler implementation while retaining the old method-channel contract and generated files; no schema/signing change is required.

### MEM-001 — Give account workspaces and retained caches explicit ownership

**Problem/evidence/root cause:** `workspace_quickprice_screen.dart:18` defines a persistent provider family; its `onDispose` close hook is not triggered just because a page stops watching. `LocalBusinessDatabase._databases` at `local_business_database.dart:18` retains every opened UID. Inventory/sales state also accumulates loaded pages. This is a potential retained working set, not a measured leak.

**Proposal/gain (H bounds, U bytes):** Define workspace leases or short bounded reuse, close idle account databases when no operation/route owns them, bound retained page windows while permitting reload, and invalidate stale account caches deliberately. Use existing cleanup hooks but ensure final writes/imports/checkouts are settled before close.

**Effects/trade-offs/use:** Benefits repeated account switches, frequent navigation and long sessions. Reopening databases can add latency/IO and rerun pricing guards; overly eager auto-dispose can break draft durability or close a workspace still used by nested routes. Preserve device/account separation and don't close on every temporary background transition blindly.

**Effort/dependencies:** 1–3 days with CPU-002; test app-lifetime auth-wrapper ownership separately from page resources.

**Validation/rollback:** Run repeated account/navigation cycles, inspect live providers/DB connections/retained snapshots after GC, and prove pending writes complete once. Use a conservative bounded cache with fallback to prior app-lifetime ownership if close races occur. Never delete a database as a memory optimization.

### MEM-002 — Reuse stable prepared image bytes with correct invalidation

**Problem/evidence/root cause:** `_SettingsImagePreview` in `settings_screen.dart:959` base64-decodes inside build and creates `MemoryImage` from new byte instances. The form rebuilds while editing colours. `BillPdfService._safeImage:385` repeatedly decodes/resizes the same branding for document generations. Existing import limits and image dispose/resize hints are already good.

**Proposal/gain (H churn reduction, U total RAM):** Decode once per immutable encoded value/revision, keep stable preview bytes, and reuse bounded prepared branding per settings version/job. Dispose/evict on account/settings changes. Preserve full output quality and EXIF/alpha handling; do not shrink logos arbitrarily.

**Effects/trade-offs/use:** Less transient buffer churn, image-cache-key churn and repeated CPU work; useful for branding-heavy bills and editing settings. A cache increases retained bytes until eviction, and stale keys could show another account's logo or old colours. The low image count means process-wide savings may be small.

**Effort/dependencies:** 0.5–1.5 days; coordinate with CPU-001 and MEM-001.

**Validation/rollback:** Compare decode counts, allocations/cache size, same-value rebuilds, replace/remove logo, corrupt legacy data, account switches, PDF visual output and large-text layouts. Keep cache small and revision-scoped. Revert caching and let existing decode paths run; persisted branding bytes need not change.

### MEM-003 — Use observed pressure and working sets, not RAM tiers alone

**Problem/evidence/root cause:** No app-specific pressure handling or image-cache budget is configured. Flutter's default image cache is a maximum, not proof that it is full; this app has few large on-screen images. Source shows much stronger unbounded-data risks than an image-heavy feed.

**Proposal/gain (T/U):** First bound queries, queues and concurrent jobs for all devices. If measurements justify it, add conservative native low-RAM/pressure signals and Flutter pressure handling to evict only recreatable caches, limit prepared-document concurrency and adjust page/prefetch budgets. Essential calculations, bill content, accessibility and offline data remain identical.

**Effects/trade-offs/use:** Can reduce avoidable peaks on constrained/contended devices. Smaller caches may trigger extra decodes, I/O or avatar downloads and make navigation slower; memory pressure also occurs on 8 GB devices. Total RAM is not a CPU/GPU benchmark or available per-app budget. Do not globally clear live images on every screen change.

**Effort/dependencies:** 1–3 days after OBS-001/MEM-001; use hysteresis, bounded changes and a fallback to default behavior.

**Validation/rollback:** Record Dart/native/graphics/PSS and live image counts during pressure/background cycles on actual 2/4/8 GB devices. Verify cache misses, battery and accessibility, not just a lower heap chart. Disable adaptive policies independently if they create thrashing; never reclaim durable records.

### UI-001 — Localize rebuilds and expensive previews where traces show cost

**Problem/evidence/root cause:** `QuickPriceScreen._changed` at `quickprice_screen.dart:89` calls page-level `setState`; the products getter filters/rebuilds categories, and form previews rebuild surrounding controls. `sale_editor_screen.dart:555` validates all preview lines inside build, including replayable custom quotes. The dashboard has one small `IntrinsicHeight` metrics row, not evidence of pervasive pathological layout.

**Proposal/gain (H less repeated work, U FPS):** Separate changing price/input/result subtrees, use Riverpod selectors or listeners at appropriate boundaries, memoize immutable product options, and calculate preview results from explicit state changes instead of repeated build traversal. Preserve immediate feedback. Optimize the small intrinsic row only if layout tracing identifies it.

**Effects/trade-offs/use:** Best for rapid edits and many custom lines; fewer widget constructions/allocations and less replay can reduce frame work. More derived state introduces invalidation bugs and complexity. Blanket `const`, RepaintBoundary, disabled animations or state-library replacement are not justified substitutes for tracing.

**Effort/dependencies:** 1–3 days after OBS-001, coordinate with CPU-003. Existing sliver-based sales/inventory and lazy estimate list are strengths to keep.

**Validation/rollback:** Track rebuild counts and UI/raster timings on the same edit/scroll script; compare amounts, input validation, focus, text scaling, screen-reader order and reduced-motion behavior. Revert component boundaries/derived caches if stale UI appears; business snapshots and routes remain unchanged.

### UI-002 — Make remaining growing form and picker children lazy

**Problem/evidence/root cause:** `PageContent` at `page_content.dart:3` receives a prebuilt child list. Sale lines and many nested fields are created eagerly in `sale_editor_screen.dart`; `sale_product_picker.dart:162` uses an eager ListView child list. Some manual registers build columns. Conversely `EstimateScreen` already uses `ReorderableListView.builder` and limits estimates to 100 lines.

**Proposal/gain (H object-count bound, U timing):** Use lazy builder/sliver sections for genuinely large child collections, with stable item keys and deliberate controller/model ownership. Keep fixed small settings pages simple. Page backing data as well as widgets; lazy rendering alone does not release full datasets.

**Effects/trade-offs/use:** Helps long bills and extensively loaded pickers, not small ordinary forms. Offscreen form fields may not mount, so naïve `FormState.validate()` can miss errors. Focus, scrolling to errors, keep-alive state and accessibility can regress.

**Effort/dependencies:** 1–3 days with DB-004 and UI-001. Model-level validation must remain authoritative for all items, including those never built.

**Validation/rollback:** Test offscreen invalid lines, controller cleanup/reorder/removal, saved values, keyboard traversal, 320 dp at large text, screen readers and scroll restoration. Compare widget counts/frame timings. Revert to eager presentation for bounded cases if state safety or benefit is inadequate; never truncate a bill.

### STOR-001 — Bound backup peaks while preserving complete recoverable snapshots

**Problem/evidence/root cause:** `local_business_database.dart:250` reads every table into one snapshot. `backup_service.dart:13` builds an indented JSON string; PDF BLOB export adds base64. Restore uses `withData: true`, UTF-8 decoding and JSON parsing before validation. There is no total backup byte bound before decode, and multiple representations can coexist.

**Proposal/gain (H peak-shape improvement, U absolute RAM):** Design streaming/chunked export/import with consistent-snapshot semantics, bounded per-record/blob validation, progress/cancellation and an explicitly versioned format. Stage/verify restore before replacing live data. Keep reading prior backup versions. Existing valid large backups must remain restorable through a bounded path rather than being rejected by a new arbitrary cap.

**Effects/trade-offs/use:** Important for years of sales/PDF archives and low RAM; may reduce giant string/map/base64 peaks and pause time. More complex consistency, staging-disk and format compatibility requirements; longer read transactions can block writes. Backups currently exclude native pricing databases/preferences/profile media; do not present current export as a complete rollback backup of the whole app.

**Effort/dependencies:** 3–6 days, approval of backup-format/UX details, and comprehensive fault injection. Separate business backup scope from any broader recovery feature.

**Validation/rollback:** Test large and legacy backups, malformed/truncated input, disk full, cancellation, checksum/account mismatch and process death. Preserve live ledgers on failure. Offer compatible export until new readers are deployed; retain verified old backup files and a schema-compatible restore/rollback build.

### STOR-002 — Reclaim obsolete generated temporary files safely

**Problem/evidence/root cause:** `MainActivity.kt:219–224` creates a new `cacheDir/share/bill-*` PDF per share; `backup_service.dart:16` creates timestamped temp backups. No application TTL cleanup for these paths is present. Actual accumulated bytes on a device are U; Android may reclaim cache itself.

**Proposal/gain (H reclaimable category, U bytes):** Apply a bounded, infrequent cleanup policy only to app-generated obsolete temp share/backup files. Use a generous grace period and explicit active-file tracking. Keep exports selected in user document storage and `bill_documents` durable archives untouched.

**Effects/trade-offs/use:** Helps frequent PDF sharing and long sessions/storage-constrained phones. Immediate deletion after launching WhatsApp is unsafe: the receiving app can read the URI later. Directory scans cost I/O; running them on every frame/resume would undermine efficiency. A conservative lifecycle/size-triggered worker is preferable to polling.

**Effort/dependencies:** 0.5–1.5 days, native CPU-004 can share the file worker.

**Validation/rollback:** Simulate delayed receiving-app reads, canceled shares, paused app, fresh/old temp files, insufficient disk and user-selected exports. Verify only known file prefixes/locations are removed. Disable cleanup if interoperability fails; previously shared transient files cannot be recreated automatically, so validate grace policy before rollout.

### STOR-003 — Read archive metadata before inflating or retaining PDF bytes

**Problem/evidence/root cause:** `sale_detail_screen.dart:99` reads/decompresses the duplicate into `_duplicate` on each detail state initialization, including state replacements after payment changes. Missing duplicates generate a document then read it back. `local_bill_document_repository.dart:14` has only a byte-returning lookup. `bill_document_codec.dart` already has bounded 5 MiB validation and conditional level-9 compression.

**Proposal/gain (H reduced reads, U bytes/time):** Add an archive-exists/metadata path, single-flight durable generation per sale, and load bytes only when exporting the duplicate. Release/reuse buffers within a documented small job/cache budget. Preserve the first archived duplicate and current original-sharing behavior. Do not recompress or regenerate every archive without measured benefit.

**Effects/trade-offs/use:** Avoid unnecessary inflate/retained bytes on frequent bill views and payments. Deferring the byte read shifts latency to duplicate export; a missing archive must still be durably created under the existing contract. Caches of shared originals need settings/payment/draft version keys, not just sale ID.

**Effort/dependencies:** 0.5–1.5 days with CPU-001/MEM-002. PDF inner streams may already be compressed; benchmark archive level changes before claiming storage savings.

**Validation/rollback:** Verify creation once, missing/corrupt archives, compression bounds, repeated payments, image/settings changes and export equivalence. Preserve immutable duplicate bytes. Revert repository access policy without migrating or deleting archived PDFs.

### NET-001 — Make large legacy imports resumable without weakening consistency

**Problem/evidence/root cause:** `_tryImportLegacyInventory` and `_importLegacy` at `local_inventory_repository.dart:403,435` deduplicate active imports and apply a one-minute retry cooldown, which is good. But the importer fetches all active/archived products and all movement pages into memory before one transaction, using a two-second overall timeout. Firestore reads explicitly use `Source.server` (`firestore_inventory_repository.dart:81`). Large accounts can fail and restart the same work. No real import request count/traffic was measured.

**Proposal/gain (H failure-mode reduction, U bandwidth):** Persist account-scoped cursors/staging records and resume bounded pages; atomically promote a verified complete import or use a precisely specified per-product commit protocol. Preserve skip-existing-local-product/history rules and owner checks. Make retry/backoff aware of progress/network state without adding continuous sync or polling.

**Effects/trade-offs/use:** Can reduce repeated downloads, allocations, timeout frustration and radio/CPU work for legacy accounts or poor connections. Staging increases storage and recovery complexity; partial promotion or a stale UID can corrupt/leak data. Server reads and permission verification must not be replaced with an assumed trusted stale cache.

**Effort/dependencies:** 3–6 days plus migration/fault tests; requires representative legacy fixtures and an approved state machine.

**Validation/rollback:** Interrupt every page/phase, switch UID, deny permissions, create conflicting local products, repeat operations, and inspect requested pages/bytes. Maintain existing transactional fallback where feasible. Disable resumption/promotion and retain live local data if correctness fails; garbage-collect only proven abandoned staging data.

### NET-002 — Avoid optional device-mode startup work and redundant preference reads

**Problem/evidence/root cause:** `bootstrap.dart:43` starts `_accountServices` before persisted mode is known. It does not block device startup on Firebase, but may still initialize optional remote services. Appearance, mode and profile reads create multiple preference round trips (`local_profile_repository.dart:13`). Firebase's native auto-initialization can occur independently of Dart, so Dart deferral alone may not remove all startup cost.

**Proposal/gain (T/U):** Measure startup stages, consider lazy account services when an explicit device workspace is selected, and batch/cache immutable preference reads where the API supports it. Do not delay account session restoration or sign-in requests without a defined equivalent contract. No milliseconds/network-byte improvement is measured.

**Effects/trade-offs/use:** Could help offline/device-only launches and reduce optional requests. First account use may become slower; changing native Firebase initialization incorrectly can break auth/providers. Extra state caching risks stale preferences across account updates.

**Effort/dependencies:** 1–3 days after OBS-001; platform-specific auto-init behavior and profile synchronization require review. Retain current immediate launcher and existing timeout/error recovery.

**Validation/rollback:** Test device/account/signed-out cold and warm starts, offline transitions, delayed Firebase, existing Google sessions and preference failures. Count initialization/network calls and compare useful-screen latency. Restore current eager-background setup if gains are negligible or account behavior regresses; keep storage keys and auth identity unchanged.

### BAT-001 — Bound event-notification retention and lifecycle flush work

**Problem/evidence/root cause:** `local_notification_service.dart:13,54,105` stores notifications in an in-memory map; activity IDs are unique, while low-stock IDs already coalesce. `_flush` sends all pending events when the app becomes inactive/paused. There is no periodic poller or worker to remove. Energy and queue growth are U on real devices.

**Proposal/gain (H bounded work, U energy):** If long-session tests show growth, use bounded in-memory batches with durable overflow or another lossless queue, and bounded lifecycle flushes. Preserve every required alert and permission setting. Summarizing/dropping alerts would change visible behavior and requires separate explicit approval. Do not add a permanent service or periodic wakeups.

**Effects/trade-offs/use:** Helps high-event foreground sessions and reduces pause-time bursts/retained strings. Persistence introduces writes, so small sessions may consume more energy, not less. Failed/duplicate delivery and account/privacy scoping need an explicit policy.

**Effort/dependencies:** 1–2 days after OBS-001; share scoped storage/worker ownership with MEM-001/CPU-004 where appropriate.

**Validation/rollback:** Stress queued events, denied notifications, rapid pause/resume, process restart and repeated low-stock changes. Measure queue depth, main-thread work and scenario energy. Restore current event-only queue if the durable approach costs more or changes behavior; do not silently discard persisted undelivered events.

### WEB-001 — Measure and configure real web transfer/cache/offline delivery

**Problem/evidence/root cause:** `web/index.html` loads the generated bootstrap with no custom loader policy; the loader uses a versioned renderer CDN by default. The fresh deployment directory is 44.71 MB, but a modeled first-load subset is 3.01–4.52 MB gzip. No hosting headers/HAR establish actual compression or cache effectiveness.

**Proposal/gain (H encoding arithmetic, U live gain):** First capture requests on supported browsers. Configure compression for JS/Wasm/text and correct MIME types; cache versioned assets appropriately while keeping bootstrap/HTML updateable. Evaluate self-hosted renderer assets for controlled/offline delivery, with required fallbacks intact. Avoid serving all renderer variants eagerly or preloading every route.

**Effects/trade-offs/use:** Most valuable on poor networks and repeat visits. Compression uses server CPU; wrong immutable-cache keys can serve old app code against new manifests. CDN removal can worsen latency; self-hosting alone does not create offline persistence. Existing transient preview behavior and authenticated account security must remain explicit.

**Effort/dependencies:** 1–3 days once a deployment/browser matrix is available. Hosting changes require a separate reviewed deployment authorization; none were made in this audit.

**Validation/rollback:** Record cold/warm HAR with content-encoding, request/cache headers, renderer/fonts and disabled cache; test roll-forward/rollback, offline revisit, browser fallbacks and CSP. Keep the prior hosting configuration/artifacts and cache-version strategy; do not claim the entire build directory is the initial transfer.

### WEB-002 — Benchmark browser-specific chunking, workers and deferred code

**Problem/evidence/root cause:** Default `main.dart.js` is 5.14 MB raw; the root router directly imports most feature screens. Image/PDF/JSON/calculation work can occupy the browser main thread. The native isolate strategy does not transfer automatically to web; a successful Wasm dry run is only build evidence.

**Proposal/gain (T/U):** Profile actual routes first. Investigate deferred document/report code, cooperative batching for large work, and real browser workers where measurable. Evaluate JS versus Wasm on supported browsers rather than assuming one is universally smaller/faster. Keep necessary features available when required; do not defer offline-essential code without a compatible preload/cache design.

**Effects/trade-offs/use:** Potentially shorter first download or fewer browser long tasks. Extra requests can slow poor-network navigation; worker transfer copies add memory; deferred-loader failure and isolation/CSP headers can complicate hosting. Not every BigInt/FFI/plugin path has identical browser capabilities.

**Effort/dependencies:** 3–6+ days after OBS-001/WEB-001/PLAT-001, with a specific hotspot and feature-preserving design.

**Validation/rollback:** Compare first-load transfer, route latency, browser heap/long tasks and exact pricing across Chromium/Firefox/Safari, cold/warm/offline cases and screen readers. Keep a nondeferred/default compiler build and feature flag; revert experiments that trade reliability for a small size win.

### PLAT-001 — Make platform capabilities explicit before promising parity

**Problem/evidence/root cause:** Android custom channels exist only in `MainActivity.kt`; no `ios/` host exists. `open_workspace_web.dart` returns transient preview state; business storage is native sqflite. Native file/channel imports such as `backup_service.dart` and `account_avatar.dart` compile through stubs but do not establish working web file storage or native share handlers.

**Proposal/gain (H reliability, U perf):** Document actual supported workflows and introduce only the platform adapters needed by approved optimizations. Keep web worker/storage/sharing and native channels behind explicit capabilities with tested errors/fallbacks. An iOS host, entitlement setup, database/plugin validation and custom channel implementations are additional product/platform work, not a free optimization.

**Effects/trade-offs/use:** Prevents unsupported-path crashes and misleading cross-platform performance comparisons. Additional adapters/tests increase maintenance and can expose presently incomplete features. Do not remove existing Android functionality or silently make permanent web data transient as a size tactic.

**Effort/dependencies:** 1–2 days for capability assessment; actual iOS/web feature parity is unestimated separate scope requiring SDK/devices and explicit approval.

**Validation/rollback:** Compile/platform-smoke all declared targets, invoke every relevant capability, verify secure account separation and offline promises. Roll back adapters independently through stable interfaces. All plans preserve existing supported behavior; none implicitly authorizes building a new iOS product.

### REL-001 — Protect signing, updateability and comparable release builds

**Problem/evidence/root cause:** `android/app/build.gradle.kts:38` signs release with the debug configuration. The current APK verifies with the same development certificate as the previous APK. Build logs warn about plugin Kotlin compatibility, but builds succeed. Toolchain/dependency versions influence both size and behavior.

**Proposal/gain (H reliability, no direct performance gain):** Before public/store distribution, decide signing ownership, update continuity and Play registration, and make release recipes/toolchain checks reproducible. Treat SDK/plugin upgrades as separately benchmarked changes. Do not replace the certificate, package ID, Firebase app, or dependencies during an optimization without explicit scope.

**Effects/trade-offs/use:** Preserves users' ability to update without uninstall/data loss and protects auth integrations. A different signing identity can prevent updates or break Google sign-in; store signing rotation needs a supported migration route. This is not a reason to erase working development data or claim a size gain.

**Effort/dependencies:** 0.5–2 days for audit/release controls, signing migration effort U until distribution requirements are known; separate decision before store publication.

**Validation/rollback:** Verify certificates/manifest across every artifact, upgrade over previous builds with populated databases, test auth and retain prior signed releases. Roll back via a compatible artifact with the same accepted identity/version/schema policy. Never instruct users to uninstall as the normal rollback strategy.

### Shared rollback and data-preservation contract

Before any implementation, record the selected IDs/exclusions, current commit and full working-tree state; make a scoped source snapshot and preserve the current signed APK. The business JSON export does **not** contain all pricing databases, active pricing state, preferences or profile images. A complete test/recovery baseline must include both business and pricing stores and required associated files. Use a consistent backup mechanism with databases closed or properly checkpointed/snapshotted; copying a live SQLite main file while ignoring journal/WAL files is not a safe backup. Keep private data private and never commit customer databases or auth credentials.

Prefer separate small commits/flags per ID. Additive migrations need a **forward-compatible rollback build** or tested restore procedure: an older binary expecting schema 11 may refuse a schema-12 database. Dropping an added index does not automatically make an older app compatible. Do not lower schema numbers, drop source ledgers, rewrite immutable pricing versions or assume code revert alone reverses a data migration. Schema changes, dependency upgrades, native signing changes and hosting deployment are distinct approval/review boundaries.

### Tempting changes not justified by evidence

- **Replacing Flutter/Riverpod/GoRouter or rewriting the UI natively:** the measured target is met by distribution, and framework replacement risks all workflows.
- **Removing Firebase/Google sign-in/Firestore import, PDF/printing, archives, language support or exact pricing:** removes required capabilities. No plan permits it.
- **Replacing exact rational arithmetic with double, skipping replay validation, weakening foreign keys/triggers, or reducing security checks:** unacceptable correctness/security trade-offs.
- **Re-enabling already-enabled shrinking or deleting build caches/dev dependencies to claim runtime savings:** false attribution.
- **Aggressive Manrope/language subsetting or deleting renderer fallbacks:** tiny Android font opportunity and real accessibility/internationalization/browser risks.
- **Blindly shrinking Flutter's image cache from its default ceiling:** this is not a measured retained allocation; there are few images. Fix stable identity/bounds and measure live entries first.
- **Turning every asynchronous method into an isolate job:** small tasks become slower; memory copies and worker startup matter. PDF serialization already has a native worker.
- **Adding WorkManager, a persistent service, polling or “automatic RAM cleaning”:** no evidence of missing background throughput; likely unnecessary battery/complexity cost.
- **Android deferred components as the first size strategy:** the current target is met without them. On-demand feature installation and offline availability complicate sideload support. Consider only if a future product requirement outweighs that cost.
- **Automatic database VACUUM, cache deletion or history pruning on launch:** can increase startup/write cost or destroy required records. Maintenance must respond to measured reclaimable space and preserve durable history.

## Section E: Optimization Packages

These are approval choices, not implemented plans. Effort is **tentative engineering time including shared tests and device verification**, excluding delays obtaining devices, app-store access or resolving unrelated platform setup. Implement only listed IDs; any excluded ID and its dependent work must be reconsidered before coding. Standalone estimates are not additive.

### Plan A — Safe Optimization

**Scope:** OBS-001, SIZE-001, SIZE-002, DB-002, CPU-004, MEM-002, STOR-002, STOR-003. REL-001 is a required distribution check; no certificate replacement or store publication is implicitly approved.

**Goal:** obtain the major packaging saving and remove focused I/O/buffer overhead with minimal visible behavior change. Expected effort **8–12 engineering days**. A delivery-only first increment can be considerably smaller (about 0.5–1 day plus installation checks).

| Metric | Current | Expected After | Confidence |
|---|---|---|---|
| App size | 77.16 MB universal APK; AAB model 13.43 MB ARM64 delivery | Approximately 28 MB ARM64 sideload or 13–14 MB modeled AAB delivery, with all ABI variants available | M diagnostic / H final packaging; no new source-size saving assumed |
| RAM | U | Fewer repeated branding/archive buffers; absolute PSS and peak reduction U | H reduced work; U magnitude |
| Startup | U | Similar bootstrap; no startup gain promised | U |
| UI smoothness | U | Fewer native I/O stalls and repeated document decodes; 60 FPS unproven | H threading benefit; U frame percentiles |
| Network | U | Smaller binary delivery; business API traffic essentially unchanged | H delivery; U runtime traffic |
| Battery | U | Potentially less repeated decode/work; no percentage claim | U |

**Risks/use:** ABI mismatch, async host lifecycle, migration compatibility for indexes, stale cache keys and premature share cleanup. Best when fast low-risk improvement is preferred and datasets are still modest. It does **not** solve all-history dashboard/report growth or unbounded backup/import workflows.

### Plan B — Balanced Optimization — Recommended

**Scope:** Plan A plus DB-001, DB-003, DB-004, DB-005, CPU-001, CPU-002, MEM-001, UI-001 and NET-001. DB-006 should be added for substantial non-ASCII catalogues; it is explicitly optional unless selected. NET-002 is a benchmark-dependent follow-up, not an automatic auth change. PLAT-001's assessment/compatibility checks constrain all changes; new platform functionality remains separately gated.

**Goal:** retain required features while addressing the strongest large-dataset, main-thread and lifecycle risks. Expected effort **25–40 engineering days**, staged so the size-only release can be reviewed first. Shared summaries, paging and document work are implemented once across IDs.

| Metric | Current | Expected After | Confidence |
|---|---|---|---|
| App size | 77.16 MB universal; 27.95 MB ARM64 diagnostic; 13.43 MB AAB delivery estimate | About the same packaging class as A; roughly 27–29 MB ARM64 / 13–14 MB modeled AAB delivery; worker/adapters may add small code | H packaging / T range; not cumulative savings |
| RAM | U; synthetic all-sales path transfers 50,000 rows | Page-bounded active record models plus summaries instead of full ledgers on ordinary screens; exact MiB/PSS U | H data-shape improvement / U device magnitude |
| Startup | U; useful dashboard includes all-history report work | Useful dashboard no longer requires full JSON ledger materialization; <3s target must be tested | H removed dependency / U timing |
| UI smoothness | U | Document preparation and large previews better isolated; aim to meet 16.67 ms frame budgets on representative low-end hardware | H work removal / U achieved FPS |
| Network | U; legacy imports may restart | Completed/staged pages can resume; smaller binary delivery; no measured request/byte percentage | H failure-mode improvement / U traffic |
| Battery | U | Less queued serialization, unnecessary replay and repeated import work, potentially offset by worker/cache overhead | T directional / U energy |

**Risks/use:** additive financial projections, identity matching, page-total correctness, queue flush ownership and import recovery. Best for everyday use on lower-end devices and businesses with growing records. Memory benefits overlap: reducing ledger materialization, retained models and widget work affects many of the same objects; do not add separate percentage claims.

### Plan C — Maximum Practical Optimization

**Scope:** Plan B plus selected DB-006, CPU-003, MEM-003, UI-002, STOR-001, NET-002, BAT-001, WEB-001 and WEB-002, **only where the baseline demonstrates need**. Includes platform-capability assessment, not an implicit iOS implementation. SIZE-003 and SIZE-004 remain separately gated feasibility investigations; neither is required by the current size target. No dependency fork, signing migration or infrastructure publication is preauthorized by choosing this plan.

**Goal:** address remaining measured bottlenecks and worst-case memory/data size while limiting avoidable complexity. Expected effort **40–65+ engineering days**, with stage gates and revised decisions if evidence does not justify later work.

| Metric | Current | Expected After | Confidence |
|---|---|---|---|
| App size | Same baseline as B | Working budget around 25–29 MB ARM64 APK / 12–14 MB modeled AAB delivery if small code savings prove worthwhile; could remain at B | T; 12/25 MB are planning possibilities, not demonstrated minima |
| RAM | U | Bounded documents/backups/queues and responsive cache policies; absolute typical/peak PSS U | H bounded algorithms / T policy effectiveness |
| Startup | U | B improvements plus measured initialization work reductions; potential deferred-feature latency trade-off | U |
| UI smoothness | U | Fewer browser/native long tasks where profiled; 60 FPS still device/workload-dependent | T until traces |
| Network | U; web asset model 3.01–4.52 MB gzip | Hosting/chunking can reduce actual transfer only if current deployment is suboptimal; browser/route data U | T/U |
| Battery | U | Avoided work may reduce scenario energy; more persistence, cache misses or worker overhead can offset it | U; validate before retention |

**Risks/use:** more formats/state machines/cache policies, streaming restore, mutable-to-immutable model changes and browser differences. Best for proven very large ledgers, long sessions, hard browser requirements or demonstrable memory pressure. Often not worth its full complexity for a small local business. Stop after B if the device acceptance criteria are already met.

### Combining gains correctly

The ARM64 packaging result and AAB compression estimate are **alternatives with different measurement definitions**, not successive source optimizations. Do not claim 77.16→27.95→13.43 MB as two additive APK reductions. Indexing cannot eliminate objects for an unbounded query; paging and projection must accompany it. Worker offload improves UI occupancy but may increase total CPU/PSS. Smaller caches can increase I/O/network. Plan ranges include overlapping code and do not promise improvements in every metric. A plan is accepted only against comparable before/after traces and preserved functionality.

## Section F: Recommended Roadmap

### Approval and sequencing

1. **Choose IDs and exclusions first.** Record the approved plan, devices/workloads, acceptance budgets and rollback boundaries. No implementation starts on general enthusiasm or silence.
2. **OBS-001 and release safeguards:** preserve source state, current signed APK and consistent test data; establish an actual 2 GB baseline. Confirm signing/update constraints via REL-001. Current evidence: clean tracked source baseline and passing audit-copy checks.
3. **SIZE-001/002:** produce reviewable ABI/AAB artifacts and comparable size reports; verify ARM32/ARM64/x86_64 coverage and upgrades. This can satisfy the size objective independently of runtime refactoring. No store upload is authorized merely by building an AAB.
4. **Low-risk targeted work:** CPU-004, MEM-002, STOR-003 and carefully validated STOR-002. Measure main-thread stalls, repeat views and share-read safety. Test DB-002 candidate indexes before selecting additive migration SQL.
5. **Data contracts before migrations:** design DB-001 exact summaries, DB-003 identity lookup/history and DB-005 open-bill projections together. Keep ledger source snapshots authoritative. Create compatible backfill and rollback builds before touching real data.
6. **Bound working sets:** DB-004 (and DB-006 when relevant), then MEM-001 ownership and CPU-002 backpressure with tested close/flush barriers. Full history/counts/totals must not disappear behind paging.
7. **Document work and interactive UI:** CPU-001 plus UI-001, using observed traces; do not duplicate the PDF package's existing serialization worker. Gate CPU-003/UI-002 on remaining build/replay/layout cost.
8. **Legacy accounts:** NET-001's staging/recovery state machine. Prioritize earlier if repeat imports dominate actual network/startup behavior. NET-002 follows only measured optional initialization cost.
9. **Further low-RAM/storage/web work:** STOR-001, MEM-003, BAT-001, WEB-001/002 only when evidence justifies their risks. Existing web/iOS capability gaps must be resolved or explicitly constrained, not hidden in benchmarks.
10. **Stop when acceptance is reached.** Defer codec/driver migrations, framework replacement and deferred Android delivery unless a new measured requirement warrants a revised decision.

### Physical-device and browser measurement protocol

**Device matrix:** at least one real 2 GB Android device representative of supported CPU/GPU/storage (including 32-bit userspace if relevant), a 4 GB middle-tier device, and a faster 8 GB+ device. Log Android/API, ABI/userspace, screen refresh rate/resolution, CPU/GPU, free storage, `ActivityManager.isLowRamDevice`, app memory class, total/available RAM, thermal state and competing workload. RAM capacity is not a speed ranking. Once an iOS host exists, use supported low/high iPhone targets and Instruments; do not extrapolate Android results.

**Modes and datasets:** profile mode for Flutter timeline/rebuild attribution; release mode for startup, installed footprint and final confirmation. Never use debug-mode FPS/memory as release results. Maintain an empty register, ordinary working register, 5,000/50,000-record synthetic ledgers, substantial paid/unpaid history, and maximum supported 100-item custom estimates. Exercise supported worst-case branding/archived PDF input and large backups/imports without inventing limits that remove valid data.

**Startup:** record at least 20 cold-process launches and 30 warm/resume trials after warm-up, with device conditions documented. Use `adb shell am force-stop com.hyner.hyner` only on the designated test instance, then `am start -W` for Android activity timing. Pair this with Flutter first-frame and application-ready/dashboard timeline marks; activity launch time alone is not useful-screen time. Separate process-cold from device-reboot/file-cache-cold conditions. Report median/p95; do not reset or clear user data to obtain a flattering number.

**Frames/CPU:** capture DevTools UI/raster timings and Perfetto/Android system trace for scroll, calculator typing, navigation, photo selection, PDF generation and share. Use `FrameTiming`/integration instrumentation with missed-vsync and p50/p95/p99; 60 Hz permits roughly 16.67 ms per pipeline stage, while 120 Hz budgets are tighter. Rendering and CPU conclusions require on-device measurements. Avoid averaging away long jank/ANR events. Android baseline profiles help some Java/Kotlin startup paths; they are not a substitute for Flutter AOT or a proven priority here.

**Memory:** capture DevTools heap/allocation/GC plus `adb shell dumpsys meminfo com.hyner.hyner` and native/graphics profiling. PSS, RSS, Java heap and Dart heap are different views and must not be added indiscriminately. Record idle, ordinary navigation, photo/PDF/backup peaks, and retained growth after GC for 50 repeated navigation/account cycles. Include backgrounding/trim-memory and process-death recovery. A proposed conservative test budget could be ~150–220 MiB steady PSS and <300 MiB transient peaks on a chosen 2 GB test device, **but these are tentative acceptance starting points, not observed or universal Android limits**; adjust using the actual app memory class, LMK behavior and workload. Require no reproducible upward retention trend or lost drafts/data.

**Database/storage:** capture actual-device EXPLAIN plans and read/write/query-boundary row counts, summary consistency, migration wall time/temp-space needs and disk footprint. Measure database sizes, journal/WAL/cache files and app installed code/data separately. Audit backup consistency. Do not claim ZIP uncompressed size is installed footprint or that a smaller database is always faster.

**Network/energy:** capture account setup, legacy import failure/retry/resume and repeated navigation with offline/slow-network cases; measure requests, transferred bytes and radio wakeups without logging customer/auth content. Use Android system tracing/power tools or controlled Batterystats scenarios over sufficiently long identical workloads. No meaningful percentage battery claim follows from a short CPU microbenchmark. Prove that no polling/service was introduced.

**Web:** use a real deployed test origin with network/cache headers, cold/warm HAR, throttled-network traces and Chromium/Firefox/Safari coverage. Measure actual renderer, fallback fonts, app JS/chunks and remote SDK requests, browser heap/long tasks and useful-screen timing. Default `compute` remains on the browser main thread; validate real worker or chunk strategies separately. Preserve CSP/auth security and test offline expectations explicitly.

### Feature/regression acceptance gates

- Every existing automated test remains passing; opt-in visual captures are run for changed screens/PDFs. Current three skips are `CAPTURE_UX_QA`, `CAPTURE_ESTIMATE_QA` and `CAPTURE_SCREENSHOTS`, not functional-test failures.
- Sale creation/stock deduction/payment retries stay idempotent; customer history and totals cover all bills and currencies.
- Door/universal strategies, exact unit conversions, rounding/tax, custom quotes, estimate edits and checkout remain byte/value consistent. Published version immutability and tamper checks remain enforced.
- Restore/import/backfill interruption leaves valid live ledgers; old backups remain readable; no accidental UID crossing, consent changes or background message sending.
- Original/duplicate PDF content, colours, decimal amounts, branding, print/save/WhatsApp flows remain correct under cancellation and account changes.
- Authentication, device-only/offline use, security controls, large text, keyboard focus, screen readers and reduced motion remain supported.
- Compare before/after using the same artifact class, devices, fixtures and protocol. Reject or revert regressions outside agreed tolerances; request a revised decision for harmful/impractical approved work instead of substituting another change silently.

## Section G: Final Engineering Recommendation

1. **Best strategy:** approve a staged **Plan B**, beginning with SIZE-001 and measurements. The strongest findings are delivery duplication and unbounded data/materialization, not a generally broken Flutter architecture. Retain the present state-management/routing/pricing foundations.
2. **Likely practical download size:** unchanged features already demonstrate **27.95 MB ARM64 diagnostic APK** and **13.43 MB bundletool-estimated ARM64 store delivery**. A realistic immediate delivery budget is roughly **28 MB sideload / 13–14 MB compressed store download** for comparable configurations. A hypothetical ~25–27 MB ARM64 / ~12–13 MB store floor is tentative and not worth high-risk migrations solely to pursue. No smaller “minimum” can be guaranteed without controlled implementation/builds; below 10 MB store delivery is not supported by this evidence.
3. **Expected memory improvement:** remove whole-ledger/dashboard/pending materialization; bound active pages, draft queues, account workspaces and document jobs. The 50,000-sale synthetic path carries 21.65 MB of line text alone, indicating meaningful avoidable payload. Actual steady/peak process-MiB improvement is unknown until device profiling; do not promise 50% lower RAM.
4. **2 GB likelihood:** reasonable for ordinary local billing/calculation workloads with bounded data and document pipelines, but **not certified**. Weak CPU/GPU/storage, Android memory class, other apps and peak PDF/backup work determine viability. Validate on real constrained devices before making a product promise. Large backup/import memory remains a reason to consider later Plan C work.
5. **Worth implementing:** architecture-aware delivery; query/summary contracts and paging; point/identity-aware customer reads; measured indexes; safe writer backpressure; native I/O workers; complete document preparation isolation; explicit resource ownership; legacy-import resumption where used; correct temporary-file hygiene. Preserve functionality and security throughout.
6. **Usually not worth the complexity now:** driver consolidation, PDF/image forks, aggressive font/language cuts, Android dynamic delivery, blanket adaptive RAM modes, framework/state-library rewrites or micro-optimizations without traces. Most of the size target is available without touching these.
7. **Must be tested physically before commitment:** low-RAM PSS/peak/long-session behavior, cold/warm useful-screen times, stable frame budgets, Android media/provider/share lifecycle, ABI update installation, database migrations/import recovery and energy impact. iOS needs an implemented host/SDK/devices; web needs hosting/browser evidence rather than a successful compiler run.

### Approval gate — no implementation has begun

Select one option and optionally list **excluded IDs**:

- **Option A:** Implement Safe Optimization.
- **Option B:** Implement Balanced Optimization.
- **Option C:** Implement Maximum Practical Optimization, subject to its measurement gates.
- **Option D:** Select individual recommendation IDs.
- **Option E:** Revise the proposed optimization plan.
- **Option F:** Do not implement anything.

No silence, general enthusiasm, or approval to read this report is implementation approval. A selected package does not authorize removing essential features, changing auth/signing identities, publishing infrastructure, or adding an iOS product. Missing prerequisites and excluded dependencies will be resolved with a concrete revised decision before dependent implementation.

## Appendix: Evidence and Reproduction

### Commands used, with original source preserved

Commands below were run in the temporary audit copy unless explicitly described as inspection. The exact SDK, lockfile, source hashes, artifact types and build flags matter.

```sh
# Read-only original artifact/tool/device inspection
flutter --version --machine
adb devices -l
xcrun --sdk iphoneos --show-sdk-path
# Python ZipFile: file/ZIP-entry byte counts and SHA-256 of current release APK

# Initialize generated build metadata only in the temporary source copy
flutter pub get --offline
# Copied pubspec.lock was checked unchanged against the original.

# Baseline diagnostic build, same code/configuration as Android release
flutter build apk --release --no-pub \
  --target-platform android-arm64 --analyze-size \
  --dart-define-from-file=build/config/firebase.android.json

# Unchanged-source AAB; no upload/publish/install
flutter build appbundle --release --no-pub \
  --dart-define-from-file=build/config/firebase.android.json
# bundletool 1.18.3: build-apks using the existing development signing identity
# and get-size total --apks=... --device-spec=...

# Default documented web build; no Android Firebase defines reused for web
flutter build web --release --no-pub
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

The initial scratch APK attempt lacked generated `package_graph.json`; it failed before compilation. Offline dependency setup in the scratch copy resolved the tooling prerequisite without changing the lockfile or original project. Successful builds are the results reported above. Android build warnings concerned plugin Kotlin migration/obsolete Java options; they were not build failures. The completed web build also reported a successful Wasm dry run; it was not a deployed/browser-tested Wasm artifact.

**Verification results:** Android size-analysis build succeeded; AAB build and bundletool generation succeeded; web release build succeeded; static analysis reported no issues; tests reported **674 passed / 3 skipped / 0 failed**. The original source/configuration manifest was compared before report delivery; final integrity result appears below.

Audit evidence files outside the repository include `source-before.json`, `apk-inventory.json`, `arm64-code-size-analysis.json`, `aot-packages.json`, `sql-evidence.json`, `web-artifacts.json`, `baseline-summary.json`, and build/analyzer/test logs. The report embeds the important measured values so decisions do not depend on temporary-file retention. Diagnostic outputs and logs may contain build configuration; do not publish them wholesale.

### Primary technical references

These references support measurement interpretation and platform constraints, rather than supplying invented application benchmarks:

- [Flutter: Measuring your app's size](https://docs.flutter.dev/perf/app-size) — release artifact analysis and device-download distinctions.
- [Android: bundletool](https://developer.android.com/tools/bundletool) — configuration-specific compressed download estimates.
- [Flutter: Performance profiling](https://docs.flutter.dev/perf/ui-performance) — profile-mode physical-device methodology.
- [Flutter: Performance best practices](https://docs.flutter.dev/perf/best-practices) — rebuild/layout/lazy-list investigation.
- [Flutter: Concurrency and isolates](https://docs.flutter.dev/perf/isolates) — isolation/copy costs and web compute limitations.
- [SQLite: EXPLAIN QUERY PLAN](https://www.sqlite.org/eqp.html) — scan/search interpretation.
- [Flutter: ImageCache API](https://api.flutter.dev/flutter/painting/ImageCache-class.html) — configurable cache ceilings and live references; a ceiling is not current consumption.
- [Android: Memory performance](https://developer.android.com/topic/performance/memory) — process working sets, memory pressure and measurement tools.
- [Flutter: Web platform](https://docs.flutter.dev/platform-integration/web) — JS/Wasm/browser implementation distinctions.

Local SDK/package implementation was also inspected to avoid stale generic advice: Flutter Gradle shrink defaults; `pdf` 3.13.1 page generation versus native save isolation; project lockfile/native SQLite build hook. All suggested gains remain labeled as measured, estimated or unknown.

### Final source-integrity verification

Compared SHA-256 hashes for all **265 baseline source/configuration files** after the audit: **0 changed, 0 removed, 0 additional non-report source/configuration files** under the same exclusions. Git tracked application files remain unchanged. The only new repository artifact from this audit is `FLUTTER_OPTIMIZATION_AUDIT.md`. Build/test/measurement outputs were generated in the temporary copy; no optimization has been applied to the application.
