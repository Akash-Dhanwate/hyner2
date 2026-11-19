import 'package:drift/drift.dart';

part 'pricing_database.g.dart';

@DriftDatabase(include: {'pricing.drift'})
class PricingDatabase extends _$PricingDatabase {
  PricingDatabase(super.executor);

  Future<Map<String, dynamic>> exportPortable() => transaction(() async {
    final records = <String, dynamic>{};
    for (final table in allTables) {
      records[table.actualTableName] = [
        for (final row in await customSelect(
          'SELECT * FROM "${table.actualTableName}"',
        ).get())
          row.data,
      ];
    }
    return {'schemaVersion': schemaVersion, 'tables': records};
  });

  Future<void> restorePortable(
    Map<String, dynamic> snapshot, {
    bool validateOnly = false,
  }) async {
    final tables = snapshot['tables'];
    final names = allTables.map((t) => t.actualTableName).toSet();
    if (snapshot['schemaVersion'] != schemaVersion ||
        tables is! Map ||
        tables.length != names.length ||
        !names.every((name) => tables[name] is List)) {
      throw const FormatException('Unsupported calculator backup schema.');
    }
    try {
      await transaction(() async {
        // Deferred checks validate the complete graph at the transaction boundary.
        await customStatement('PRAGMA defer_foreign_keys = ON');
        final triggers = await customSelect(
          "SELECT name,sql FROM sqlite_master WHERE type='trigger'",
        ).get();
        for (final trigger in triggers) {
          final name = trigger.read<String>('name').replaceAll('"', '""');
          await customStatement('DROP TRIGGER "$name"');
        }
        for (final name in names) {
          await customStatement('DELETE FROM "$name"');
        }
        for (final table in allTables) {
          final allowed = table.$columns.map((c) => c.$name).toSet();
          for (final raw in tables[table.actualTableName] as List) {
            if (raw is! Map ||
                raw.isEmpty ||
                raw.keys.any((key) => !allowed.contains(key)) ||
                raw.values.any((v) => v != null && v is! String && v is! num)) {
              throw const FormatException('Invalid calculator backup row.');
            }
            final columns = raw.keys.cast<String>().toList();
            await customStatement(
              'INSERT INTO "${table.actualTableName}" (${columns.map((c) => '"$c"').join(',')}) VALUES (${List.filled(columns.length, '?').join(',')})',
              [for (final c in columns) raw[c]],
            );
          }
        }
        if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
          throw const FormatException(
            'Calculator backup relationships are invalid.',
          );
        }
        for (final trigger in triggers) {
          await customStatement(trigger.read<String>('sql'));
        }
        if (validateOnly) throw const _PricingValidationRollback();
      });
    } on _PricingValidationRollback {
      /* Validated without committing. */
    }
  }

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

class _PricingValidationRollback implements Exception {
  const _PricingValidationRollback();
}
