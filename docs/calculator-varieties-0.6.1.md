# QuickPrice varieties and negotiated rates — Android 0.6.1+9

This release includes the earlier business/billing features and approved Plan A optimizations, and adds product varieties inside each saved calculator.

## Use

1. Open QuickPrice. Create a calculator, or open **More options → Edit selling rates** for an existing calculator.
2. Under a product, tap **Add variety**. Name each type (for example, Flush and Laminated) and enter its selling rate. The first is selected by default. Use **Add variety** again for more types, or **Add another product** for a different product. Save and use the calculator.
3. Choose **Variety** during calculation. Height, width, units and quantity stay in place; the selected variety's rate recalculates the item.
4. Edit the visible **Customer rate** for a negotiated selling rate. It uses the displayed unit, such as INR/ft²; it is not an override of the entire bill total. **Use saved rate** restores the configured amount. Switching variety resets the negotiated rate to that variety's saved rate.
5. Add each item to the estimate, then continue to Sales. The selected variety, measurements and exact agreed amount are saved with each item. Changing calculator rates later does not rewrite previously captured estimate or bill items.

Example with no tax/extras: 7 ft × 3 ft at a Laminated rate of INR 175/ft² totals INR 3,675. Negotiating that item to INR 155/ft² changes the total to INR 3,255. Switching to Flush at INR 150/ft² totals INR 3,150 while keeping 7 × 3 measurements. Existing tax, discount and add-on policies continue to apply.

## Preservation and implementation

- Uses the existing choice-input and selector-rate engine. No database schema, auth, security, stock, payment or backup-format change was required.
- Saved variety prices publish through the existing immutable rate-card version process. Optional editor metadata is kept consistent; existing varieties are reconstructed from the durable rule when editing.
- Negotiation replaces only the resolved base rate for the current calculation, including its selectors. Other rates, dimensions, billing adjustments, extras, tax, discounts and rounding stay in place.
- Existing advanced rate schedules retain their original simple fallback-rate editing behavior. Adding simple varieties to a schedule with other advanced selectors directs the owner to Advanced settings rather than flattening those rules.
- Up to 100 named varieties per product. Names must be distinct, nonblank, at most 120 characters and without commas (the advanced editor uses comma-separated choices). Saved variety rates must be greater than zero and within the engine's existing monetary limits.
- Existing archive/payment/customer history, WhatsApp, measurement and bill-colour work remains included. No existing feature was intentionally removed.

Application paths: `lib/features/pricing/application/{simple_calculator,calculator_session}.dart`, `lib/features/pricing/presentation/{simple_calculator_screen,quickprice_screen}.dart`. Version updated in `pubspec.yaml` and Settings. The build helper accepts `--label varieties` to preserve earlier release artifacts.

## Verification

- Full suite: **690 Flutter tests passed, four opt-in tests skipped**. The new domain and widget tests cover creation/editing, rate switching, exact negotiation, selector preservation, unchanged measurements, immutable prior quotes, tax/discount/add-on policy preservation, invalid inputs, advanced-schedule preservation, SQLite reopen and saved customer-bill amounts.
- The owner flow also passed with real app fonts loaded. Setup/calculator captures were visually inspected. It includes 320-pixel layout with keyboard checks; existing enlarged-text and checkout regression tests pass.
- Static analysis: no issues found. Formatting and Python helper compilation pass.
- ARM32, ARM64, x86_64 and universal Android release builds completed. Package/version/signature/ABI/ZIP/checksum/size checks pass. The new UI strings are present in each ABI's compiled application library; ordinary shipping profiling remains disabled.
- Web release compilation and Wasm dry run pass. Existing web workflow limitations are unchanged. No iOS host build is available.
- No Android device is connected. Installation/update, native WhatsApp/printing/provider interactions and physical RAM/FPS/battery behavior remain unverified. No real merchant data was opened or modified during testing.

## Release artifacts

All APKs are version **0.6.1**, version code **9**, package `com.hyner.hyner`, with the same signing identity as the preceding APK. Choose the ABI matching Android userspace, or use the universal fallback. Install as an update; do not uninstall or clear app data.

| APK | File bytes | Decimal MB |
|---|---:|---:|
| `hyner-0.6.1-varieties-arm64-v8a.apk` | 27,775,463 | 27.78 |
| `hyner-0.6.1-varieties-armeabi-v7a.apk` | 25,889,329 | 25.89 |
| `hyner-0.6.1-varieties-x86_64.apk` | 29,355,400 | 29.36 |
| `hyner-0.6.1-varieties-universal.apk` | 77,312,134 | 77.31 |

Files and SHA-256 sidecars are under `build/app/outputs/flutter-apk/`. Evidence manifests are `build/optimization/artifacts-varieties-{split,universal}.json`; test/build logs and visual captures are under `build/feature-varieties/`.

```sh
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
python3 tool/build_android.py --format split --no-pub --label varieties
python3 tool/build_android.py --format universal --no-pub --label varieties
flutter build web --release --no-pub
```

Source files and the pre-feature diff were preserved under `build/feature-varieties/before/`; the separate Plan A baseline remains intact. Database schema remains 12. Any source rollback must retain schema-12 compatibility, preserve stored records and signing continuity, and use a reviewed forward release rather than uninstalling or forcing a data-destructive downgrade.
