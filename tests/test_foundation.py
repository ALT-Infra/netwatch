"""Exercise the patched implementation using the actual runtime dependencies."""

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_runtime_configuration_transactions():
    engine = os.environ.get("NETWATCH_ENGINE") or ("podman" if shutil.which("podman") else "docker")
    subprocess.run(
        [
            engine,
            "run",
            "--rm",
            "-e",
            "PYTHONPATH=/opt/frigate",
            "--entrypoint",
            "python3",
            "-v",
            f"{ROOT / 'tests'}:/tests:ro",
            "localhost/netwatch:local",
            "/tests/runtime_config.py",
        ],
        check=True,
    )
