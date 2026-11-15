# Bill deletion — 0.8.1+13

Open **Sales → Saved bills → select a bill → Delete bill**, below Bill total.
Review the customer, reference, amount and consequences, then confirm **Delete
bill**. Cancel leaves the bill unchanged. Unlike customer contact corrections,
deletion is available on older bills too.

Use deletion for an incorrect or cancelled sale, when its goods remain in or
have returned to inventory. It permanently removes the bill, its recorded
payments, scheduled follow-up and locally archived duplicate PDF. Sales,
receipts/due totals, profit reports and customer bill history recalculate from
the remaining records. Saved customer profiles and other bills remain.

Each inventory line restores its sold quantity to the current product quantity,
preserving later purchases/sales/adjustments. Archived products receiving stock
become active again. Custom QuickPrice lines never change inventory. A positive
stock adjustment records the deletion; the original stock movements remain.

Deletion does not transfer or refund money and cannot remove copies already
downloaded, printed or sent to another app. The confirmation identifies recorded
payments and explains that any refund must be settled separately. There is no
undo operation.

All database changes happen in one transaction. Missing products, stock/revision
overflow or payment changes after confirmation reject deletion without partial
writes. A repeated deletion does not restore stock twice. A minimal deletion
record retains the bill reference, timestamps, currency, total and recorded paid
amount in the existing settings table. It blocks stale checkout retries from
recreating the same bill. Opening a deleted bill explains that a new estimate or
bill is needed. Deletion records and stock history survive backup/restore.

The confirmation scrolls on narrow screens, blocks duplicate submissions while
saving, displays failures with retry, and dismisses when the account changes.
Sales, recent bills, customer history, balances, reports, product details and stock
alerts refresh after successful deletion. Background duplicate generation cannot
recreate a deleted archive because archive writes require an existing sale.

No dependency, database schema or backup format change is required. Existing
0.8.0 features and data are retained. Install 0.8.1 over the current app without
uninstalling or clearing app data.

Verification logs are `build/bill-deletion-tests.log`,
`build/bill-deletion-analyze.log` and `build/bill-deletion-all-tests.log`.
Database tests cover stock/payment/report consistency, backup restoration,
retry protection, transaction rollback, inventory limits, archived products,
custom price lines and account isolation. Widget tests cover confirmation,
cancellation, failure/retry, pending saves, account changes and 320dp large text.
Physical-device installation and sharing/printing remain untested in this task.

## Verified release

- Code analysis: no issues.
- Full test suite: 742 passed, four existing opt-in tests skipped.
- Final focused database and screen suite: 37 passed.
- Split and universal APKs: package `com.hyner.hyner`, version 0.8.1, version code 13, previous signing certificate retained. Source fingerprints and corresponding ABI AOT library hashes match.

- `hyner-0.8.1-bill-deletion-armeabi-v7a.apk`: 26,234,369 bytes. SHA-256: `688e05f6b48974294f148929760e94d53fb7e4e4ce922231eca11bdc05db424e`.
- `hyner-0.8.1-bill-deletion-arm64-v8a.apk`: 28,120,503 bytes. SHA-256: `a047b433863fda3cf3ba830087425a15d88c4c9ee0295aefe98e6b83105ff115`.
- `hyner-0.8.1-bill-deletion-x86_64.apk`: 29,700,440 bytes. SHA-256: `e3dd216c89ee1e37ff382eb746b1ad9bb705e425a23ae892dda1bc7e418a24ea`.
- `hyner-0.8.1-bill-deletion-universal.apk`: 78,312,534 bytes. SHA-256: `8f17ff1892622502b2802c5a9de60b867ae8a2279872b73eb1bed9eb5322e186`.
