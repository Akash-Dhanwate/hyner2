#!/usr/bin/env python3
"""Render Hyner privacy and deletion pages with the developer's actual details."""
import argparse
from html import escape
from pathlib import Path
from urllib.parse import urlparse, quote


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--developer-name', required=True)
    parser.add_argument('--support-email', required=True)
    parser.add_argument('--base-url', required=True)
    parser.add_argument('--output', type=Path, default=Path('build/release-web'))
    args = parser.parse_args()
    if '@' not in args.support_email or any(c.isspace() for c in args.support_email):
        parser.error('Use an actual support email address.')
    url = urlparse(args.base_url)
    if url.scheme != 'https' or not url.netloc or url.username or url.password:
        parser.error('Use your public HTTPS site URL.')
    name, email = escape(args.developer_name), escape(args.support_email)
    base = args.base_url.rstrip('/')
    mail = f'mailto:{quote(args.support_email, safe="@.")}?subject=Hyner%20account%20deletion%20request'
    documents = {
        'privacy.html': ('Hyner privacy policy', f'''
<p>Hyner is provided by {name}. Contact: <a href="mailto:{email}">{email}</a>.</p>
<h2>Business records on your device</h2>
<p>Inventory, customer details, bills, payment records, calculators, rates and business settings are stored locally. Signing in does not automatically synchronize or back up these records. Local data remains until you remove it, clear app storage, or uninstall, subject to your Android backup settings.</p>
<h2>Account services</h2>
<p>Optional Google and email sign-in use Google Firebase Authentication to process account identifiers, email and authentication information. Earlier Hyner versions may have stored profile and inventory records in Firebase under your account. Device-only mode does not require an online account. Google services process data under their applicable privacy terms.</p>
<h2>Photos, exported files and sharing</h2>
<p>Selected business logos, signatures and profile photos are saved for your chosen use. PDF exports and backups include business and customer information. Sharing with WhatsApp, printers, file providers or other apps happens when you choose those actions. Recipient apps handle the copies under their own policies. Complete backups are readable files containing both databases, required images and selected preferences; authentication tokens and passwords are excluded. Store exported files privately.</p>
<h2>Payments and communications</h2>
<p>Hyner records payments you confirm; it does not process or automatically verify UPI payments. You control whether to send WhatsApp drafts or attachments. Customer marketing consent is optional and can be withdrawn in the customer record.</p>
<h2>Deletion and your choices</h2>
<p>You can export local business data and request deletion of your Hyner account. Account deletion removes the Firebase sign-in account and its Hyner-managed legacy cloud records. In-app deletion also clears that workspace on the current device. Exported/shared files, other devices and recipient apps require separate deletion. Save any business records you need before deleting. Deletion requests require verification of account ownership; do not send passwords, tokens or customer records.</p>
<p><a href="{escape(base)}/delete-account.html">Request account deletion</a>. Contact {email} for privacy questions or corrections.</p>
'''),
        'delete-account.html': ('Delete your Hyner account', f'''
<p>Hyner is provided by {name}. You can request account deletion without installing or opening the app.</p>
<h2>Send a deletion request</h2>
<p>Email <a href="{mail}">{email}</a> with the subject “Hyner account deletion request” and the email address used to sign in. We will verify that you own the account before taking action. Never send passwords, sign-in codes, authentication tokens or customer records.</p>
<p><a href="{mail}">Open an account deletion request in your email app</a></p>
<h2>What is deleted</h2>
<p>The Hyner Firebase sign-in account and its Hyner-managed legacy cloud profile and inventory records are deleted. This does not delete your Google account. Local-only business records on your devices are not accessible to us: use Settings → Privacy and account deletion in Hyner or clear Hyner’s Android storage on each device. Back up any records you need first.</p>
<h2>Copies outside the account</h2>
<p>Previously exported backups, downloaded or shared PDFs, printouts and copies held by other apps or recipients are not removed by account deletion. You control those copies and must delete them separately. No routine account-data retention is implemented by the deletion service; any applicable retention exception must be disclosed before use.</p>
<p><a href="{escape(base)}/privacy.html">Privacy policy</a></p>
'''),
    }
    args.output.mkdir(parents=True, exist_ok=True)
    for filename, (title, body) in documents.items():
        (args.output / filename).write_text(f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{title}</title><style>body{{font:17px/1.65 system-ui,sans-serif;max-width:760px;margin:48px auto;padding:0 24px;color:#19212b;background:#fff}}h1{{font-size:30px;line-height:1.2}}h2{{font-size:21px;margin-top:32px}}a{{color:#205ca0}}</style><main><h1>{title}</h1>{body}</main></html>''')
    print(f'Review before publishing: {args.output / "privacy.html"} and {args.output / "delete-account.html"}')


if __name__ == '__main__':
    main()
