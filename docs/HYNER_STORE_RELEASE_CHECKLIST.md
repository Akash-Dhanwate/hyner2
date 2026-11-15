# Hyner Google Play Store Release Checklist

**Assessment date:** 2026-11-14  
**Package in source:** `com.hyner.hyner`  
**App version in `pubspec.yaml`:** `0.8.4+16`  
**Release decision:** **NO-GO for public Play release**. The source still selects Android debug signing for `release`; privacy policy/data-safety/account deletion materials and a signed release verification are not present. This checklist is an engineering readiness review, not legal advice or a substitute for completing Play Console declarations.

Status means: **PASSED** = verified from current repository or safely executed check; **FAILED** = a concrete blocker is present; **NOT VERIFIED** = external/account/device evidence is required; **NOT APPLICABLE** = checked and not relevant to the current implementation.

## 1. Android build and platform requirements

| Check | Status | Evidence / action |
|---|---|---|
| Package ID and displayed name | PASSED | `android/app/build.gradle.kts` declares `com.hyner.hyner`; manifest label is `Hyner`. Confirm the final Play listing identity before first publication. |
| Version metadata | PASSED | `pubspec.yaml` declares `0.8.4+16`; increment version code for each uploaded update. |
| Target SDK for 2026 Play policy | PARTIAL | Android 16 / API 36 is the current requirement for new apps and updates from 2026-08-31. The built arm64 APK manifest reports target 36 (min 24), but no AAB was generated, so inspect the actual Play bundle before upload. Gradle delegates SDK values to Flutter. [Target API requirement](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-en) |
| Android 16 behavior | NOT VERIFIED | Test API 36 edge-to-edge, insets, large-screen resizability, back navigation, file picker and notifications. [Android 16 behavior changes](https://developer.android.com/about/versions/16/behavior-changes-16) |
| Minimum supported SDK | PARTIAL | The built arm64 APK manifest reports min SDK 24. The source delegates to `flutter.minSdkVersion`; verify the AAB manifest and confirm supported-device coverage before upload. |
| Play upload format | NOT VERIFIED | Prepare and validate an Android App Bundle (`.aab`) for Play upload; this pass did not produce a release bundle. [Android App Bundle](https://support.google.com/googleplay/android-developer/answer/9844279?hl=en) |
| Production signing | FAILED | `android/app/build.gradle.kts` sets release `signingConfig` to the debug signing config. A debug-signed, per-ABI APK set was built for sideload testing, not Play. Prepare a secured upload key and Play App Signing plan. Do not change signing identity for an already-distributed app without checking update compatibility. [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en) |
| CI/reproducible release build | NOT VERIFIED | `python3 tool/build_android.py --format split --no-pub --label premium-ui` produced validated per-ABI APKs, not a Play AAB. No release AAB pipeline was verified in this pass. A debug-signed APK is not a Play release artifact. |

## 2. Permissions and data handling

| Check | Status | Evidence / action |
|---|---|---|
| Manifest permissions | PASSED (source review) | `android/app/src/main/AndroidManifest.xml` explicitly declares `INTERNET` and `POST_NOTIFICATIONS`; no broad storage permission is declared. The notification permission should remain contextual to notification setup. Recheck merged release manifest and transitive SDK permissions. |
| Data collection inventory | NOT VERIFIED | Source shows Firebase Authentication/Google Sign-In, local SQLite business records, SharedPreferences, customer and business details, and PDFs/backups that users can export/share. Obtain an SDK-level data inventory and document purposes, retention, processing, and sharing before Data Safety submission. No production account or customer records were inspected. |
| Privacy policy URL and in-app link | FAILED | No privacy-policy document, public URL, or discoverable in-app policy entry was found in this repository search. Publish a truthful public policy, add an in-app link, and use the same active URL in Play Console. Do not submit a fabricated declaration. [User Data and privacy policy requirements](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en) |
| Data Safety declaration | NOT VERIFIED | Play Console declarations must match actual code, SDK behavior, user-initiated sharing, and policy. Complete after a verified data inventory; do not infer “no collection” merely because the business database is local. [Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-en) |
| Account creation and deletion | FAILED / product decision required | Firebase account sign-in/account setup exists. No in-app account deletion action or external account deletion web resource was found. Apps that let users create accounts must provide a readily discoverable deletion request path both in-app and externally, subject to the policy's retention rules. Business financial records cannot be silently deleted without an approved lawful retention and data separation strategy. Decide retention, account/business ownership, and deletion behavior before implementation and Play submission. [Account deletion policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en-GB) |
| Local backup confidentiality | NOT VERIFIED | Backup is user-exported local data and may contain sensitive business/customer information. Verify current encryption, integrity, format, file permissions and user warnings; do not assume Android device encryption protects an exported file after it leaves the app. |
| Shared PDF privacy | PARTIAL | Bill filenames can include customer mobile by default, with an opt-out in Settings. The share action is user initiated. Test recipient apps and ensure filenames/attachments do not enter analytics or diagnostics. |
| Account access test instructions | NOT VERIFIED | If sign-in is required for reviewer-visible areas, prepare working review credentials and clear access instructions without embedding credentials in the public listing. Verify those credentials in Play Console's App access section. [App access instructions](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en-en) |

## 3. Play Console declarations and listing materials

| Check | Status | Evidence / action |
|---|---|---|
| Content rating | NOT VERIFIED | Complete the current questionnaire in Play Console based on actual content and functionality. Do not choose a rating from assumptions. [Content ratings](https://support.google.com/googleplay/android-developer/answer/9898843?hl=en) |
| Advertising declaration | NOT VERIFIED | No ad SDK was identified in `pubspec.yaml`, but confirm transitive/native dependencies and declare accurately in Console. |
| Target audience / families | NOT VERIFIED | Determine intended age group and complete the Play Console declarations. No child-directed feature is inferred here. |
| Store icon and screenshots | PARTIAL | Android launcher icon and splash resources exist under `android/app/src/main/res`; Google Play listing screenshots, feature graphic, and verified device captures were not found/created. Capture actual current screens; do not advertise unimplemented sync or accounting. |
| App name and description | NOT VERIFIED | Draft below is factual starting copy only; review for supported claims, translation, length, and Play policy before submission. |
| Developer identity and contact | NOT VERIFIED | Must be supplied and verified in Play Console; not available in source. |
| Developer-account verification/testing eligibility | NOT VERIFIED | Depends on the actual developer account type, creation date, and Play Console status. For qualifying newer personal accounts, closed testing currently requires at least 12 opted-in testers for 14 continuous days before production access; confirm the account-specific rule and console task. [Personal account testing](https://support.google.com/googleplay/android-developer/answer/14151465) |
| Physical Android device checks | NOT VERIFIED | No physical device validation was executed in this pass. |

### Truthful store listing draft

**Short description:** Manage shop products, create bills, and calculate custom product prices.

**Full description draft:**

> Hyner helps small shops keep product and stock records, calculate prices for configured products, prepare estimates, create bills, record payments, and review sales and expenses. Business records are stored on your device. You can export a backup using the app's backup tools. Signing in does not automatically synchronize business records between devices. PDF bills can be saved or shared from the app. Features and available screens may vary by device.

Before publication, validate every claim against the exact release build and approved privacy/data-handling disclosures. Do not claim multi-device synchronization, automatic cloud backup, verified UPI payments, complete accounting, or automatic WhatsApp delivery.

## 4. Platform and quality gates

| Check | Status | Notes |
|---|---|---|
| Startup and route smoke test | PARTIAL | Flutter navigation and auth tests pass in the current focused suite; physical cold start and update-over-existing install not tested here. |
| Authentication | PARTIAL | Existing sign-in tests cover controlled test cases; real Google/email provider configuration and Play reviewer access are environment/account dependent. |
| Offline business operations | NOT VERIFIED (device) | Local SQLite is the current business data layer, but run a real airplane-mode transaction and restart test on release build. |
| Migration/upgrade safety | NOT VERIFIED (device) | No destructive migration was run. Execute upgrade tests with synthetic prior-version data before release. |
| PDF save/share/print | PARTIAL | Naming helper and native sanitizer have unit tests; Android picker, print service, generic shares, WhatsApp and recipient handoff need physical-device checks. |
| Backup/restore | NOT VERIFIED for release | Test complete supported data coverage, malformed backup rejection, interruption behavior, and recovery using disposable synthetic workspaces. |
| Billing/inventory integrity | NOT VERIFIED for release | Run transaction-level regression scenarios from the business-readiness audit against synthetic data and the exact release build. |
| Accessibility and Android 16 | NOT VERIFIED | Verify large text, TalkBack, contrast, reduced motion, edge-to-edge, predictive/system back, keyboard and narrow layout on supported devices. |
| Store review notes | NOT VERIFIED | Prepare accurate instructions for account-protected flows and any required setup. |

## 5. Other platforms

Android is the intended release target. The repository has a `web/` directory, but the business register relies on local SQLite and web QuickPrice has a different, transient boundary. No iOS, Windows, macOS, or Linux runner directories were verified in the source snapshot. Do not claim those platforms are release ready because the UI uses Flutter.

## 6. Required actions before GO

1. Select and secure production signing; verify package/update-key continuity.
2. Build a release AAB, inspect its target/min SDK and merged permissions, and test the signed artifact.
3. Make an approved account/business deletion and retention design; implement both required request paths where applicable.
4. Publish a truthful privacy policy, add an in-app entry, and complete Data Safety from an SDK/data-flow inventory.
5. Complete Console content rating, advertising, audience, app access, developer account and testing-track requirements.
6. Run upgrade, offline, backup/restore, billing/inventory, PDF, account and accessibility checks on designated Android devices.
7. Capture accurate Play listing assets from the release candidate and review all store copy.

**Current decision: NO-GO for public production release.** A limited internal build may be used for testing only after its signing and test-data handling are understood. This decision is based on the concrete debug-signing configuration and missing privacy/account deletion release work, not on visual polish or compilation status.
