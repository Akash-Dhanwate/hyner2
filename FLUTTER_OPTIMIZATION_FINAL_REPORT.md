# Flutter Optimization Final Report — Approved Plan A

Date: 10 November 2026. Approval: user selected **A (Safe Optimization)** after the audit. Baseline: `094766cc145b7b8586153e403c733a96a18a9692`. Toolchain: Flutter 3.47.7, Dart 3.13.5; existing Android SDK/build setup retained.

## Outcome and scope

Plan A's source changes, release artifacts, host verification and measurement tooling are complete. Physical-device qualification remains outstanding. No application installation, store upload, production infrastructure change or real merchant database operation was performed.

The final **ARM64 sideload APK is 27,775,463 bytes (27.78 decimal MB)**, **64.00% smaller** than the original 77,164,678-byte universal APK. ARM32 is 25.84 MB and x86_64 is 29.36 MB. The ≤50 MB sideload target is achieved for all three supported architectures. This is architecture-aware delivery: it does not demonstrate a 64% reduction in Dart code, RAM, installed footprint or startup time. The same-format universal APK grew slightly.

Controlled host measurements show less repeated image preparation/archive inflation and faster selective SQL reads. They do not establish phone startup, FPS, CPU utilization, RAM or energy improvements. Good operation on a real 2 GB Android device remains unverified; total device RAM is not the application's available memory budget.

Approved IDs: OBS-001, SIZE-001, SIZE-002, DB-002, CPU-004, MEM-002, STOR-002, STOR-003. REL-001 was limited to distribution verification. No Plan B/C query, state-management, authentication, financial-summary, PDF-isolate or platform-feature migration was included. The earlier billing/customer/WhatsApp/measurement/colour changes are retained in these builds.

## Implemented changes

| ID | Final implementation | Benefits and practical limits |
|---|---|---|
| OBS-001 | Opt-in startup/frame recorder, bounded 240-frame window, Android collection script and documented scenarios | Repeatable measurement without customer-content logs. Disabled in shipping releases. Device/browser traces and energy collection still require hardware and separate profiling. |
| SIZE-001 | Default per-ABI release APKs; optional universal fallback, AAB and diagnostic analysis modes | Substantially smaller sideload transfer. Requires correct ABI selection; ARM32 is retained for phones with 32-bit Android userspace. No intrinsic RAM/FPS saving established. |
| SIZE-002 | Artifact size ceilings, checksums, native/ZIP/package/version/certificate checks and Flutter size analysis | Detects distribution and size regressions. Existing R8, resource shrinking and icon tree shaking remain active; they were already enabled before this work. Additional release verification costs build time. |
| DB-002 | Additive schema-12 customer/date/id, partial follow-up and currency/date/id indexes | Speeds selective reads in the fixture, preserves rows and current query semantics. Increases index storage and writes; cannot solve full-history/all-time materialization. |
| CPU-004 | Move Android profile-photo decode/encode, share-PDF writes and destination writes to a process-wide bounded file worker | Removes those operations from the activity thread. One active and one queued operation; idle worker expires. Replies/intents stay on the main thread. Actual Android stalls/content providers remain unprofiled. |
| MEM-002 | Stable settings-preview byte/provider identity; page-owned prepared-branding pixels reused for original/duplicate variants | Avoids repeated base64/image work. Fresh PDF providers prevent retaining prior document graphs. Cache deliberately retains bounded pixels while the bill page is alive; net PSS reduction is unknown. |
| STOR-002 | Conservative best-effort cleanup of known generated temporary PDF/backup handoffs | Prevents indefinite accumulation when relevant operations run. Seven-day grace, process/session/active protection, links excluded. No real-device reclaimed-byte claim. |
| STOR-003 | Metadata-only archive existence lookup; single-flight archive creation per account/sale; bytes loaded only for explicit export | Avoids repeated decompression and retained duplicate-PDF buffers on ordinary bill views/payment refreshes. First immutable archive remains unchanged. Corruption is discovered on explicit read rather than every open; rebuilt-export fallback remains available with a notice. |
| REL-001 | Preserve and inspect package, version, ABI and signing continuity | Same application identity/certificate; no key migration, store release or physical update test. Existing signing identity is developmental. |

Production dependencies and `pubspec.lock` did not change. The only dependency addition is **test-only JUnit 4.13.2**. No security/permission/backup-format weakening, pricing rewrite or removal of offline functionality was introduced.

## Android size measurements

Decimal MB uses 1 MB = 1,000,000 bytes. All APKs are release builds; none of these figures is installed storage or app memory.

| Artifact | Before (bytes) | After (bytes) | Valid interpretation |
|---|---:|---:|---|
| Universal APK | 77,164,678 | 77,262,982 | Same-format increase **98,304 bytes / 0.13%** |
| ARM32 sideload APK | Original delivery was universal: 77,164,678 | 25,840,177 | **66.51% less file transfer** than previous delivery; no pre-change split APK measured |
| ARM64 sideload APK | Original delivery was universal: 77,164,678 | 27,775,463 | **64.00% less file transfer** than previous delivery; no pre-change split APK measured |
| x86_64 sideload APK | Original delivery was universal: 77,164,678 | 29,355,400 | **61.96% less file transfer** than previous delivery; no pre-change split APK measured |
| AAB upload container | 75,680,203 | 75,762,859 | Same-format increase **82,656 bytes / 0.11%**; not device download size |
| ARM64 diagnostic analysis APK | 27,950,711 | 28,016,247 | Same-format increase **65,536 bytes / 0.23%**; foreign JNI helpers distinguish it from the shipping split |

The split gain is not added to the AAB gain. Most original universal APK bytes were native libraries for three architectures. Package analysis was rerun; the engine/plugins remain, and production AOT bytes match between each ABI's split and universal artifact. All shipping checks found the profiling marker absent. Source-library hashes are identical across split, universal, bundle and diagnostic builds.

Bundletool 1.18.3 estimated compressed delivery using identical specifications before/after:

| Specification | Before (bytes) | After (bytes) | Status |
|---|---:|---:|---|
| ARM64, API 35, en, 420 dpi | 13,426,385 | 13,445,178 | Tool estimate; +18,793 bytes |
| ARM32, API 24, en, 320 dpi | 13,209,758 | 13,217,930 | Tool estimate; +8,172 bytes |
| x86_64, API 35, en, 420 dpi | 13,682,406 | 13,694,149 | Tool estimate; +11,743 bytes |

These are bundletool compressed-download estimates, not observed Play Store downloads. The AAB validates and its certificate is verified; no publication occurred. A practical demonstrated delivery size is **25.84–29.36 MB sideload**, or **13.22–13.69 MB estimated compressed bundle delivery** for these specifications. No lower minimum is established.

### Artifacts

- [ARM64 APK](build/app/outputs/flutter-apk/hyner-0.6.0-plan-a-arm64-v8a.apk) — most current Android phones.
- [ARM32 APK](build/app/outputs/flutter-apk/hyner-0.6.0-plan-a-armeabi-v7a.apk) — 32-bit Android userspace, including some low-RAM phones.
- [x86_64 APK](build/app/outputs/flutter-apk/hyner-0.6.0-plan-a-x86_64.apk).
- [Universal fallback](build/app/outputs/flutter-apk/hyner-0.6.0-plan-a-universal.apk) — when the ABI is uncertain.
- [AAB](build/app/outputs/bundle/release/hyner-0.6.0-plan-a.aab) — upload format, not directly installable.

Each has a `.sha256` sidecar. Package: `com.hyner.hyner`; version 0.6.0, code 8; min SDK 24, target SDK 36. Sideload variants explicitly retain the declared version code rather than applying ABI multipliers. Certificate SHA-256 remains `abdc309aa793adb3e76226fd8a6a980a00bdc393022c95ef8956c8a8d10a8517`. Original APK checksum remains `f4c6453a8f544a709cee6d27f2871c75544c86db47a6cd273ef35edaea8e03a9`.

## SQL comparison and costs

Measured in a synthetic **in-memory desktop SQLite 3.53.4** database, 50,000 sales, seven read repetitions; values are medians. Identical result-ID hashes were verified. Tests also exercise the actual version-11 to version-12 migration with preserved sale/customer/settings rows, including WhatsApp opt-outs. These timings exclude application hydration, device disk synchronization and UI work.

| Operation | Before | After | Observation |
|---|---:|---:|---|
| Customer-history candidate read (2,510 rows) | 13.405 ms | 3.386 ms | **74.74% lower**; composite index replaces full date-index traversal; OR still sorts |
| Follow-ups (500 rows) | 2.266 ms | 0.576 ms | **74.59% lower**; partial index replaces scan/temp sort |
| INR month (3,332 rows) | 3.909 ms | 3.959 ms | About 1.29% slower in this run; no useful gain demonstrated |
| USD month (834 rows) | 1.444 ms | 0.959 ms | **33.60% lower** for selective currency/date access |
| First sales page (31 rows) | 0.033 ms | 0.036 ms | No gain; sub-0.003 ms difference is not evidence of a useful regression |
| Allocated database pages | 22,978,560 bytes | 27,787,264 bytes | **+4,808,704 bytes / 20.93%** in this fixture |
| 1,000 inserts, no disk sync | 1.627 ms | 3.316 ms | **~104% longer**, approximately 1.69 microseconds extra per insert on this host |

The three indexes are retained because selective history/follow-up/currency reads gain while the absolute host write overhead is small. This is a trade-off, not a universal query win. Migration index-build time, free-space requirements and Android flash write costs remain to be measured on a realistic large test database. Very large ledgers can still block startup while indexes are first created. Do not infer a 75% faster application, smaller database, or improved battery from these SQL-only results.

## Image/archive comparison and memory implications

Controlled Flutter-test host benchmark: five repetitions of 20 operations. Synthetic logo: 512×512 PNG, 92,473 encoded bytes. Archive fixture: 1,048,591 decoded bytes with a PDF-like byte/codec payload; it is not a representative rendered invoice or end-to-end PDF benchmark.

| Repeated operation | Before-style path | Optimized path | Observation |
|---|---:|---:|---|
| Twenty branding preparations/accesses | 60.912 ms | 2.753 ms | **95.48% less time** in this loop; twenty preparations become one |
| Twenty archive accesses | 51.442 ms read/inflate | 2.930 ms metadata | **94.30% less time** in this loop; metadata does not decode archive bytes |
| Archive decoded-byte volume across all 100 accesses | 104,859,100 bytes | 0 bytes | Allocation/work avoided in this fixture, not a peak-RAM measurement |

Bill pages no longer retain an inflated duplicate PDF between actions. Settings previews retain stable decoded bytes/providers across unrelated rebuilds and evict their own image entry on change/dispose. Prepared branding is bounded to the current logo/signature and compact/noncompact variants, invalidated by source change, and cleared on page disposal. Providers are created per PDF document. Ordinary 8-bit RGBA retained resized pixels are bounded at roughly 2.5 MiB for both 512-pixel/256-pixel variants combined; legacy source pixel formats and encoded originals add overhead. Caching can increase steady bill-page memory while reducing transient allocations and CPU work. **Typical/peak PSS and net RAM savings were not measured.**

## Native CPU, lifecycle and temporary storage

Photo decoding/JPEG encoding and PDF file writes now run on one process-wide worker with one waiting slot. This bounds queued large buffers even across activity recreation; overload fails through the existing error paths. Completion is delivered once on the UI thread. Activity closure removes only its queued jobs and resolves pending results; an already-open write can finish safely without launching a share from a destroyed activity. The worker times out after 30 seconds idle; no background service or polling was added.

Unit tests cover thread dispatch, bounded overflow, close/late-result delivery, replacement-owner preservation and immediate-dispatch cancellation. They do not simulate actual Android content providers, photos, WhatsApp, print services or process death. File I/O is moved, not eliminated; Dart PDF layout still runs where it did before.

Cleanup runs best effort on relevant share/backup activity, at most once per day, and targets only known generated temporary filenames older than seven days. It excludes durable duplicates, databases, user-selected exports, symlinks, active backup paths, current-process PDF handoffs and session-created backups. Dart enumeration streams with a 1,000-entry cap. Native cleanup caps inspection/file I/O to 1,000 entries but Java still enumerates directory names. Large directories are not guaranteed to be fully drained. No cache-size reduction has been measured on a real installation.

Third-party receivers provide no general consumption receipt. The grace period is conservative protection rather than a guarantee for arbitrarily delayed reads after process restart. Physical delayed-share tests remain necessary. Cleanup failure never prevents sharing. No required offline data is deleted.

## Baseline and remaining measurement gaps

| Metric | Before | After | Measurement status |
|---|---|---|---|
| Android sideload transfer | 77.16 MB universal | 27.78 MB ARM64; others above | Measured release files; delivery format changed |
| ARM64 compressed bundle delivery | 13.426 MB | 13.445 MB | Bundletool estimate, fixed spec |
| Installed footprint | Unavailable | Unavailable | Requires installation/storage measurement |
| Typical / peak Dart/native/graphics RAM | Unavailable | Unavailable | Requires DevTools and device PSS/heap traces |
| Cold / warm useful-screen startup | Unavailable | Unavailable | Collector added; no connected Android device |
| Scroll frame times / 60 FPS | Unavailable | Unavailable | Opt-in stage recorder added; no physical trace |
| CPU utilization / GC / long-session growth | Unavailable | Unavailable | Host microbenchmarks are not device utilization |
| Network transfer / requests | Unavailable | Unavailable | No network behavior optimized or measured |
| Battery energy / wakeups | Unavailable | Unavailable | No power trace; no claimed percentage saving |
| iOS size / performance | Unavailable | Unavailable | No iOS host project/SDK here |
| Web deployment files, uncompressed | 44,713,723 bytes | 44,724,729 bytes | Includes renderer variants/debug symbols; not initial download |
| Web main.dart.js | 5,142,754 bytes | 5,153,759 bytes | Build output measurement |
| Web main.dart.js gzip-9 | 1,505,791 bytes | 1,509,920 bytes | Local compression only; HTTP transfer unmeasured |
| Web initial request/render/heap | Unavailable | Unavailable | No browser HAR/runtime benchmark |

Web release compilation and Wasm dry run succeed. Existing web business-workflow limitations from the audit remain; compile success does not certify parity with Android. No iOS compatibility claim can be made from an absent host project. CPU/GPU speed is not inferred from RAM capacity.

## Validation executed

- **683 Flutter tests passed, four skipped**, full suite with `CAPTURE_BILL_PDF=true`; no failures. The baseline was 674 passed / three skipped. The fourth skip is the opt-in resource benchmark, which was executed separately and passed; the original three screenshot captures remain opt-in.
- **Six native JUnit tests passed** via `:app:testDebugUnitTest`, zero failures/errors. AGP exposes the debug test task for this build; the unavailable release-unit task was not treated as a pass. Native production code also compiles in all release artifacts.
- `flutter analyze --no-pub`: **No issues found**. Format verification: 196 files, zero changes. Python helper compilation and `git diff --check` pass.
- ARM32, ARM64, x86_64, universal, AAB and diagnostic builds completed. ZIP/ABI/size/package/version/certificate checks pass; bundletool validates AAB. Checksums and analysis evidence are preserved.
- Web release build passes. No publication or remote service mutation was performed.
- Generated original and coloured PDFs were rendered and visually inspected for layout, logo/signature, amounts and section colours. Branding tests verify pixel reuse with fresh document providers.
- Migration/backup tests preserve business rows and existing opt-outs; archive tests cover concurrent generation, account scoping, failure retry, metadata-only normal opening/payment refresh and corrupt-archive fallback. Cleanup tests cover stale/fresh/protected files, directories and links. Existing tests cover billing, payments, inventory/measurements, pricing, customer history, settings, offline persistence, backup/restore, 320-pixel layouts and enlarged text.

Phone integration flows still need manual validation: sign-in, ABI-compatible install/update without data clearing, image picker, printing, WhatsApp fallback, save-provider cancellation, activity recreation/process death and delayed receiver reads. Automated host tests do not replace these checks.

## Evidence and reproduction

See [Plan A guide](docs/performance/PLAN_A.md) for exact commands and scenario protocol. Main local evidence under `build/optimization/`:

- `baseline/baseline.json`, `baseline-verified.json`, `artifacts-{split,universal,bundle,analysis}.json` and checksum sidecars.
- `arm64-code-size-analysis-after.json`, `bundle-validation.log`, `bundle-download-estimates.json`, `web-artifacts-after.json`.
- `index-comparison.json`, `resource-comparison.json` and their benchmark logs.
- `all-tests.log`, `android-unit-tests.log`, `final-analyze.log`, `final-format.log`, `web-build.log`, release-build logs and PDF render images.
- Native XML results under `build/app/test-results/testDebugUnitTest/`.

Build outputs are local, ignored artifacts and can be removed by clean operations. This report records the key measurements independently. No customer data is embedded in benchmark fixtures or logs.

## Rollback and data integrity

Before implementation, tracked source was clean. The source archive, file manifest, original signed APK, checksum and audit baseline were recorded under `build/optimization/baseline/` and copied outside the build tree to **`/Users/akash/hyner2-plan-a-rollback-pi7btrjr`**. These are source/build recovery artifacts, not a backup of merchant data. The working tree is left reviewable; no commit, push or deployment was performed.

1. For a source rollback, restore only the approved modified files from the baseline into a reviewed fallback branch. Keep package/certificate continuity and **schema-12 compatibility** in the fallback build.
2. Do not install the old schema-11 application over an upgraded database without compatibility work. Do not lower SQLite `user_version`, uninstall, clear app data or drop business tables. The safe initial rollback retains the additive indexes; remove them only with a forward migration if necessary.
3. Preview/branding caches, metadata lookup, worker, profiling and cleanup changes can be reverted individually while retaining schema compatibility. Cleanup can be disabled separately; files already expired from temporary storage are not recoverable from the source archive.
4. On a test device, close/checkpoint databases and preserve complete data stores, preferences and associated media before migration/rollback. The existing portable business JSON backup is not a full application-state backup. No such private device backup was available or created here.
5. Rebuild the fallback, run the same tests, verify signature/version and validate an update on the designated test device. Never use a data-destructive downgrade as a rollback shortcut.

## Recommended follow-up

First qualify these artifacts on real ARM32/ARM64 hardware, including a 2 GB Android device with realistic free memory and large synthetic data. Compare process-cold and warm startup distributions, useful-screen markers, PSS/heap/native peaks, UI/raster frame percentiles, import/migration time and free space, and long-session stability. Profile photo/PDF/share operations, background/resume and low-memory lifecycle recovery. Run controlled energy and network captures separately.

The recorder defaults off; instrumented runs must be labelled separately. Its over-budget count refers to build/raster stages exceeding 16.67 ms and is not a measured FPS or missed-vsync count. Android `am start -W` is not Flutter useful-screen startup; settled PSS is not peak memory. The collector requires an explicit test-device flag and does not install, clear data or dump customer logs.

Further pagination, database projections, PDF computation offloading, auth/cache policy changes or device-adaptive modes remain outside approval. Consider them only after device evidence justifies a separate decision. The demonstrated size target is already met by delivery changes; additional complexity solely to chase smaller binaries is not justified by this run.

## Files changed

Application, native test, benchmark and documentation paths are listed below. The original audit is retained as a historical report; this report records implementation results.

- `README.md`
- `android/app/build.gradle.kts`
- `android/app/src/main/kotlin/com/hyner/hyner/FileWorkQueue.kt`
- `android/app/src/main/kotlin/com/hyner/hyner/MainActivity.kt`
- `android/app/src/main/kotlin/com/hyner/hyner/SharedTempFiles.kt`
- `android/app/src/test/kotlin/com/hyner/hyner/FileWorkQueueTest.kt`
- `android/app/src/test/kotlin/com/hyner/hyner/SharedTempFilesTest.kt`
- `docs/performance/PLAN_A.md`
- `lib/core/performance/performance_recorder.dart`
- `lib/core/storage/backup_service.dart`
- `lib/core/storage/generated_backup_files.dart`
- `lib/core/storage/local_business_database.dart`
- `lib/features/dashboard/presentation/dashboard_screen.dart`
- `lib/features/sales/data/bill_pdf_service.dart`
- `lib/features/sales/data/local_bill_document_repository.dart`
- `lib/features/sales/domain/bill_document_repository.dart`
- `lib/features/sales/presentation/sale_detail_screen.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/main.dart`
- `test/business/bill_document_storage_test.dart`
- `test/business/bill_pdf_service_test.dart`
- `test/business/bill_settings_screen_test.dart`
- `test/business/customer_migration_test.dart`
- `test/business/generated_backup_files_test.dart`
- `test/business/local_business_data_test.dart`
- `test/business/plan_a_indexes_test.dart`
- `test/business/sales_customer_storage_test.dart`
- `test/business/sales_screen_test.dart`
- `test/business/support/fakes.dart`
- `test/performance/performance_recorder_test.dart`
- `test/performance/plan_a_resources_benchmark_test.dart`
- `tool/android_size_budgets.json`
- `tool/benchmark_plan_a_queries.py`
- `tool/build_android.py`
- `tool/check_android_artifacts.py`
- `tool/profile_android.py`
- `FLUTTER_OPTIMIZATION_FINAL_REPORT.md` (this report).
