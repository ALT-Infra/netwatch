import stat

import pytest
import yaml

from edge.frigate import render_config, write_config
from edge.schemas import CameraInput
from edge.store import Store


def test_main_substream_handoff_and_private_file(settings, camera_input, tmp_path):
    store = Store(settings)
    camera = store.create(CameraInput(**camera_input))
    destination = tmp_path / "frigate" / "config.yml"
    write_config(store, destination)
    assert stat.S_IMODE(destination.stat().st_mode) == 0o600
    config = yaml.safe_load(destination.read_text())
    name = f"camera_{camera.id}"
    assert config["auth"]["enabled"] is True
    assert config["go2rtc"]["rtsp"]["listen"] == "127.0.0.1:8554"
    inputs = config["cameras"][name]["ffmpeg"]["inputs"]
    assert inputs[0]["roles"] == ["record"]
    assert inputs[1]["roles"] == ["detect"]
    assert inputs[1]["path"].endswith("_sub")
    assert config["cameras"][name]["detect"]["enabled"] is False
    with pytest.raises(FileExistsError):
        write_config(store, destination)


def test_single_stream_is_pulled_once(settings, camera_input):
    camera_input["sub_url"] = None
    store = Store(settings)
    camera = store.create(CameraInput(**camera_input))
    config = render_config(store)
    assert len(config["go2rtc"]["streams"]) == 1
    assert config["cameras"][f"camera_{camera.id}"]["ffmpeg"]["inputs"][0]["roles"] == [
        "record",
        "detect",
    ]
