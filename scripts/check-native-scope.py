"""Exercise exact production scope tokens with Foundation object identities."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
engine=(root/'native/Bridge.applescript').read_text()
lines=[line.removeprefix('    ') for line in engine.splitlines()[1:-1] if 'property parent :' not in line]
checks=(root/'scripts/check-native-scope.applescript').read_text()
with tempfile.TemporaryDirectory(prefix='orion-scope-qa-') as tmp:
 source=Path(tmp)/'checks.applescript';source.write_text('use framework "Foundation"\n'+'\n'.join(lines)+'\n'+checks)
 result=subprocess.run(['osascript',str(source)],capture_output=True,text=True)
 print(result.stdout,end='')
 if result.returncode:print(result.stderr,end='')
 raise SystemExit(result.returncode)
