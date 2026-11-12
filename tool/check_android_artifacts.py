#!/usr/bin/env python3
"""Verify APK contents, package/version/signature and distribution size budgets."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def build_tools():
    sdk = Path(os.environ.get('ANDROID_HOME', Path.home() / 'Library/Android/sdk'))
    directories = [p for p in (sdk / 'build-tools').iterdir() if (p / 'apksigner').exists() and (p / 'aapt').exists()]
    if not directories:
        raise RuntimeError('Android build-tools with aapt and apksigner are required.')
    return max(directories, key=lambda p: tuple(int(n) for n in re.findall(r'\d+', p.name)))


def apk_contents(path):
    with zipfile.ZipFile(path) as apk:
        if apk.testzip() is not None:
            raise ValueError('APK ZIP integrity check failed.')
        names = apk.namelist()
        libraries = [n for n in names if n.startswith('lib/') and n.endswith('.so')]
        abis = sorted({n.split('/')[1] for n in libraries})
        primary_abis = sorted({n.split('/')[1] for n in libraries if n.endswith('/libapp.so')})
        for abi in primary_abis:
            for required in ['libapp.so', 'libflutter.so', 'libsqlite3.so']:
                if f'lib/{abi}/{required}' not in names:
                    raise ValueError(f'{abi}: missing required native library {required}')
        if not primary_abis or 'classes.dex' not in names:
            raise ValueError('Missing application code.')
        profiling_marker = any(b'HYNER_PERF ' in apk.read(f'lib/{abi}/libapp.so') for abi in primary_abis)
        if profiling_marker:
            raise ValueError('Opt-in profiling code is present; do not distribute the measurement build.')
        return {'profiling_marker_present':profiling_marker,'abis': abis, 'primary_abis': primary_abis, 'native_bytes': sum(apk.getinfo(n).file_size for n in libraries),
                'aot_sha256': {abi: hashlib.sha256(apk.read(f'lib/{abi}/libapp.so')).hexdigest() for abi in primary_abis}}


def certificate(path, tools):
    result = subprocess.check_output([str(tools / 'apksigner'), 'verify', '--print-certs', str(path)], text=True)
    fingerprints = {value.lower() for value in re.findall(r'certificate SHA-256 digest:\s*([0-9a-fA-F]+)', result)}
    if len(fingerprints) != 1:
        raise ValueError('Expected exactly one verified signing identity; review any signing migration.')
    return fingerprints.pop()


def inspect(path, kind, reference=None):
    budgets = json.loads((ROOT / 'tool/android_size_budgets.json').read_text())
    size = path.stat().st_size
    maximum = budgets['maximum_bytes'][kind]
    if size > maximum:
        raise ValueError(f'{kind}: {size} bytes exceeds reviewed budget {maximum}.')
    result = {'file': path.name, 'kind': kind, 'bytes': size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'budget_bytes': maximum}
    if kind == 'bundle':
        with zipfile.ZipFile(path) as bundle:
            if bundle.testzip() is not None or 'BundleConfig.pb' not in bundle.namelist() or 'base/manifest/AndroidManifest.xml' not in bundle.namelist():
                raise ValueError('Invalid bundle ZIP/manifest/configuration.')
        verified = subprocess.check_output([shutil.which('jarsigner') or 'jarsigner', '-J-Duser.language=en', '-verify', str(path)], text=True)
        if 'jar verified.' not in verified:
            raise ValueError('The AAB JAR signature could not be verified.')
        certs = subprocess.check_output([shutil.which('keytool') or 'keytool', '-J-Duser.language=en', '-printcert', '-jarfile', str(path)], text=True)
        fingerprints = {value.replace(':', '').lower() for value in re.findall(r'SHA256:\s*([0-9A-Fa-f:]+)', certs)}
        if len(fingerprints) != 1:
            raise ValueError('Review the AAB signing identity before distribution.')
        result['certificate_sha256'] = fingerprints.pop()
        if reference and result['certificate_sha256'] != certificate(reference, build_tools()):
            raise ValueError('AAB signer differs from the previous APK.')
        return result
    result.update(apk_contents(path))
    if kind in ('arm64-v8a', 'armeabi-v7a', 'x86_64') and result['abis'] != [kind]:
        raise ValueError(f'Expected one ABI {kind}, found {result["abis"]}')
    if kind == 'universal' and result['primary_abis'] != ['arm64-v8a', 'armeabi-v7a', 'x86_64']:
        raise ValueError('Universal fallback lost a supported ABI.')
    tools = build_tools()
    badging = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', str(path)], text=True)
    package = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
    if not package or package[1] != 'com.hyner.hyner':
        raise ValueError('Unexpected application ID.')
    version = re.search(r'^version:\s*([^+\s]+)\+(\d+)', (ROOT / 'pubspec.yaml').read_text(), re.M)
    if package[2] != version[2] or package[3] != version[1]:
        raise ValueError('APK version changed or ABI multipliers broke the update/rollback policy.')
    result.update(package=package[1], version_code=int(package[2]), version_name=package[3], certificate_sha256=certificate(path, tools))
    if reference and result['certificate_sha256'] != certificate(reference, tools):
        raise ValueError('Signing identity differs from the reference APK; do not distribute this update.')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--kind', required=True, choices=['arm64-v8a','armeabi-v7a','x86_64','universal','bundle','analysis'])
    parser.add_argument('--reference-apk', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = inspect(args.apk.resolve(), args.kind, args.reference_apk)
    payload = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload)
    print(payload, end='')


if __name__ == '__main__':
    main()
