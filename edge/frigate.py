"""Render a private Frigate camera config: uv run --env-file .env python -m edge.frigate."""

import os
from pathlib import Path

import yaml

from edge.settings import Settings
from edge.store import Store

UPSTREAM_COMMIT = "3d4dd3ac4b00e7257bd3412608a783001d7d77ed"


def render_config(store: Store):
    streams, cameras = {}, {}
    for camera in store.list():
        name = f"camera_{camera.id}"
        streams[name] = [store.stream_url(camera.id)]
        inputs = [
            {
                "path": f"rtsp://127.0.0.1:8554/{name}",
                "input_args": "preset-rtsp-restream",
                "roles": ["record"] if camera.has_substream else ["record", "detect"],
            }
        ]
        if camera.has_substream:
            streams[f"{name}_sub"] = [store.stream_url(camera.id, "sub")]
            inputs.append(
                {
                    "path": f"rtsp://127.0.0.1:8554/{name}_sub",
                    "input_args": "preset-rtsp-restream",
                    "roles": ["detect"],
                }
            )
        cameras[name] = {"ffmpeg": {"inputs": inputs}, "detect": {"enabled": False}}
    return {
        "mqtt": {"enabled": False},
        "auth": {"enabled": True},
        "go2rtc": {
            "api": {"listen": "127.0.0.1:1984"},
            "rtsp": {"listen": "127.0.0.1:8554"},
            "streams": streams,
        },
        "record": {"enabled": False},
        "cameras": cameras,
    }


def write_config(store: Store, destination: Path):
    # Explicit offline handoff; never return decrypted configuration through an HTTP endpoint.
    if not store.list():
        raise ValueError("Add at least one camera before rendering a Frigate config.")
    content = yaml.safe_dump(render_config(store), sort_keys=False)
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as output:
        output.write(content)


def main():
    settings = Settings.from_env()
    destination = settings.data_dir / "frigate" / "config.yml"
    try:
        write_config(Store(settings), destination)
    except (ValueError, FileExistsError) as exc:
        if isinstance(exc, FileExistsError):
            raise SystemExit(
                "Config exists; move it aside before exporting a fresh snapshot."
            ) from None
        raise SystemExit(str(exc)) from None
    print(f"Saved private config to {destination}. It contains camera credentials; keep it local.")


if __name__ == "__main__":
    main()
