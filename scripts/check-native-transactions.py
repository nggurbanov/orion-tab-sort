#!/usr/bin/env python3
"""Exercise shipped command/state handlers; replace only snapshot, move and I/O boundaries."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def fixture_source(engine, checks):
    # Keep every production handler, including performCommand, validation and journal encoding.
    # Rename exactly these native/I/O boundaries so synthetic overrides can inject faults.
    for name in ('snapshot', 'applyLayout', 'writeJournal', 'saveResolvedJournal', 'protectedJournalArchive', 'restoreRootExpansion'):
        pattern = rf'(?m)^(    (?:on|end) ){name}(?=\(|\s|$)'
        engine, count = re.subn(pattern, rf'\1production_{name}', engine)
        if count != 2:
            raise AssertionError(f'Expected one exact shipped {name} handler, got {count}')
    loader = (ROOT / 'native/templates/install-bridge.applescript').read_text()
    loader_guards = loader[loader.index('on validateRuntime('):loader.index('set hostBundle')]
    lines = [line.removeprefix('    ') for line in engine.splitlines()[1:-1]
             if 'property parent :' not in line]
    return 'use framework "Foundation"\n' + '\n'.join(lines) + '\n' + loader_guards + '\n' + checks


def main():
    engine = (ROOT / 'native/Bridge.applescript').read_text()
    checks = (ROOT / 'scripts/check-native-transactions.applescript').read_text()
    with tempfile.TemporaryDirectory(prefix='orion-transactions-') as directory:
        source = Path(directory) / 'fixture.applescript'
        source.write_text(fixture_source(engine, checks))
        result = subprocess.run(['osascript', str(source), str(Path(directory) / 'journal.json'),
                                 'fixed'], text=True, capture_output=True, timeout=45)
        print(result.stdout, end='')
        if result.returncode:
            print(result.stderr, end='')
        raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
