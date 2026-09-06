"""A stalled diagnostic must not hide or prolong the actual browser test failure."""

import runpy
import time
from pathlib import Path

import pytest
from selenium.common.exceptions import TimeoutException

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize(
    ("engine_body", "diagnostic_error"),
    [
        ("import time; time.sleep(10)", "TimeoutExpired"),
        ("raise SystemExit(2)", "CalledProcessError"),
    ],
)
def test_diagnostics_preserve_preview_failure(tmp_path, capsys, engine_body, diagnostic_error):
    engine = tmp_path / "engine"
    engine.write_text("#!/usr/bin/env python3\n" + engine_body + "\n")
    engine.chmod(0o700)
    module = runpy.run_path(str(ROOT / "scripts/verify_browser.py"))
    diagnose = module["dump_go2rtc_streams"]
    diagnose.__globals__["DIAGNOSTIC_PROCESS_TIMEOUT"] = 0.2
    original = TimeoutException("Preview did not produce video")
    started = time.monotonic()
    with pytest.raises(TimeoutException) as failure:
        try:
            raise original
        except TimeoutException:
            diagnose(str(engine))
            raise
    assert failure.value is original
    assert time.monotonic() - started < 2
    assert diagnostic_error in capsys.readouterr().out
