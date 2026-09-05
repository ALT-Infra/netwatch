import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient

from edge.app import create_app
from edge.schemas import ProbeResult
from edge.settings import Settings


@pytest.fixture
def settings(tmp_path):
    return Settings(tmp_path, "test-access-key-" + "a" * 32, Fernet.generate_key().decode())


@pytest.fixture
def headers(settings):
    return {"Authorization": f"Bearer {settings.api_token}"}


@pytest.fixture
def camera_input():
    return {
        "name": "Warehouse entrance",
        "main_url": "rtsp://192.0.2.20/live?token=private-query",
        "sub_url": "rtsp://192.0.2.20/sub",
        "username": "camera-user",
        "password": "private-camera-secret@:/%",
    }


@pytest.fixture
def client(settings):
    def probe(url):
        return ProbeResult(
            status="reachable",
            message="Video stream responded.",
            codec="h264",
            width=1920,
            height=1080,
        )

    with TestClient(create_app(settings, probe)) as client:
        yield client
