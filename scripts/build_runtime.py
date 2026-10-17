#!/usr/bin/env python3
"""Render a machine-local runtime and compile it using macOS system tools."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def apple_escape(value):
    if any(char in value for char in "\r\n\0"):
        raise ValueError("Runtime paths cannot contain newlines or NUL")
    return value.replace("\\", "\\\\").replace('"', '\\"')


def render(text, values):
    for key, value in values.items():
        text = text.replace("@@" + key + "@@", apple_escape(str(value)))
    if re.search(r"@@[A-Z_]+@@", text):
        raise ValueError("Unresolved runtime template value")
    return text


def build(extension_id, output, orion_state=None):
    if sys.platform != "darwin":
        raise RuntimeError("The native runtime must be compiled on macOS")
    if not re.fullmatch(r"[a-z0-9]{32}", extension_id):
        raise ValueError("Expected Orion's 32-character lowercase extension ID")
    output = output.expanduser().resolve()
    if output == ROOT or output in ROOT.parents:
        raise ValueError("Choose a runtime directory, not the source tree or an ancestor")
    marker = output / ".orion-tab-sort-runtime"
    if output.exists() and any(output.iterdir()) and not marker.is_file():
        raise ValueError("Refusing to overwrite a non-runtime directory")
    values = {
        "RUNTIME_ROOT": str(output), "EXTENSION_ID": extension_id,
        "ORION_STATE": str((orion_state or Path.home() / "Library/Application Support/Orion/Defaults/browser_state.plist").expanduser().resolve()),
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    # Compile every script before modifying the destination. Runtime state is
    # never copied, replaced or cleaned by this build operation.
    with tempfile.TemporaryDirectory(prefix="orion-sort-build-", dir=output.parent) as directory:
        stage = Path(directory)
        resources = stage / "native/OrionNativeTreeBridgeV3R48.bundle/Contents/Resources"
        resources.mkdir(parents=True)
        (resources.parent / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "local.orion.native-tree-bridge-v3-r48",
            "CFBundleName": "OrionNativeTreeBridgeV3R48", "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "48", "NSAppleScriptEnabled": True,
        }))
        engine = resources / "OrionNativeTreeBridgeV3R48.applescript"
        engine.write_text(render((ROOT / "native/Bridge.applescript").read_text(), values))
        (stage / "scripts").mkdir()
        for source, target in [("install-bridge.applescript", "install-sorter-bridge.applescript"), ("open-sidebar.applescript", "open-sorter-sidebar.applescript")]:
            path = stage / "scripts" / target
            path.write_text(render((ROOT / "native/templates" / source).read_text(), values))
        launcher = stage / "launcher.applescript"
        launcher.write_text(render('''use framework "Foundation"
set sourceText to current application's NSString's stringWithContentsOfFile:"@@RUNTIME_ROOT@@/scripts/open-sorter-sidebar.applescript" encoding:4 |error|:(missing value)
if sourceText is missing value then error "Sorter runtime is missing"
set scriptObject to current application's NSAppleScript's alloc()'s initWithSource:sourceText
set {scriptResult, scriptError} to scriptObject's executeAndReturnError:(reference)
if scriptResult is missing value then error (current application's NSDictionary's dictionaryWithDictionary:scriptError)'s description() as text
return scriptResult's stringValue() as text
''', values))
        for source in stage.rglob("*.applescript"):
            subprocess.run(["osacompile", "-l", "AppleScript", "-o", str(source.with_suffix(".scpt")), str(source)], check=True)
        output.mkdir(parents=True, exist_ok=True)
        for path in stage.iterdir():
            destination = output / path.name
            if path.is_dir():
                shutil.copytree(path, destination, dirs_exist_ok=True)
            else:
                shutil.copy2(path, destination)
        marker.write_text(json.dumps({"bridge": "R48", "extensionId": extension_id}, indent=2) + "\n")
        state = output / "state"
        state.mkdir(mode=0o700, exist_ok=True)
        state.chmod(0o700)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extension-id", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "build/runtime")
    parser.add_argument("--orion-state", type=Path, help="Optional Orion profile state path")
    args = parser.parse_args()
    try:
        output = build(args.extension_id, args.output, args.orion_state)
    except (ValueError, RuntimeError) as error:
        parser.error(str(error))
    print(f"Compiled runtime: {output}")
    print(f"Programmable-button source: {output / 'launcher.applescript'}")
    print("No browser, extension, startup agent or application settings were changed.")


if __name__ == "__main__":
    main()
