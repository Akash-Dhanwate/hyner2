#!/usr/bin/env python3
"""Build verified ABI APKs (default), universal fallback, AAB, or size analysis. No upload/install."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess

from check_android_artifacts import inspect


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--format', choices=['split', 'universal', 'bundle', 'analysis'], default='split')
    parser.add_argument('--no-pub', action='store_true')
    parser.add_argument('--reference-apk', type=Path)
    parser.add_argument('--label', default='plan-a', help='Artifact filename label (letters, digits and hyphens).')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', args.label):
        parser.error('Use lowercase letters, digits and hyphens for --label.')
    root = Path(__file__).resolve().parents[1]
    registration = json.loads((root / 'android/app/google-services.json').read_text())
    clients = [c for c in registration['client'] if c['client_info']['android_client_info']['package_name'] == 'com.hyner.hyner']
    if len(clients) != 1:
        raise SystemExit('Expected exactly one Firebase registration for com.hyner.hyner')
    client = clients[0]
    oauth = [c['client_id'] for c in client.get('oauth_client', []) if c['client_type'] == 3]
    if len(oauth) != 1:
        raise SystemExit('The Android registration needs its existing Google web OAuth client.')
    project = registration['project_info']
    values = {'HYNER_ENV': 'development', 'FIREBASE_API_KEY': client['api_key'][0]['current_key'],
              'FIREBASE_APP_ID': client['client_info']['mobilesdk_app_id'], 'FIREBASE_MESSAGING_SENDER_ID': project['project_number'],
              'FIREBASE_PROJECT_ID': project['project_id'], 'GOOGLE_SERVER_CLIENT_ID': oauth[0]}
    config = root / 'build/config/firebase.android.json'
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps(values))
    flutter = shutil.which('flutter') or '/Users/akash/develop/flutter/bin/flutter'
    environment = os.environ.copy()
    java = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
    if java.exists(): environment.setdefault('JAVA_HOME', str(java))
    environment.setdefault('ANDROID_HOME', str(Path.home() / 'Library/Android/sdk'))
    # Sideload variants keep the declared version code, so switching ABI/universal
    # packaging does not jump to 1000*ABI+version and obstruct later updates.
    # AAB is the store format; legacy Play multi-APK versioning is not used here.
    environment['ORG_GRADLE_PROJECT_force-version-code-ignoring-abi'] = 'true'
    command = [flutter, 'build', 'appbundle' if args.format == 'bundle' else 'apk', '--release']
    if args.no_pub: command.append('--no-pub')
    if args.format == 'split': command.append('--split-per-abi')
    if args.format == 'analysis': command.extend(['--target-platform', 'android-arm64', '--analyze-size'])
    command.append(f'--dart-define-from-file={config}')
    subprocess.run(command, cwd=root, env=environment, check=True)
    name = next(line.split(':', 1)[1].strip().split('+')[0] for line in (root / 'pubspec.yaml').read_text().splitlines() if line.startswith('version:'))
    output = root / 'build/app/outputs/flutter-apk'
    reference = args.reference_apk
    if reference is None:
        candidate = root / 'build/optimization/baseline/hyner-0.6.0-updated.apk'
        reference = candidate if candidate.exists() else None
    artifacts = []
    abis = ['armeabi-v7a', 'arm64-v8a', 'x86_64']
    for kind in abis if args.format == 'split' else [args.format]:
        if kind == 'bundle':
            source = root / 'build/app/outputs/bundle/release/app-release.aab'
            destination = source.with_name(f'hyner-{name}-{args.label}.aab')
        else:
            source = output / (f'app-{kind}-release.apk' if kind in abis else 'app-release.apk')
            destination = output / f'hyner-{name}-{args.label}-{kind}.apk'
        result = inspect(source, kind, reference)
        shutil.copy2(source, destination)
        result['file'] = destination.name
        destination.with_suffix(destination.suffix + '.sha256').write_text(f'{result["sha256"]}  {destination.name}\n')
        artifacts.append(result)
    evidence_name = args.format if args.label == 'plan-a' else f'{args.label}-{args.format}'
    evidence = root / f'build/optimization/artifacts-{evidence_name}.json'
    evidence.parent.mkdir(parents=True, exist_ok=True)
    source_hash = hashlib.sha256()
    for path in sorted((root / 'lib').rglob('*.dart')):
        source_hash.update(str(path.relative_to(root)).encode()); source_hash.update(path.read_bytes())
    sdk = json.loads(subprocess.check_output([flutter, '--version', '--machine'], text=True, env=environment))
    evidence.write_text(json.dumps({'format': args.format, 'source_lib_sha256': source_hash.hexdigest(),
                                    'flutter': sdk['frameworkVersion'], 'dart': sdk['dartSdkVersion'], 'artifacts': artifacts}, indent=2) + '\n')
    print(f'Verified release artifacts and checksums: {evidence}')


if __name__ == '__main__':
    main()
