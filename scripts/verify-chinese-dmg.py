#!/usr/bin/env python3
"""Verify the app actually shipped in a DMG, without loading user state."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('dmg', type=Path)
parser.add_argument('--report', required=True, type=Path)
parser.add_argument('--intel', action='store_true', help='Also execute the x86_64 slice (requires Intel or Rosetta)')
parser.add_argument('--require-notarized', action='store_true', help='Require stapled Apple tickets and Gatekeeper acceptance for the DMG and application')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
dmg = args.dmg.resolve()
report_path = args.report.resolve()
subprocess.run(['hdiutil', 'verify', str(dmg)], check=True)
if args.require_notarized:
    subprocess.run(['codesign', '--verify', '--strict', str(dmg)], check=True)
    subprocess.run(['xcrun', 'stapler', 'validate', str(dmg)], check=True)
    verdict = subprocess.run(['spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose=4', str(dmg)], capture_output=True, text=True, check=True)
    if 'source=Notarized Developer ID' not in verdict.stderr:
        raise RuntimeError('DMG is not accepted as Notarized Developer ID')
with tempfile.TemporaryDirectory(prefix='checkmate-dmg-verify-') as temporary:
    temporary = Path(temporary)
    mount = temporary / 'mounted'
    attached = False
    try:
        result = subprocess.check_output(['hdiutil', 'attach', '-readonly', '-nobrowse', '-plist', '-mountpoint', str(mount), str(dmg)])
        attached = True
        plistlib.loads(result)
        if not (mount / 'Applications').is_symlink() or os.readlink(mount / 'Applications') != '/Applications':
            raise RuntimeError('Applications install shortcut missing')
        for name in ('安装说明.txt', 'LICENSE.txt', '第三方许可.txt'):
            if not (mount / name).is_file():
                raise RuntimeError(f'Installer documentation missing: {name}')
        app = temporary / 'installed/CheckmateChinese.app'
        subprocess.run(['ditto', str(mount / 'CheckmateChinese.app'), str(app)], check=True)
        package_command = ['python3', str(root / 'scripts/check-package.py'), str(app), '--chinese']
        if args.require_notarized:
            package_command.append('--release')
            subprocess.run(['xcrun', 'stapler', 'validate', str(app)], check=True)
            verdict = subprocess.run(['spctl', '--assess', '--type', 'execute', '--verbose=4', str(app)], capture_output=True, text=True, check=True)
            if 'source=Notarized Developer ID' not in verdict.stderr:
                raise RuntimeError('Application is not accepted as Notarized Developer ID')
        package = json.loads(subprocess.check_output(package_command, text=True))
        signature = subprocess.run(['codesign', '-d', '--verbose=4', str(app)], capture_output=True, text=True, check=True).stderr
        signature_kind = 'ad-hoc' if 'Signature=adhoc' in signature else ('Developer ID' if 'Authority=Developer ID Application: ' in signature else 'other')
        runs = {}
        for architecture in (['native', 'x86_64'] if args.intel else ['native']):
            output = temporary / f'{architecture}.json'
            command = [str(app / 'Contents/MacOS/CheckmateNative'), '--package-check', str(output)]
            if architecture == 'x86_64':
                command = ['arch', '-x86_64'] + command
            subprocess.run(command, cwd=temporary, env={**os.environ, 'CHECKMATE_AUTOMATION': '1'}, check=True, timeout=90, capture_output=True)
            run = json.loads(output.read_text())
            if not run.get('passed') or run.get('lessons') != 40 or not run.get('engineMove'):
                raise RuntimeError(f'Packaged app check failed: {architecture}')
            if app.resolve() not in Path(run['resourceRoot']).resolve().parents:
                raise RuntimeError('Application used resources outside its installed copy')
            runs[architecture] = run
        report = {'passed': True, 'dmg': str(dmg), 'package': package, 'execution': runs,
                  'signature': signature_kind, 'appleNotarized': True if args.require_notarized else None}
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps(report, ensure_ascii=False))
    finally:
        if attached:
            subprocess.run(['hdiutil', 'detach', str(mount)], check=True)
