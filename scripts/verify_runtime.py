"""Verify native Frigate camera lifecycle on a disposable local instance.

Requires an initialized running instance with no cameras. --keep-demo retains only the
clearly labelled synthetic camera after the add/restart/remove checks finish.
"""

import argparse
import shutil
import subprocess
import time
from pathlib import Path

import httpx
import yaml

ROOT = Path(__file__).resolve().parents[1]
NAME = "netwatch-local"
CAMERA = "netwatch_synthetic_test"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default="podman" if shutil.which("podman") else "docker")
    parser.add_argument("--keep-demo", action="store_true")
    args = parser.parse_args()

    def container(*command):
        return subprocess.check_output([args.engine, "exec", NAME, *command], text=True)

    client = httpx.Client(base_url="http://127.0.0.1:8971", timeout=20)

    def wait_ready():
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            try:
                if client.get("/api/version").status_code in (200, 401):
                    return
            except httpx.HTTPError:
                pass
            time.sleep(1)
        raise AssertionError("Frigate did not become ready within 120 seconds")

    def login():
        password = container("cat", "/config/bootstrap-password").strip()
        result = client.post("/api/login", json={"user": "admin", "password": password})
        assert result.status_code == 200, "Native login failed"

    def restart():
        def started_at():
            return subprocess.check_output(
                [args.engine, "inspect", "--format", "{{.State.StartedAt}}", NAME], text=True
            ).strip()

        previous = started_at()
        result = client.post("/api/restart")
        assert result.status_code == 200
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if started_at() != previous:
                wait_ready()
                login()
                return
            time.sleep(1)
        raise AssertionError("Native restart did not restart the container")

    def config():
        return yaml.safe_load(container("cat", "/config/config.yml"))

    wait_ready()
    assert client.get("/api/config/raw").status_code == 401
    assert (
        client.post("/api/login", json={"user": "admin", "password": "incorrect"}).status_code
        == 401
    )
    login()
    assert not client.get("/api/config").json()["cameras"], "Use an empty disposable instance"
    before = container("cat", "/config/config.yml")
    response = client.put(
        "/api/config/set",
        json={"requires_restart": 1, "config_data": {"mqtt": {"port": "invalid"}}},
    )
    assert response.status_code == 400
    assert container("cat", "/config/config.yml") == before
    secret = "netwatch-private-marker"
    response = client.post(
        "/api/ffprobe/snapshot",
        json={"url": f"rtsp://user:{secret}@127.0.0.1:1/live", "timeout": "invalid"},
    )
    assert response.status_code == 422 and secret not in response.text
    for route in ["ffprobe", "ffprobe/snapshot", "onvif/probe", "reolink/detect"]:
        assert client.get(f"/api/{route}").status_code in (404, 405)
    print(
        "PASS: native authentication, failed-write rollback and private request validation",
        flush=True,
    )

    # Values in environment_vars were previously exposed through the shared config endpoint.
    private_update = {
        "requires_restart": 0,
        "config_data": {"environment_vars": {"FRIGATE_TEST_SECRET": secret}},
    }
    assert client.put("/api/config/set", json=private_update).status_code == 200
    assert secret not in client.get("/api/config").text
    private_update["config_data"]["environment_vars"]["FRIGATE_TEST_SECRET"] = ""
    assert client.put("/api/config/set", json=private_update).status_code == 200

    # Native roles must not grant viewers access to logs or unscoped static media.
    viewer_name = "netwatch_test_viewer"
    viewer_password = "NetwatchFixturePassword_2026!"
    result = client.post(
        "/api/users", json={"username": viewer_name, "password": viewer_password, "role": "viewer"}
    )
    assert result.status_code == 200, result.text
    try:
        with httpx.Client(base_url=str(client.base_url), timeout=20) as viewer:
            assert (
                viewer.post(
                    "/api/login", json={"user": viewer_name, "password": viewer_password}
                ).status_code
                == 200
            )
            assert viewer.get("/api/logs/frigate").status_code == 403
            assert viewer.get("/api/config/raw").status_code == 403
            for path in [
                "/clips/absent.mp4",
                "/recordings/absent.mp4",
                "/exports/absent.mp4",
                "/clips%2fabsent.mp4",
            ]:
                assert viewer.get(path).status_code == 403, path
    finally:
        assert client.delete(f"/api/users/{viewer_name}").status_code == 200
    print("PASS: viewer denied logs, raw configuration and direct static media", flush=True)

    # Existing native settings still use non-secret query updates. Protect the connection
    # namespace without breaking motion tuning and zone editing elsewhere in Frigate.
    assert (
        client.put(
            "/api/config/set",
            json={
                "requires_restart": 1,
                "config_data": {
                    "cameras": {
                        "netwatch_query_test": {
                            "ffmpeg": {
                                "inputs": [
                                    {
                                        "path": "rtsp://127.0.0.1:8554/netwatch_query_test",
                                        "roles": ["detect"],
                                    }
                                ]
                            }
                        }
                    }
                },
            },
        ).status_code
        == 200
    )
    assert (
        client.put(
            "/api/config/set?cameras.netwatch_query_test.motion.threshold=35",
            json={"requires_restart": 1},
        ).status_code
        == 200
    )
    assert config()["cameras"]["netwatch_query_test"]["motion"]["threshold"] == 35
    assert (
        client.put(
            "/api/config/set?cameras.netwatch_query_test.ffmpeg.inputs=blocked",
            json={"requires_restart": 1},
        ).status_code
        == 400
    )
    assert (
        client.put(
            "/api/config/set",
            json={"requires_restart": 1, "config_data": {"cameras": {"netwatch_query_test": None}}},
        ).status_code
        == 200
    )
    print("PASS: native motion-setting queries work; connection queries are rejected", flush=True)

    # Produce our own moving test pattern using the image's actual FFmpeg binary.
    ffmpeg = container(
        "python3",
        "-c",
        "from frigate.config.camera.ffmpeg import FfmpegConfig; print(FfmpegConfig().ffmpeg_path)",
    ).strip()
    container(
        ffmpeg,
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "lavfi",
        "-i",
        "testsrc2=size=640x360:rate=10",
        "-t",
        "12",
        "-an",
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-pix_fmt",
        "yuv420p",
        "/media/frigate/netwatch-fixture.mp4",
    )
    payload = {
        "requires_restart": 1,
        "config_data": {
            "cameras": {
                CAMERA: {
                    "enabled": True,
                    "friendly_name": "Synthetic video test — not a real camera",
                    "ffmpeg": {
                        "inputs": [
                            {
                                "path": f"rtsp://127.0.0.1:8554/{CAMERA}",
                                "input_args": "preset-rtsp-restream",
                                "roles": ["detect"],
                            }
                        ]
                    },
                    "detect": {"enabled": False, "width": 640, "height": 360, "fps": 5},
                    "live": {"streams": {"Test pattern": CAMERA}},
                }
            },
            "go2rtc": {
                "streams": {
                    CAMERA: (
                        "ffmpeg:/media/frigate/netwatch-fixture.mp4#video=copy"
                        "#input=-re -stream_loop -1 -i /media/frigate/netwatch-fixture.mp4"
                    )
                }
            },
        },
    }

    def enroll():
        response = client.put("/api/config/set", json=payload)
        assert response.status_code == 200, response.text
        saved = config()
        assert CAMERA in saved["cameras"] and CAMERA in saved["go2rtc"]["streams"]
        assert container("stat", "-c", "%a", "/config/config.yml").strip() == "600"
        restart()
        assert CAMERA in client.get("/api/config").json()["cameras"]
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            stats = client.get("/api/stats").json()
            camera = stats.get("cameras", {}).get(CAMERA, {})
            if camera.get("camera_fps", 0) > 0:
                response = client.get(f"/api/{CAMERA}/latest.jpg")
                assert response.status_code == 200 and response.content.startswith(b"\xff\xd8")
                print(
                    f"PASS: decoded synthetic video ({camera['camera_fps']} fps), "
                    "JPEG and restart persistence",
                    flush=True,
                )
                return
            time.sleep(1)
        raise AssertionError("No decoded frames from synthetic RTSP restream")

    enroll()
    result = client.put(
        "/api/config/set", json={"requires_restart": 1, "config_data": {"cameras": {CAMERA: None}}}
    )
    assert result.status_code == 200, result.text
    saved = config()
    assert not saved.get("cameras", {}).get(CAMERA)
    assert CAMERA not in saved["go2rtc"]["streams"]
    restart()
    assert CAMERA not in client.get("/api/config").json()["cameras"]
    streams = container(
        "python3",
        "-c",
        "import requests; print(requests.get('http://127.0.0.1:1984/api/streams').text)",
    )
    assert CAMERA not in streams
    print("PASS: removal persists across restart and removes the running restream", flush=True)
    if args.keep_demo:
        enroll()
        print("Synthetic camera retained for Firefox review.", flush=True)
    else:
        container("rm", "/media/frigate/netwatch-fixture.mp4")


if __name__ == "__main__":
    main()
