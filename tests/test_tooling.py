"""Publication/build boundaries, using temporary synthetic files only."""
import contextlib
import hashlib
import importlib.util
import io
import json
import plistlib
import re
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent.parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load tooling module: {name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


builder = load("build_runtime")
packager = load("package_extension")
transactions = load("check-native-transactions")


class ToolingTests(unittest.TestCase):
    def test_apple_script_values_cannot_break_string_literals(self):
        self.assertEqual(builder.apple_escape('a\\b"c'), 'a\\\\b\\"c')
        for value in ["a\nb", "a\rb", "a\0b"]:
            with self.assertRaises(ValueError):
                builder.apple_escape(value)
        with self.assertRaises(ValueError):
            builder.render('"@@MISSING@@"', {})

    def test_package_is_allowlisted_and_reproducible(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT / "extension", root / "extension")
            (root / "extension/private.js").write_text("synthetic private local file")
            (root / "extension/settings.local.json").write_text('{"key":"synthetic-only"}')
            with patch.object(packager, "ROOT", root), contextlib.redirect_stdout(io.StringIO()):
                packager.main()
                archive = next((root / "dist").glob("*.zip"))
                first = hashlib.sha256(archive.read_bytes()).digest()
                packager.main()
                self.assertEqual(first, hashlib.sha256(archive.read_bytes()).digest())
                with ZipFile(archive) as contents:
                    self.assertEqual(set(contents.namelist()), set(packager.FILES))

    def test_transaction_fixture_executes_exact_shipped_command_handlers(self):
        engine = (ROOT / "native/Bridge.applescript").read_text()
        checks = (ROOT / "scripts/check-native-transactions.applescript").read_text()
        fixture = transactions.fixture_source(engine, checks)
        for name in ("performCommand", "compensateLayout", "recoverRetained", "acknowledgeCurrent", "recoverLayout", "transactionStatus", "recoveryJournal"):
            start = engine.index(f"    on {name}(")
            end = engine.index(f"    end {name}", start) + len(f"    end {name}")
            shipped = "\n".join(line.removeprefix("    ") for line in engine[start:end].splitlines())
            self.assertEqual(fixture.count(shipped), 1, name)
            self.assertEqual(fixture.count(f"on {name}("), 1, name)
        with self.assertRaises(AssertionError):
            transactions.fixture_source(engine.replace("    on applyLayout(", "    on renamedLayout("), checks)
        # Both snapshot-derived reply flags are computed by the exercised state handler.
        self.assertIn("replyObject's addEntriesFromDictionary:(my transactionStatus())", engine)

    @unittest.skipUnless(sys.platform == "darwin", "Compiles AppleScript using macOS")
    def test_runtime_compiles_escaped_paths_and_preserves_state(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'runtime with spaces and "quotes"'
            builder.build("a" * 32, output)
            journal = output / "state/native-session-undo.json"
            journal.write_text('{"fixture":"preserve-me"}')
            builder.build("a" * 32, output)
            self.assertEqual(journal.read_text(), '{"fixture":"preserve-me"}')
            for source in output.rglob("*.applescript"):
                self.assertNotIn("@@", source.read_text())
            revision = re.match(r"script OrionNativeTreeBridgeV3R(\d+)", (ROOT / "native/Bridge.applescript").read_text()).group(1)
            bundle = output / f"native/OrionNativeTreeBridgeV3R{revision}.bundle"
            metadata = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
            self.assertEqual(metadata["CFBundleVersion"], revision)
            self.assertEqual(metadata["CFBundleName"], f"OrionNativeTreeBridgeV3R{revision}")
            self.assertEqual(json.loads((output / ".orion-tab-sort-runtime").read_text())["bridge"], f"R{revision}")
            for generated in (output / "scripts").glob("*.applescript"):
                self.assertIn(f"OrionNativeTreeHostV3R{revision}", generated.read_text())
            archived = output / "state/native-session-undo.json.acknowledged-fixture"
            archived.write_text("synthetic archived recovery evidence")
            archived.chmod(0o600)
            builder.build("a" * 32, output)
            self.assertEqual(archived.read_text(), "synthetic archived recovery evidence")
            self.assertEqual(archived.stat().st_mode & 0o777, 0o600)
            sentinel_dir = Path(directory) / "unrelated"
            sentinel_dir.mkdir()
            sentinel = sentinel_dir / "keep.txt"
            sentinel.write_text("unchanged")
            with self.assertRaises(ValueError):
                builder.build("a" * 32, sentinel_dir)
            self.assertEqual(sentinel.read_text(), "unchanged")
            with self.assertRaises(ValueError):
                builder.build('invalid/id', Path(directory) / "bad")


if __name__ == "__main__":
    unittest.main()
