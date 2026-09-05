import subprocess
from unittest.mock import patch

import pytest

from edge.probe import ProbeBusy, ProbeUnavailable, StreamProbe


def test_success_uses_bounded_process_without_shell():
    result = subprocess.CompletedProcess(
        [], 0, b'{"streams":[{"codec_name":"h264","width":640,"height":360}]}'
    )
    with patch("edge.probe.subprocess.run", return_value=result) as run:
        assert StreamProbe()("rtsp://private:secret@192.0.2.1/live").status == "reachable"
    kwargs = run.call_args.kwargs
    assert kwargs["timeout"] == 12
    assert kwargs["stderr"] == subprocess.DEVNULL
    assert not kwargs.get("shell", False)


@pytest.mark.parametrize(
    "output",
    [
        b"SECRET",
        b'{"streams":[]}',
        b'{"streams":[null]}',
        b'{"streams":[{"codec_name":"SECRET@host","width":640,"height":360}]}',
    ],
)
def test_bad_media_never_echoes_output(output):
    with patch(
        "edge.probe.subprocess.run", return_value=subprocess.CompletedProcess([], 0, output)
    ):
        result = StreamProbe()("rtsp://192.0.2.1/live")
        assert result.status == "unreachable"
        assert "SECRET" not in result.model_dump_json()


def test_timeout_and_missing_binary():
    with patch("edge.probe.subprocess.run", side_effect=subprocess.TimeoutExpired("SECRET", 12)):
        assert StreamProbe()("rtsp://192.0.2.1/live").status == "unreachable"
    with patch("edge.probe.subprocess.run", side_effect=FileNotFoundError):
        with pytest.raises(ProbeUnavailable):
            StreamProbe()("rtsp://192.0.2.1/live")


def test_probe_concurrency_cap():
    probe = StreamProbe()
    probe.slots.acquire()
    probe.slots.acquire()
    with pytest.raises(ProbeBusy):
        probe("rtsp://192.0.2.1/live")
