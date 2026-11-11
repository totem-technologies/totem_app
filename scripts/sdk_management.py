#!/usr/bin/env python3
"""Check the Flutter SDK selected for this workspace."""

import json
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    if len(sys.argv) not in (2, 3) or sys.argv[1] not in ('setup', 'doctor'):
        raise ValueError('Usage: sdk_management.py setup|doctor [flutter command]')
    pin = (ROOT / '.flutter-version').read_text().strip()
    command = shlex.split(sys.argv[2]) if len(sys.argv) == 3 else ['flutter']
    if not command or not shutil.which(command[0]):
        raise ValueError(f'Flutter not found. Install Flutter {pin} and add it to PATH: https://docs.flutter.dev/get-started/install')
    result = subprocess.run([*command, '--version', '--machine'], cwd=ROOT,
                            check=True, text=True, capture_output=True)
    metadata = json.loads(result.stdout)
    version = metadata['frameworkVersion']
    if version != pin:
        raise ValueError(f'Expected Flutter {pin} from .flutter-version, found {version}; select the pinned SDK and retry')
    flutter_root = Path(metadata['flutterRoot'])
    dart_path = shutil.which('dart')
    bundled = [flutter_root / 'bin/dart', flutter_root / 'bin/cache/dart-sdk/bin/dart']
    if not dart_path or not any(path.exists() and path.samefile(dart_path) for path in bundled):
        raise ValueError(f'Dart on PATH ({dart_path or "not found"}) is not from the selected Flutter SDK ({flutter_root}); put {flutter_root / "bin"} first on PATH')
    dart = subprocess.run([dart_path, '--version'], check=True, text=True, capture_output=True)
    dart_version = re.search(r'Dart SDK version: (\S+)', dart.stdout + dart.stderr)
    expected = metadata['dartSdkVersion']
    build = re.search(r'\(build ([^)]+)\)', expected)
    expected = build.group(1) if build else expected.split()[0]
    if not dart_version or dart_version.group(1) != expected:
        raise ValueError(f'Dart on PATH ({dart_path}) does not match Flutter metadata (expected {expected}); repair the selected Flutter SDK and ensure its bin directory is first on PATH')
    print(f'Flutter {version} ({command[0]}); Dart {expected} ({dart_path})', flush=True)
    if sys.argv[1] == 'doctor':
        subprocess.run([*command, 'doctor'], cwd=ROOT, check=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f'sdk management: {error}', file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.strip(), file=sys.stderr)
        sys.exit(1)
