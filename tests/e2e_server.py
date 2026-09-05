"""Isolated browser test server. Only the camera network response is simulated."""

from pathlib import Path
from tempfile import TemporaryDirectory

import uvicorn
from cryptography.fernet import Fernet

from edge.app import create_app
from edge.schemas import ProbeResult
from edge.settings import Settings


def fake_probe(url):
    return ProbeResult(
        status="reachable",
        message="Video stream responded.",
        codec="h264",
        width=1920,
        height=1080,
    )


if __name__ == "__main__":
    with TemporaryDirectory(prefix="netwatch-e2e-") as directory:
        settings = Settings(
            Path(directory),
            "browser-test-access-key-00000000000000",
            Fernet.generate_key().decode(),
            Path(__file__).resolve().parents[1] / "web" / "dist",
        )
        uvicorn.run(create_app(settings, fake_probe), host="127.0.0.1", port=8011, access_log=False)
