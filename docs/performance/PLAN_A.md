# Plan A implementation and measurement guide

Approved scope: OBS-001, SIZE-001, SIZE-002, DB-002, CPU-004, MEM-002, STOR-002, STOR-003, plus REL-001 distribution verification. Plan B/C work is excluded. Source baseline is commit `094766cc145b7b8586153e403c733a96a18a9692`; the original source snapshot, file hashes and signed APK are preserved in `build/optimization/baseline/` on this machine. A second copy outside the build directory is preserved at `/Users/akash/hyner2-plan-a-rollback-pi7btrjr`; its location is also recorded in `build/optimization/rollback-location.txt`. These snapshots contain source/build evidence, not merchant data backups. No production data or infrastructure is modified by the build/benchmark scripts.

## Release artifacts and budgets

Run Flutter/Gradle commands sequentially to avoid shared native-build output collisions:

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' android/gradlew -p android :app:testDebugUnitTest
python3 tool/build_android.py --format split --no-pub
python3 tool/build_android.py --format universal --no-pub
python3 tool/build_android.py --format bundle --no-pub
python3 tool/build_android.py --format analysis --no-pub
```

The default script builds three separate sideload APKs. Most current Android phones use `arm64-v8a`; devices with 32-bit Android userspace need `armeabi-v7a`, including some low-RAM phones. Use `adb shell getprop ro.product.cpu.abilist` to check. `x86_64` is for compatible devices/emulators. The universal file is a compatibility fallback. AAB is an upload format and cannot be directly installed. No store publication is performed.

Each artifact has a SHA-256 sidecar and an evidence manifest under `build/optimization/artifacts-*.json`. APK checks verify package, declared version, ZIP/native library integrity, per-ABI contents, signature and size budgets. A reference APK, when supplied or preserved in the baseline directory, also verifies certificate continuity. This is the existing development signing identity; no production signing migration is included. Sideload splits retain the declared version code instead of adding ABI multipliers, so future distribution changes do not jump the version unexpectedly. Legacy Play multi-APK publication is not supported by this recipe; use an AAB for a separately approved store release.

`tool/android_size_budgets.json` sets reviewed file-size ceilings; these are not Play download sizes, installed footprints or RAM budgets. CI can call the same build/check commands; a dependency/SDK-driven budget change requires evidence and review. Production builds retain existing R8/resource shrinking and icon tree shaking. `--format analysis` creates a diagnostic ARM64 artifact and Flutter's package-size JSON; its foreign JNI helpers make it distinct from the final split APK. Do not distribute the diagnostic as a substitute for the validated split artifacts.

## Repeatable measurements

```sh
python3 tool/benchmark_plan_a_queries.py --rows 50000 --repetitions 7 --output build/optimization/index-comparison.json
flutter test --no-pub --dart-define=RUN_PLAN_A_BENCHMARKS=true test/performance/plan_a_resources_benchmark_test.dart --concurrency=1 --reporter expanded
flutter test --no-pub --dart-define=CAPTURE_BILL_PDF=true test/business/bill_pdf_service_test.dart --reporter expanded
```

SQL comparisons use a synthetic in-memory host SQLite database and compare identical result IDs. They include index storage and insertion overhead; no real database is opened. Branding/archive microbenchmarks are controlled Flutter-test host comparisons, not phone RAM, battery or FPS results. Measurements from different scripts/fixtures/runs are not directly interchangeable.

Physical-device collection is opt-in and requires a designated test device with synthetic records. It does not install an APK, clear app data, reset battery statistics, dump raw customer logs or write business records:

```sh
python3 tool/profile_android.py --serial DEVICE_SERIAL --dataset-label synthetic-ordinary --confirm-test-device --output build/optimization/device-baseline.json
```

Capture the baseline before upgrading the test database, then use the identical dataset/device/script on the optimized build. The collector records Android activity timings and settled PSS; those are not Flutter useful-screen timing or peak RAM. Warm resumes reuse process startup markers. CPU/network/energy fields remain null until separately profiled. A disconnected device produces no invented baseline.

For Flutter frame and useful-screen markers, use a separate, non-distribution instrumented build:

```sh
flutter run --profile --dart-define=HYNER_PERF=true --dart-define-from-file=build/config/firebase.android.json -d DEVICE_SERIAL
```

Open calculator editing, inventory/customer scrolling, sale/payment, PDF/photo and import/backup scenarios from the audit. `HYNER_PERF` emits only fixed phase names, durations, rolling stage statistics and a process-run identifier; no customer names, prices, IDs, photos or contact details are logged. Its frame window holds at most 240 samples. It is disabled by default in ordinary release builds. `over_60hz_stage_budget_samples` means a build/raster stage exceeded 16.67 ms; it is not a measured FPS/missed-vsync count. Use DevTools/Perfetto for refresh-rate-specific UI/raster/CPU and native/graphics/GC details. Collect PSS during real large operations for peaks, and use a controlled power trace for energy.

No Android device is currently connected. Real 2 GB reliability, launch times, peak RAM, frame timing, native content-provider behavior, share handoff delay and battery remain unverified. iOS has no host project/SDK here; web compilation and host tests do not certify cross-platform workflow parity.

## Data and rollback

Database version 12 adds only three indexes: customer/date, non-null follow-up date, and currency/date. Stored business rows, original pricing snapshots, identity matching, payment logic, WhatsApp preferences and backup row format remain unchanged. Queries keep their current semantics; this is not Plan B's financial-summary/pagination migration. Indexes consume storage and impose write overhead.

The normal business JSON backup does not include every pricing database, preference or profile image. For a full test/recovery snapshot, close/checkpoint SQLite safely and preserve both stores and required associated files; do not copy a live database while ignoring its journal/WAL. Never commit private snapshots.

Do not simply install the original schema-11 binary after version 12 has been opened: it can refuse the newer database. A source rollback must retain version-12/index compatibility in a newly built, correctly signed fallback. Indexes may be retained while query-independent changes are reverted; drop them only in a forward migration if required. Never lower `user_version`, erase records, rewrite published pricing versions or ask a merchant to uninstall as a rollback shortcut.

Branding caches are page-owned, bounded to current original/duplicate variants and invalidated by source image changes. Only prepared pixels are cached; PDF providers are created per document so they cannot retain an old document graph. Preview byte/provider identity survives unrelated form rebuilds and is evicted on replace/dispose. Archive generation is single-flight per account/sale and preserves the first immutable duplicate; metadata checks avoid PDF inflation on normal views. Corrupt archives are reported on explicit export; the earlier rebuilt-export fallback remains available and never overwrites the immutable archive.

Native file jobs use one active worker plus one queued job; completion is dispatched once on the main thread. Activity closure cancels queued results without launching a share from a destroyed activity; an already-open write can finish safely. No persistent service/poller is introduced.

Cleanup is best effort, at most one attempt per day on relevant operations, and inspects at most 1,000 entries per pass. It targets only known generated cache-share PDFs or timestamped temporary backup JSON files older than seven days. Current-process PDF handoffs, active backup paths, session-created backups, symlinks, user-chosen exports, databases and durable duplicate archives are excluded. There is no receiving-app consumption receipt; the seven-day grace and process/session protection are conservative safeguards, not a proof for arbitrarily delayed third-party reads. Native delayed-provider/share compatibility still requires physical-device testing. Disable cleanup independently if those checks reveal a problem.
