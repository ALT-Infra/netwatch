import json
from dataclasses import replace

import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient

from edge.app import create_app
from edge.probe import ProbeUnavailable
from edge.schemas import CameraInput
from edge.store import Store


@pytest.mark.parametrize(
    "method,path,body",
    [
        ("GET", "/api/cameras", None),
        ("POST", "/api/cameras", {}),
        ("DELETE", "/api/cameras/id", None),
        ("POST", "/api/cameras/id/probe", {}),
    ],
)
def test_requires_auth(client, method, path, body):
    assert client.request(method, path, json=body).status_code == 401
    assert (
        client.request(
            method, path, json=body, headers={"Authorization": "Bearer wrong"}
        ).status_code
        == 401
    )


def test_camera_lifecycle_and_no_secret_disclosure(client, headers, camera_input, settings):
    response = client.post("/api/cameras", json=camera_input, headers=headers)
    assert response.status_code == 201
    item = response.json()
    assert item["last_probe"] is None
    assert item["host"] == "192.0.2.20"
    assert item["has_substream"] and item["has_credentials"]
    checked = client.post(f"/api/cameras/{item['id']}/probe", json={}, headers=headers)
    assert checked.status_code == 200
    assert checked.json()["last_probe"]["width"] == 1920
    assert checked.json()["checked_at"]
    listing = client.get("/api/cameras", headers=headers)
    assert listing.headers["cache-control"] == "no-store"
    database = (settings.data_dir / "edge.sqlite3").read_bytes()
    for secret in ["camera-user", "private-camera-secret", "private-query"]:
        assert secret not in response.text + checked.text + listing.text
        assert secret.encode() not in database
    assert client.delete(f"/api/cameras/{item['id']}", headers=headers).status_code == 204
    assert client.get("/api/cameras", headers=headers).json() == []
    assert client.delete(f"/api/cameras/{item['id']}", headers=headers).status_code == 404


@pytest.mark.parametrize(
    "url",
    [
        "file:///etc/passwd",
        "http://192.0.2.1",
        "rtsp://user:SECRET@192.0.2.1/live",
        "rtsp://192.0.2.1:99999/live",
        "rtsp://192.0.2.1:0/live",
        "rtsp://",
        "rtsp://192.0.2.1/live#exec=SECRET",
        "rtsp://192.0.2.1/\nSECRET",
        "rtsp://[broken",
    ],
)
def test_invalid_url_does_not_echo_request(client, headers, camera_input, url):
    camera_input["main_url"] = url
    response = client.post("/api/cameras", json=camera_input, headers=headers)
    assert response.status_code == 422
    assert "SECRET" not in response.text
    assert "private-camera-secret" not in response.text
    assert "private-query" not in response.text


def test_missing_and_absent_substream(client, headers, camera_input):
    assert client.post("/api/cameras/missing/probe", json={}, headers=headers).status_code == 404
    camera_input["sub_url"] = None
    item = client.post("/api/cameras", json=camera_input, headers=headers).json()
    assert (
        client.post(
            f"/api/cameras/{item['id']}/probe", json={"stream": "sub"}, headers=headers
        ).status_code
        == 400
    )


def test_persistence_and_wrong_vault_key(settings, camera_input):
    item = Store(settings).create(CameraInput(**camera_input))
    restarted = Store(settings)
    assert restarted.get(item.id).name == camera_input["name"]
    url = restarted.stream_url(item.id)
    assert "private-camera-secret%40%3A%2F%25@" in url
    assert "private-query" in url
    with pytest.raises(ValueError, match="Vault key does not match"):
        Store(replace(settings, vault_key=Fernet.generate_key().decode()))


def test_ffprobe_missing_does_not_mark_camera_offline(settings, headers, camera_input):
    def unavailable(url):
        raise ProbeUnavailable

    with TestClient(create_app(settings, unavailable)) as client:
        camera = client.post("/api/cameras", json=camera_input, headers=headers).json()
        assert (
            client.post(f"/api/cameras/{camera['id']}/probe", json={}, headers=headers).status_code
            == 503
        )
        assert client.get("/api/cameras", headers=headers).json()[0]["last_probe"] is None


def test_malformed_json_does_not_echo_secrets(client, headers):
    response = client.post(
        "/api/cameras",
        content='{"password":"SECRET",',
        headers={
            **headers,
            "Content-Type": "application/json",
        },
    )
    assert response.status_code == 422
    assert "SECRET" not in json.dumps(response.json())


def test_configuration_fails_closed(settings):
    with pytest.raises(ValueError):
        replace(settings, api_token="")
    with pytest.raises(ValueError):
        replace(settings, vault_key="")
