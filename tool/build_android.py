#!/usr/bin/env python3
"""Build with the real com.hyner.hyner Firebase registration, never old app IDs."""
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    registration = json.loads((root / 'android/app/google-services.json').read_text())
    clients = [c for c in registration['client']
               if c['client_info']['android_client_info']['package_name'] == 'com.hyner.hyner']
    if len(clients) != 1:
        raise SystemExit('Expected exactly one Firebase registration for com.hyner.hyner')
    client = clients[0]
    oauth = [c['client_id'] for c in client.get('oauth_client', []) if c['client_type'] == 3]
    if len(oauth) != 1:
        raise SystemExit('Download google-services.json with a Google web OAuth client before enabling account access.')
    project = registration['project_info']
    values = {
        'HYNER_ENV': 'development',
        'FIREBASE_API_KEY': client['api_key'][0]['current_key'],
        'FIREBASE_APP_ID': client['client_info']['mobilesdk_app_id'],
        'FIREBASE_MESSAGING_SENDER_ID': project['project_number'],
        'FIREBASE_PROJECT_ID': project['project_id'],
        'GOOGLE_SERVER_CLIENT_ID': oauth[0],
    }
    target = root / 'build/config/firebase.android.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(values))
    flutter = shutil.which('flutter') or '/Users/akash/develop/flutter/bin/flutter'
    environment = os.environ.copy()
    java = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
    if java.exists():
        environment.setdefault('JAVA_HOME', str(java))
    environment.setdefault('ANDROID_HOME', str(Path.home() / 'Library/Android/sdk'))
    subprocess.run([flutter, 'build', 'apk', '--release',
                    f'--dart-define-from-file={target}'], cwd=root, env=environment, check=True)


if __name__ == '__main__':
    main()
