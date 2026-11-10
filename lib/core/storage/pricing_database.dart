import 'package:drift/drift.dart';

part 'pricing_database.g.dart';

@DriftDatabase(include: {'pricing.drift'})
class PricingDatabase extends _$PricingDatabase {
  PricingDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // V4 adds device-owned workspace state without changing pricing snapshots.
      if (from < 1 || from > 3 || to != 4) {
        throw StateError('Unsupported pricing database upgrade: $from → $to');
      }
      for (final entity in allSchemaEntities) {
        if ((from == 1 &&
                entity.entityName != 'pricing_profiles' &&
                entity.entityName != 'pricing_drafts') ||
            (from == 2 && entity.entityName.startsWith('universal_pricing_')) ||
            (from >= 2 &&
                const {
                  'pricing_device_workspace',
                  'pricing_workspace_values',
                  'pricing_local_tax_approvals',
                }.contains(entity.entityName))) {
          await m.create(entity);
        }
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _installImmutabilityGuards();
      await _installUniversalGuards();
      final errors = await customSelect('PRAGMA foreign_key_check').get();
      if (errors.isNotEmpty) {
        throw StateError('Pricing database relationship validation failed');
      }
    },
  );

  Future<void> _installUniversalGuards() async {
    for (final operation in ['UPDATE', 'DELETE']) {
      await customStatement(
        '''CREATE TRIGGER IF NOT EXISTS universal_versions_no_${operation.toLowerCase()}
        BEFORE $operation ON universal_pricing_versions WHEN OLD.sealed = 1
        BEGIN SELECT RAISE(ABORT, 'Published rate cards are immutable'); END''',
      );
      await customStatement(
        '''CREATE TRIGGER IF NOT EXISTS universal_audit_no_${operation.toLowerCase()}
        BEFORE $operation ON universal_pricing_audit_events
        BEGIN SELECT RAISE(ABORT, 'Audit events are immutable'); END''',
      );
    }
    for (final table in [
      'categories',
      'products',
      'inputs',
      'rates',
      'unit_systems',
      'dimension_rules',
      'addons',
    ]) {
      final name = 'universal_pricing_$table';
      for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
        final row = operation == 'INSERT' ? 'NEW' : 'OLD';
        await customStatement(
          '''CREATE TRIGGER IF NOT EXISTS ${name}_guard_${operation.toLowerCase()}
          BEFORE $operation ON $name
          WHEN (SELECT sealed FROM universal_pricing_versions WHERE business_id = $row.business_id
            AND profile_id = $row.profile_id AND version = $row.version) = 1
          BEGIN SELECT RAISE(ABORT, 'Published pricing data is immutable'); END''',
        );
      }
      await customStatement(
        '''CREATE TRIGGER IF NOT EXISTS ${name}_guard_move
        BEFORE UPDATE ON $name
        WHEN (SELECT sealed FROM universal_pricing_versions WHERE business_id = NEW.business_id
          AND profile_id = NEW.profile_id AND version = NEW.version) = 1
        BEGIN SELECT RAISE(ABORT, 'Published pricing data is immutable'); END''',
      );
    }
  }

  Future<void> _installImmutabilityGuards() async {
    for (final operation in ['UPDATE', 'DELETE']) {
      await customStatement(
        '''CREATE TRIGGER IF NOT EXISTS pricing_versions_no_${operation.toLowerCase()}
        BEFORE $operation ON pricing_rate_card_versions WHEN OLD.sealed = 1
        BEGIN SELECT RAISE(ABORT, 'Published rate cards are immutable'); END''',
      );
      await customStatement(
        '''CREATE TRIGGER IF NOT EXISTS pricing_audit_no_${operation.toLowerCase()}
        BEFORE $operation ON pricing_audit_events
        BEGIN SELECT RAISE(ABORT, 'Audit events are immutable'); END''',
      );
    }
    for (final table in [
      'pricing_categories',
      'pricing_variants',
      'pricing_rule_versions',
      'pricing_addons',
      'pricing_rule_addons',
    ]) {
      for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
        final row = operation == 'INSERT' ? 'NEW' : 'OLD';
        await customStatement(
          '''CREATE TRIGGER IF NOT EXISTS ${table}_guard_${operation.toLowerCase()}
          BEFORE $operation ON $table
          WHEN (SELECT sealed FROM pricing_rate_card_versions WHERE business_id = $row.business_id
            AND profile_id = $row.profile_id AND version = $row.version) = 1
          BEGIN SELECT RAISE(ABORT, 'Published pricing data is immutable'); END''',
        );
      }
      // Also reject moving a row from an unsealed version into a sealed one.
      await customStatement(
        '''CREATE TRIGGER IF NOT EXISTS ${table}_guard_move
        BEFORE UPDATE ON $table
        WHEN (SELECT sealed FROM pricing_rate_card_versions WHERE business_id = NEW.business_id
          AND profile_id = NEW.profile_id AND version = NEW.version) = 1
        BEGIN SELECT RAISE(ABORT, 'Published pricing data is immutable'); END''',
      );
    }
  }
}
