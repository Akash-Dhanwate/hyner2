# Hyner 0.9.0 launch implementation

Version: **0.9.0+17**. Business database: **14**. Portable business JSON: **12**. Pricing database: **4**, unchanged. Complete backup envelope: **hyner-full-backup v1**.

This is an Android release candidate for testing. It has not been published to Google Play. No merchant database, live account, signing identity or Firebase deployment was modified during development.

## Permanent bill numbers and export names

Each workspace assigns bill numbers **1, 2, 3, …** inside the sale transaction. Retrying a save retains its original number. Voiding or deleting a bill does not reuse its number. Restoring an older backup preserves the highest number already used on this installation. Numbers do not reset annually. Independent offline devices are independent workspaces; no global cross-device numbering is claimed.

Existing bills receive numbers in `createdAt, id` order during migration. Internal UUIDs remain unchanged, preserving checkout retry identities, customer links, PDFs and inventory movement references. Existing archived duplicate PDFs remain immutable; newly rendered PDFs and export names use the assigned number. Historical PDFs already shared are not renamed.

Export names use **Customer Name - Bill 1.pdf**, with **- Duplicate** for duplicate exports. Reserved filename characters are sanitized. Mobile numbers are excluded from this convention. Bill number is searchable and visible in history, customer history, the dashboard and reports.

## Payments, returns and corrections

- Dated customer and supplier payments record amount, method (cash, UPI, bank, card, other), note/reference, effective date and recorded timestamp. Each operation has a retry identity. Existing payment APIs write the same ledger.
- Reversal entries retain the original receipt or refund. An entry can be reversed once; a correction reason is required. Reversals correct records and do not move money.
- Customer returns select original bill lines, enforce remaining returnable quantities, allocate gross/tax/cost from immutable snapshots, and optionally restore sellable stock in the same transaction. Cumulative integer allocation preserves exact totals across partial measured-item returns.
- A return credit reduces the bill's unpaid amount first. Any excess becomes a customer refund due. Refunds are separately confirmed with a date and payment method. They are records of money moved outside Hyner, not automatic transfers. Refunds cannot exceed available credit.
- A return without restocking records known item cost as a protected operating loss. Unknown purchase costs remain an incomplete-cost limitation; no cost is invented.
- Return history includes a downloadable operational return-credit PDF with line quantities, amounts, included tax adjustment, date, reason and stock treatment. This implementation does not certify jurisdiction-specific tax filing or electronic-invoice requirements.
- **Void bill** preserves the original sale, lines, receipts, duplicate archive and reason. It restores only quantities not already returned and makes any retained payment a refund due. Confirm only when the remaining goods are in the shop's stock.
- **Create replacement bill** opens the normal bill editor and transactionally links the new numbered bill to its void original. One original has one direct replacement. Payments/refunds stay on their original document; automatic payment transfer is not implemented.
- The production local-sales UI uses voiding rather than the old destructive deletion action. The legacy deletion API remains for compatibility; it rejects bills with returns or void corrections.
- Supplier returns create a credit against the purchase; partial payments and refunds received reconcile the remaining balance. Supplier credits are scoped to their original purchase; cross-invoice credit transfer is not implemented.

Financial entries are stored in `financial_entries`; customer returns are stored in `sale_returns`. Legacy payments are migrated without inventing methods. Historical paid balances without known receipt dates are marked `opening_balance` and excluded from payment-date collection totals.

Reports distinguish receipts by payment date from receipts against bills issued in a selected sales period. Voids are excluded from active sales. Return credits restate the original bill period's sales and cost; a separate metric shows credits issued by return date. Positive/negative ledger entries include corrections, so their labels explicitly identify corrections rather than claiming bank-verified cash flow.

## Complete backups and recovery

**Settings → Business backup → Save complete backup** uses the Android save picker and a `.hyner` file. It includes the business register, financial audit rows, bill archives, all pricing tables (including published cards and estimate drafts), scoped profile/onboarding preferences, appearance preferences and required local profile images. Logos/signatures already live in business settings. Tokens, passwords and sign-in mode are excluded. These are readable backups, not encrypted exports.

SHA-256 detects file corruption, not a malicious author's identity. Input and decoded image sizes are bounded. The complete file limit is **64 MiB**. Restoration is restricted to the same workspace/account. Image filenames are content checked and restored into a workspace-specific local namespace. Preference keys/types and database relationships are checked before committing.

Business writes remain locked while the pricing snapshot is captured. Restore validates both stores in rollback-only transactions. It writes a durable previous-state snapshot and journal before replacing data, holds the business transaction through pricing/preferences replacement, and removes the journal only after successful completion. If a commit fails, it restores the previous state. If the process ends mid-restore, startup recovery runs before ordinary providers open their stores. Failure to recover does not silently reset the database.

Old register-only JSON backups remain importable; they cannot recover calculator data or images that they never contained. Full backup creation refuses a missing referenced local profile image. Restore can still repair such a workspace from a healthy full backup. Manually exported/shared files remain under the user's control.

The recovery guarantee has synthetic transaction/process-journal tests. Sudden device power loss, low-storage failures, low-memory Android behavior and hardware file-provider compatibility are not certified by host tests.

## Workspace and account data

Stock adjustment now binds to the workspace that opened the form and dismisses after an account change. Existing checkout, purchase, customer, expense, accounting and document guards were reviewed and exercised by the regression suite. New financial writes recheck their captured workspace after dialogs. A started transaction continues to target the account it captured, never a newly selected account. Ambiguous financial saves retain their operation identity for retry.

**Settings → Privacy and account deletion** explains local storage, optional Firebase sign-in, exports, messaging and deletion. The in-app deletion client and `functions/` service are implemented, but deletion is unavailable until the endpoint is deployed and configured. The service accepts a recent authenticated token, derives the account from that token, recursively deletes only its legacy `users/{uid}` Firestore tree, and removes its Firebase Auth identity. It never accepts a caller-selected deletion path. Local cleanup has a startup completion journal. Previously exported/shared files and records on other devices require separate handling.

No remote account was deleted or service deployed during verification. Firebase emulator/end-to-end deletion and live ownership-verification procedures remain release checks.

## Release setup still requiring owner information

Supply the actual developer/business name, support email and website. Generate reviewable public pages with:

```sh
python3 tool/prepare_release_pages.py \
  --developer-name 'YOUR ACTUAL NAME' \
  --support-email 'YOUR SUPPORT EMAIL' \
  --base-url 'https://YOUR SITE'
```

Review and publish the generated `privacy.html` and `delete-account.html`. The deletion page provides an external email request mechanism; the developer must monitor it and verify ownership before acting. No response-time or legal retention promise is fabricated by the generator. Review the policy against the deployed SDKs, actual operations and any retention obligations before publication.

Deploy the reviewed account service to the intended Firebase project, then configure these public values for the build:

- `HYNER_DEVELOPER_NAME`, `HYNER_SUPPORT_EMAIL`
- `HYNER_PRIVACY_URL`, `HYNER_DELETION_URL`
- `HYNER_ACCOUNT_DELETION_ENDPOINT`

The independent Functions configuration is `firebase.release.json`; its codebase is `hyner-account-services`. Dependencies are pinned in `functions/package-lock.json`. The handler has unit coverage and its Firebase export was loaded successfully, but it has not been deployed or tested against a live Firebase account.

Production builds require externally managed `HYNER_KEYSTORE_PATH`, `HYNER_STORE_PASSWORD`, `HYNER_KEY_ALIAS` and `HYNER_KEY_PASSWORD`. Secrets are never written into the build's Dart configuration. The existing development certificate remains the default for test APKs. No new signing key was generated and no existing identity was replaced.

```sh
python3 tool/build_android.py --production --format bundle --label launch
```

This command fails before building if required release values/signing inputs are absent. A production signing/update plan must address existing development-signed installs before public distribution. The script does not upload to Play or publish any service.

Complete Play Console declarations, account-specific testing requirements, listing assets and physical-device acceptance on the exact signed candidate. No Android device was connected during this implementation.

## Verification

- Dart analysis: clean (`build/launch-analyze.log`).
- Full Flutter regression suite: **801 passed, 4 skipped, 0 failed** (`build/launch-all-tests-release.log`).
- Android native unit tests: **8 passed, 0 failures** (`build/launch-native-tests.log`).
- Account-deletion handler: **5 passed**, including token ownership, recent sign-in, explicit confirmation, failure reporting and idempotent retries.
- Firebase function module: imports successfully with the pinned Admin/Functions dependencies.
- Python release tools: compile successfully.
- Android split APK build: passed for ARM64, ARMv7 and x86_64, including package/version/ABI/signature/checksum/size checks. Manifest: `build/optimization/artifacts-launch-ready-split.json`. The APKs retain the development certificate for sideload testing.

New coverage includes concurrent consecutive numbering, schema-13 migration, retry-safe returns, exact measured gross/tax allocation, payment reversals, non-restocked losses, collection-date reports, supplier reconciliation, full-store/image recovery, corruption rejection, published-card immutability after restore, a coordinated backup with a queued writer, and stock-dialog dismissal on account change.

Earlier test fixtures that assumed pre-numbering schemas were updated to assert preserved business fields plus the new metadata. Inventory setup tests now exercise an owner workspace rather than an explicitly transient browser preview, and reflect the existing 100/10 stock defaults and calculator-rate synchronization.
