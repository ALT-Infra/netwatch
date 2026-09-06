"""Fetch an exact upstream revision and apply our controlled patch series."""

import argparse
import json
import shutil
import subprocess
from pathlib import Path


def main():
    integration = Path(__file__).resolve().parent
    root = integration.parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", type=Path, default=root / "vendor" / "frigate")
    target = parser.parse_args().target.resolve()
    upstream = json.loads((integration / "upstream.json").read_text())
    if target.exists():
        raise SystemExit(
            "vendor/frigate already exists; preserved its contents. Use git status there."
        )
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "--branch",
            upstream["tag"],
            upstream["repository"],
            str(target),
        ],
        check=True,
    )
    revision = subprocess.check_output(
        ["git", "-C", str(target), "rev-parse", "HEAD"], text=True
    ).strip()
    if revision != upstream["commit"]:
        raise SystemExit(
            "Upstream tag no longer matches the pinned commit; stopped before patching."
        )
    for patch in upstream["patches"]:
        subprocess.run(
            [
                "git",
                "-C",
                str(target),
                "apply",
                "--check",
                str(integration / patch),
            ],
            check=True,
        )
        subprocess.run(
            [
                "git",
                "-C",
                str(target),
                "apply",
                str(integration / patch),
            ],
            check=True,
        )
    (target / "frigate/version.py").write_text('VERSION = "0.17.2-3d4dd3a-netwatch"\n')
    for name in ["pnpm-lock.yaml", "pnpm-workspace.yaml"]:
        shutil.copyfile(integration / name, target / "web" / name)
    (target / "web/package-lock.json").unlink()
    print(
        "Prepared the pinned Frigate source and Netwatch patches. "
        "Build with uv run scripts/local.py build."
    )


if __name__ == "__main__":
    main()
