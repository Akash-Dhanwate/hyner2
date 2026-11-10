# Android Firebase setup — 2026-11-08

Historical setup record. The current 0.2.0+4 build includes the merchant setup
wizard and calculator; see [Stages C–D](universal-stages-c-d.md) for current
verification and remaining integrations. The shell/build details below describe
the earlier 0.1.0+3 artifact.

This change connects the native Android Firebase SDK to the merchant's existing
project. It is separate from the staged pricing roadmap. Universal Stage A is
still the completed pricing stage; Stage B has not started.

## Verified registration

- Firebase project: `hyner-541ad`, number `746350362575`.
- Android application ID: `com.hyner.hyner`.
- Firebase Android app ID: `1:746350362575:android:5927a4265e5de1b7419cba`.
- Configuration: `android/app/google-services.json`, supplied by the user.
- Read-only Firebase CLI calls confirmed the project/app registration and the
  registered SHA-1 matching the current APK signer:
  `CE:7E:4F:34:BC:7E:82:22:C7:D0:AE:AC:A4:57:CE:61:68:27:85:73`.
- No web app was listed in this project. Web must get its own registered options
  before Firebase can initialize there; Android credentials are not reused.

## Implementation

`firebase_core` 5.1.0 and Google Services Gradle plugin 4.5.0 initialize the native
default app using generated Android resources. The release manifest now has the
internet permission. `flutter_web_plugins` is declared explicitly because the
generated web plugin registrant imports it.

The Flutter shell opens without waiting for Firebase. Initialization checks the
project and app IDs and returns an explicit ready/unconfigured/unavailable state.
A ten-second timeout or initialization failure leaves the shell accessible.
Timeout does not cancel a native initialization already in progress; its late
completion cannot start sync. Ready means local SDK configuration loaded, not
server reachability, authentication, authorization or a successful data sync.

No network probe is added to pricing calculations. No existing engine, snapshot,
database schema or repository permission policy is changed. No authentication
session, owner role or business membership is manufactured from this config.

## Boundaries and next work

This build still displays the development shell, not the merchant calculator.
It does not yet sign users in or synchronize rate cards, estimates, stock or
invoices. Firebase configuration alone cannot implement that workflow.

The existing Hyner source inspected has user-scoped inventory/sales contracts;
it does not provide the business membership and published pricing authorization
contract needed by universal QuickPrice. Live Firestore data and deployed rules
were not read or changed. No rules, indexes, functions or other Firebase resources
were deployed. Authentication providers were not changed or verified.

Stage B must first persist universal rule definitions and immutable versions.
Subsequent cloud integration needs authenticated business membership, backend
permission checks, approved published-rate downloads, account-scoped local
caches, and explicit conflict/offline policies. Quotations and invoices must use
the existing authoritative transaction contracts. Do not enable permissive
Firestore rules to bypass these requirements.

## Verification

The focused bootstrap tests cover matching and mismatched configuration,
unsupported platforms, failures, timeout, rendering before initialization
finishes, and the explicit absence of pricing sync. SDK initialization is
injected in these tests; they do not exercise Firebase on an Android device.

- Formatting: 28 Dart files checked, no pending changes.
- `flutter analyze`: passed, no issues.
- `flutter test --reporter expanded`: all 305 tests passed (296 existing + 9 new).
- Chrome bootstrap and shell tests: all 10 passed.
- Android release APK: passed; version `0.1.0+3`, package `com.hyner.hyner`,
  minimum Android API 24, target API 36. APK signature verification passed, and
  generated Firebase resources contain the expected project/app IDs.
- Web release build: passed, including the Wasm compatibility dry run. The
  initial attempt failed because `flutter_web_plugins` was absent; declaring
  the SDK dependency resolved the generated registrant error.
- Android build reported a non-failing upstream `firebase_core` Kotlin Gradle
  plugin migration warning. The host tests also reported missing optional iOS
  SDKs and the existing Drift multiple-database test warning; the suite passed.

APK: `build/app/outputs/flutter-apk/app-release.apk` (50.3 MB as reported by
Flutter). SHA-256:
`a5423696711c994ebc2b0ccec25bac9aaa20dbb5c60cff2177fc2c8caec6bd79`.

Reproduce with `flutter pub get`, `flutter analyze`, `flutter test`,
`flutter test --platform chrome test/firebase_bootstrap_test.dart test/app_smoke_test.dart`,
`flutter build apk --release`, and `flutter build web --release`.

No Android device or configured emulator was available. Android startup,
authentication, live synchronization, physical-device performance and offline
restart behavior therefore have not been verified on-device.

The APK uses the existing debug signing key for installation/testing. Production
distribution still needs its release signing configuration and registered
release certificate fingerprints.

Setup follows the official
[Flutter setup](https://firebase.google.com/docs/flutter/setup) and
[Android setup](https://firebase.google.com/docs/android/setup) documentation.
