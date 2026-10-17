"""Execute the actual plan guards with Foundation objects, without loading Orion."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
engine = (root / "native/Bridge.applescript").read_text()
lines = engine.splitlines()[1:-1]
lines = [line.removeprefix("    ") for line in lines if "property parent :" not in line]
test = (root / "scripts/check-native-plan.applescript").read_text()
with tempfile.TemporaryDirectory(prefix="orion-plan-guard-") as temporary:
    source = Path(temporary) / "guards.applescript"
    source.write_text("use framework \"Foundation\"\n" + "\n".join(lines) + "\n" + test.replace('use framework "Foundation"', ""))
    completed = subprocess.run(["osascript", str(source)], capture_output=True, text=True)
    print(completed.stdout, end="")
    if completed.returncode:
        print(completed.stderr, end="")
    raise SystemExit(completed.returncode)
