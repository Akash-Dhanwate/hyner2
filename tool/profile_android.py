#!/usr/bin/env python3
"""Collect repeatable startup/PSS samples on an explicitly designated Android test device.
Does not install, clear data, reset batterystats or capture customer content.
"""
import argparse
import json
import math
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--dataset-label', required=True, help='Non-PII synthetic fixture name')
    parser.add_argument('--confirm-test-device', action='store_true', help='Required: launches/force-stops only the designated test application')
    parser.add_argument('--cold-iterations', type=int, default=20)
    parser.add_argument('--warm-iterations', type=int, default=30)
    parser.add_argument('--settle-seconds', type=float, default=3)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.confirm_test_device: parser.error('--confirm-test-device is required; use synthetic data, never an active merchant session.')
    if args.cold_iterations < 1 or args.warm_iterations < 1 or args.settle_seconds < 0: parser.error('Invalid iteration/wait count.')
    adb = shutil.which('adb') or str(Path.home() / 'Library/Android/sdk/platform-tools/adb')
    package = 'com.hyner.hyner'
    def call(*command):
        return subprocess.check_output([adb, '-s', args.serial, *command], text=True, stderr=subprocess.STDOUT, timeout=60)
    if call('get-state').strip() != 'device': raise SystemExit('The designated device is unavailable.')
    if 'package:' not in call('shell', 'pm', 'path', package): raise SystemExit('Install the reviewed test APK first.')
    model = call('shell', 'getprop', 'ro.product.model').strip()
    sdk = call('shell', 'getprop', 'ro.build.version.sdk').strip()
    abi = call('shell', 'getprop', 'ro.product.cpu.abilist').strip()
    mem = call('shell', 'cat', '/proc/meminfo')
    device_memory = {name: int(value) for name, value in re.findall(r'^(MemTotal|MemAvailable):\s+(\d+)', mem, re.M)}
    records = []
    try:
        for mode, count in [('cold_process', args.cold_iterations), ('warm_resume', args.warm_iterations)]:
            for iteration in range(count):
                if mode == 'cold_process': call('shell', 'am', 'force-stop', package)
                else: call('shell', 'input', 'keyevent', 'KEYCODE_HOME')
                activity = call('shell', 'am', 'start', '-W', '-n', package + '/.MainActivity')
                if 'Error:' in activity: raise RuntimeError('Activity launch failed; verify installed package/launchable activity.')
                launch = {name: int(value) for name, value in re.findall(r'^(ThisTime|TotalTime|WaitTime):\s*(\d+)', activity, re.M)}
                time.sleep(args.settle_seconds)
                memory = call('shell', 'dumpsys', 'meminfo', package)
                match = re.search(r'TOTAL PSS:\s*(\d+)', memory) or re.search(r'^\s*TOTAL\s+(\d+)', memory, re.M)
                pid = call('shell', 'pidof', package).strip().split()[0]
                raw = call('logcat', '-d', '--pid=' + pid, '-v', 'raw', '-s', 'flutter:I')
                metrics = []
                for line in raw.splitlines():
                    if line.startswith('HYNER_PERF '):
                        try: metrics.append(json.loads(line[len('HYNER_PERF '):]))
                        except json.JSONDecodeError: pass
                if metrics:
                    run = metrics[-1].get('run_id')
                    metrics = [m for m in metrics if m.get('run_id') == run]
                records.append({'mode': mode, 'iteration': iteration + 1, 'activity_ms': launch,
                                'total_pss_kib': int(match[1]) if match else None, 'flutter_metrics': metrics})
                print(f'{mode} {iteration + 1}/{count}: {launch}, PSS KiB={records[-1]["total_pss_kib"]}', flush=True)
    finally:
        # Preserve partial results if the device disconnects; do not invent missing samples.
        args.output.parent.mkdir(parents=True, exist_ok=True)
        def distribution(values):
            values = sorted(value for value in values if value is not None)
            return {'samples':len(values),'median':statistics.median(values) if values else None,
                    'p95':values[math.ceil(.95 * len(values)) - 1] if values else None,'maximum':max(values) if values else None}
        summary = {mode:{'activity_total_ms':distribution([r['activity_ms'].get('TotalTime') for r in records if r['mode']==mode]),
                         'settled_pss_kib':distribution([r['total_pss_kib'] for r in records if r['mode']==mode])}
                   for mode in ['cold_process','warm_resume']}
        args.output.write_text(json.dumps({'summary':summary,'flutter_metric_scope':'process markers; warm resumes reuse the same startup run', 'kind':'real device samples; am start is not Flutter useful-screen timing',
            'device':{'model':model,'sdk':sdk,'abis':abi,'memory_kib':device_memory},'dataset_label':args.dataset_label,
            'settle_seconds':args.settle_seconds,'cpu_percent':None,'battery_energy':None,'network_bytes':None,
            'samples':records}, indent=2) + '\n')


if __name__ == '__main__':
    main()
