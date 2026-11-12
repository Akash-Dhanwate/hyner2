#!/usr/bin/env python3
"""Synthetic host comparison only; never opens an application/user database."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import statistics
import time

INDEXES = {
    'sales_customer_created': 'CREATE INDEX sales_customer_created ON sales(customerId, createdAt DESC, id DESC)',
    'sales_followup_due': 'CREATE INDEX sales_followup_due ON sales(followupAt) WHERE followupAt IS NOT NULL',
    'sales_currency_created': 'CREATE INDEX sales_currency_created ON sales(currency, createdAt DESC, id DESC)',
}


def build(rows):
    db = sqlite3.connect(':memory:')
    source = (Path(__file__).resolve().parents[1] / 'lib/core/storage/local_business_database.dart').read_text()
    db.execute(re.search(r'CREATE TABLE sales \([\s\S]*?\n\s*\)', source).group(0))
    db.execute('CREATE INDEX sales_created ON sales(createdAt DESC,id DESC)')
    lines = json.dumps([{'sku': 'A', 'name': 'Panel', 'unitPriceMinor': 12550, 'unitCostMinor': 10000, 'quantity': 2}] * 3)
    for i in range(rows):
        stamp = f'2026-{i % 12 + 1:02}-{i % 28 + 1:02}T12:00:00.000Z'
        db.execute('INSERT INTO sales(id,currency,lines,customerId,paymentStatus,createdAt,followupAt) VALUES(?,?,?,?,?,?,?)',
                   (f'b{i:08}', 'USD' if i % 10 == 0 else 'INR', lines, None if i % 20 == 0 else f'c{i % 5000}', 'unpaid', stamp, stamp if i % 100 == 1 else None))
    db.commit()
    return db, lines


def measure(db, repetitions):
    db.execute('ANALYZE')
    queries = {
        'customer_history': ('SELECT * FROM sales WHERE customerId IN (?) OR customerId IS NULL ORDER BY createdAt DESC,id DESC', ('c1',)),
        'followups': ('SELECT * FROM sales WHERE followupAt IS NOT NULL ORDER BY followupAt ASC', ()),
        'month_inr': ('SELECT * FROM sales WHERE currency=? AND createdAt>=? AND createdAt<? ORDER BY createdAt DESC', ('INR', '2026-11-01T00:00:00.000Z', '2026-12-01T00:00:00.000Z')),
        'month_usd': ('SELECT * FROM sales WHERE currency=? AND createdAt>=? AND createdAt<? ORDER BY createdAt DESC', ('USD', '2026-11-01T00:00:00.000Z', '2026-12-01T00:00:00.000Z')),
        'sales_page': ('SELECT * FROM sales ORDER BY createdAt DESC,id DESC LIMIT 31', ()),
    }
    result = {}
    for name, (sql, parameters) in queries.items():
        plan = [r[3] for r in db.execute('EXPLAIN QUERY PLAN ' + sql, parameters)]
        times = []
        for _ in range(repetitions):
            start = time.perf_counter()
            found = db.execute(sql, parameters).fetchall()
            times.append((time.perf_counter() - start) * 1000)
        result[name] = {'rows': len(found), 'median_ms': statistics.median(times), 'plan': plan,
                        'result_ids_sha256': hashlib.sha256(json.dumps(sorted(row[0] for row in found)).encode()).hexdigest()}
    result['database_allocated_bytes'] = db.execute('PRAGMA page_count').fetchone()[0] * db.execute('PRAGMA page_size').fetchone()[0]
    write_times = []
    for _ in range(3):
        db.execute('SAVEPOINT benchmark_writes')
        start = time.perf_counter()
        for i in range(1000):
            db.execute('INSERT INTO sales(id,currency,lines,customerId,paymentStatus,createdAt,followupAt) VALUES(?,?,?,?,?,?,?)',
                       (f'write{i}', 'INR', '[]', f'c{i}', 'unpaid', '2026-11-10T12:00:00.000Z', '2026-11-11T12:00:00.000Z'))
        write_times.append((time.perf_counter() - start) * 1000)
        db.execute('ROLLBACK TO benchmark_writes')
        db.execute('RELEASE benchmark_writes')
    result['insert_1000_median_ms_no_disk_sync'] = statistics.median(write_times)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rows', type=int, default=50000)
    parser.add_argument('--repetitions', type=int, default=7)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.rows < 100 or args.repetitions < 3:
        parser.error('Use at least 100 synthetic rows and 3 repetitions.')
    db, lines = build(args.rows)
    before = measure(db, args.repetitions)
    for sql in INDEXES.values():
        db.execute(sql)
    after = measure(db, args.repetitions)
    for name in ['customer_history', 'followups', 'month_inr', 'month_usd', 'sales_page']:
        assert before[name]['result_ids_sha256'] == after[name]['result_ids_sha256'], name
    output = {'kind': 'synthetic in-memory desktop SQLite; not device latency', 'sqlite': sqlite3.sqlite_version,
              'sales': args.rows, 'repetitions': args.repetitions, 'candidate_indexes': INDEXES, 'before': before, 'after': after}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps(output, indent=2))
    db.close()


if __name__ == '__main__':
    main()
