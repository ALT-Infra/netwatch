"""Fetch an exact upstream revision and apply our development patch series."""

import json
import subprocess
from pathlib import Path


def main():
    integration = Path(__file__).resolve().parent
    root = integration.parents[1]
    target = root / "vendor" / "frigate"
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
                "--unidiff-zero",
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
                "--unidiff-zero",
                str(integration / patch),
            ],
            check=True,
        )
    print(
        "Prepared vendor/frigate with the development patches. See integrations/frigate/README.md."
    )


if __name__ == "__main__":
    main()
