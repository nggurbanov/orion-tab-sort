#!/usr/bin/env python3
"""Package only the current extension sources, with reproducible ZIP metadata."""
import json
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent.parent
FILES = (
    "manifest.json", "api.js", "sorter.html", "sorter.css", "sorter.js",
    "tree-plan.js", "recovery.js", "ai-provider.js", "provider-settings.js",
    "persistent-identity.js",
)


def main():
    source = ROOT / "extension"
    manifest = json.loads((source / "manifest.json").read_text())
    output = ROOT / "dist" / f"orion-tab-sort-{manifest['version']}.zip"
    output.parent.mkdir(exist_ok=True)
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        for name in sorted(FILES):
            path = source / name
            info = ZipInfo(path.name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())
    print(output)


if __name__ == "__main__":
    main()
