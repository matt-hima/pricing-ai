#!/usr/bin/env python3
"""Sign nested native code before its containing bundles for Developer ID distribution."""
import os
from pathlib import Path
import subprocess
import sys

app = Path(sys.argv[1]).resolve()
identity = os.environ['MAC_SIGN_IDENTITY']
entitlements = Path(__file__).resolve().parent.parent / 'macos/Runner/Release.entitlements'


def sign(path, main=False):
    args = ['codesign', '--force', '--timestamp', '--options', 'runtime', '--sign', identity]
    if main:
        args += ['--entitlements', str(entitlements)]
    subprocess.run([*args, str(path)], check=True)


# Sign actual Mach-O files, skipping symlinks and preserving framework layout.
for directory, dirs, files in os.walk(app, topdown=False):
    for name in files:
        path = Path(directory) / name
        if path.is_symlink():
            continue
        kind = subprocess.check_output(['file', '-b', str(path)], text=True)
        if 'Mach-O' in kind:
            sign(path)
    path = Path(directory)
    if path != app and path.suffix in {'.framework', '.app', '.xpc', '.bundle'} and not path.is_symlink():
        sign(path)
sign(app, main=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], check=True)
