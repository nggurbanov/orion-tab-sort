"""Validate restart finalization against isolated Foundation journal fixtures."""
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
engine=(root/'native/Bridge.applescript').read_text()
lines=[line.removeprefix('    ') for line in engine.splitlines()[1:-1] if 'property parent :' not in line]
checks=(root/'scripts/check-native-journal.applescript').read_text()
with tempfile.TemporaryDirectory(prefix='orion-journal-qa-') as tmp:
 source=Path(tmp)/'checks.applescript';source.write_text('use framework "Foundation"\n'+'\n'.join(lines)+'\n'+checks)
 result=subprocess.run(['osascript',str(source),str(Path(tmp)/'journal.json')],capture_output=True,text=True)
 print(result.stdout,end='')
 if result.returncode:print(result.stderr,end='')
 raise SystemExit(result.returncode)
