#!/usr/bin/env python3
"""Install and inspect the SDKs pinned in the repository's FVM configuration."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def api(name):
    return json.loads(run('fvm', 'api', name, cwd=ROOT, capture_output=True).stdout)


def main():
    config = json.loads((ROOT / '.fvmrc').read_text())
    pins = {'default': config['flutter'], 'ios': config['flavors']['ios']}
    if len(sys.argv) != 2 or sys.argv[1] not in ('setup', 'doctor'):
        raise ValueError('Usage: sdk_management.py setup|doctor')
    for command, instruction in (
        ('fvm', 'Install FVM: https://fvm.app/documentation/getting-started/installation'),
        ('git', 'Install Git and ensure it is available on PATH'),
    ):
        if not shutil.which(command):
            raise ValueError(f'{command} not found on PATH. {instruction}')
    if sys.argv[1] == 'setup':
        # Explicit installs may rewrite project configuration; isolate them.
        env = os.environ.copy()
        env.pop('FVM_FLUTTER_VERSION', None)
        with tempfile.TemporaryDirectory() as directory:
            for version in dict.fromkeys(pins.values()):
                run('fvm', 'install', version, '--skip-pub-get', cwd=directory, env=env)
        run('fvm', 'install', '--skip-pub-get', cwd=ROOT, env=env)
        return

    print(f"FVM: {run('fvm', '--version', capture_output=True).stdout.strip()}", flush=True)
    print(f"Git: {run('git', '--version', capture_output=True).stdout.strip()}", flush=True)
    project = api('project')['project']
    versions = {item['name']: item for item in api('list')['versions']}
    selections = {'default': project['pinnedVersion']['name'], 'ios': project['flavors'].get('ios')}
    override = os.environ.get('FVM_FLUTTER_VERSION')
    if override:
        print(f'FVM_FLUTTER_VERSION is set to {override}; unset it to use project selection.')
    for name, pin in pins.items():
        actual = override if name == 'default' and override else selections[name]
        print(f'{name}: expected Flutter {pin}; FVM selection {actual}', flush=True)
        if actual != pin or selections[name] != pin:
            raise ValueError(f'{name}: FVM selection does not match .fvmrc; unset FVM_FLUTTER_VERSION and check the project configuration')
    print('Selection checked via FVM API; Flutter commands are not run because they may write local state.')
    for name, pin in pins.items():
        sdk = versions.get(pin)
        if not sdk or not sdk['isSetup']:
            raise ValueError(f'{name}: Flutter {pin} is not installed and set up; run make setup')
        if not os.access(sdk['flutterExec'], os.X_OK) or not os.access(sdk['dartExec'], os.X_OK):
            raise ValueError(f'{name}: Flutter or Dart executable is missing; run make setup')
        metadata = json.loads((Path(sdk['directory']) / 'bin/cache/flutter.version.json').read_text())
        if metadata['flutterVersion'] != pin:
            raise ValueError(f"{name}: expected Flutter {pin}, found {metadata['flutterVersion']}")
        dart = run(sdk['dartExec'], '--version', capture_output=True)
        dart_version = (dart.stdout or dart.stderr).strip()
        expected_dart = metadata['dartSdkVersion']
        build = re.search(r'\(build ([^)]+)\)', expected_dart)
        actual = re.search(r'Dart SDK version: (\S+)', dart_version)
        if not actual or actual.group(1) != (build.group(1) if build else expected_dart):
            raise ValueError(f"{name}: bundled Dart does not match Flutter metadata: {dart_version}")
        print(f'{name}: Flutter {pin}; {dart_version}')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(f'sdk management: {error}', file=sys.stderr)
        if error.stderr:
            print(error.stderr.strip(), file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError) as error:
        print(f'sdk management: {error}', file=sys.stderr)
        sys.exit(1)
