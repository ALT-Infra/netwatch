"""Exercise the native camera manager in Firefox against the synthetic runtime fixture."""

import argparse
import shutil
import subprocess
import time
from pathlib import Path

import httpx
import yaml
from selenium import webdriver
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

ROOT = Path(__file__).resolve().parents[1]
NAME = "netwatch-local"
CAMERA = "netwatch_browser_test"
FIXTURE = "netwatch_synthetic_test"
BASE = "http://127.0.0.1:8971"


DIAGNOSTIC_PROCESS_TIMEOUT = 8


def dump_go2rtc_streams(engine):
    """Diagnostics must finish even when the media service or container engine hangs."""
    try:
        streams = subprocess.check_output(
            [
                engine,
                "exec",
                NAME,
                "python3",
                "-c",
                "import requests; "
                "response = requests.get('http://127.0.0.1:1984/api/streams', timeout=(2, 3)); "
                "response.raise_for_status(); print(response.text[:2000])",
            ],
            text=True,
            timeout=DIAGNOSTIC_PROCESS_TIMEOUT,
        )
        print(f"DIAG: go2rtc streams: {streams[:2000]}", flush=True)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print(f"DIAG: go2rtc streams unavailable ({type(exc).__name__})", flush=True)


def inject_preview_delay(driver):
    """Delay actual WebSocket sends; leave the player and its deadline unchanged."""
    driver.execute_script("""
        const NativeWebSocket = window.WebSocket;
        const test = window.netwatchPreviewTest = {mode: 'withhold', attempts: []};
        window.WebSocket = class extends NativeWebSocket {
            send(data) {
                if (this.url.includes('/live/mse/api/ws?src=wizard_')
                    && typeof data === 'string' && JSON.parse(data).type === 'mse') {
                    const attempt = {mode: test.mode, started: performance.now()};
                    test.attempts.push(attempt);
                    this.addEventListener('close', () => {
                        attempt.closedAfter = performance.now() - attempt.started;
                    }, {once: true});
                    if (test.mode === 'withhold') return;
                    if (test.mode === 'delay') {
                        setTimeout(() => {
                            if (this.readyState === NativeWebSocket.OPEN) {
                                attempt.sentAfter = performance.now() - attempt.started;
                                super.send(data);
                            }
                        }, 4000);
                        return;
                    }
                }
                super.send(data);
            }
        };
        test.restore = () => { window.WebSocket = NativeWebSocket; };
    """)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default="podman" if shutil.which("podman") else "docker")
    args = parser.parse_args()

    def container(*command):
        return subprocess.check_output([args.engine, "exec", NAME, *command], text=True)

    def raw_config():
        return yaml.safe_load(container("cat", "/config/config.yml"))

    assert set(raw_config()["cameras"]) == {FIXTURE}, "Run verify_runtime.py --keep-demo first"
    password = container("cat", "/config/bootstrap-password").strip()
    options = Options()
    options.add_argument("-headless")
    driver = webdriver.Firefox(options=options)
    wait = WebDriverWait(driver, 45)

    def click(text):
        wait.until(
            EC.element_to_be_clickable((By.XPATH, f'//button[normalize-space(.)="{text}"]'))
        ).click()

    def manager():
        driver.get(BASE + "/settings")
        wait.until(
            EC.element_to_be_clickable((By.XPATH, '//*[normalize-space(text())="Management"]'))
        ).click()
        wait.until(
            EC.element_to_be_clickable((By.XPATH, '//button[normalize-space(.)="Add New Camera"]'))
        )

    def restart_from_ui():
        def started_at():
            return subprocess.check_output(
                [args.engine, "inspect", "--format", "{{.State.StartedAt}}", NAME], text=True
            )

        before = started_at()
        click("Restart to apply saved changes")
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if started_at() != before:
                try:
                    if httpx.get(BASE + "/api/version").status_code == 401:
                        manager()
                        return
                except httpx.HTTPError:
                    pass
            time.sleep(1)
        raise AssertionError("UI restart did not restore the application")

    try:
        driver.set_window_size(1400, 950)
        driver.get(BASE + "/login")
        wait.until(EC.visibility_of_element_located((By.NAME, "user"))).send_keys("admin")
        driver.find_element(By.NAME, "password").send_keys(password)
        click("Login")
        wait.until(lambda d: "/login" not in d.current_url)
        manager()
        driver.execute_script("""
            window.netwatchWrites = [];
            const originalOpen = XMLHttpRequest.prototype.open;
            const originalSend = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.open = function(method, url, ...args) {
                this.netwatchConfigWrite = method.toUpperCase() === 'PUT'
                    && url.endsWith('/config/set');
                return originalOpen.call(this, method, url, ...args);
            };
            XMLHttpRequest.prototype.send = function(body) {
                if (this.netwatchConfigWrite) window.netwatchWrites.push(JSON.parse(body));
                return originalSend.call(this, body);
            };
        """)
        click("Add New Camera")
        wait.until(EC.visibility_of_element_located((By.CSS_SELECTOR, '[role="dialog"]')))
        driver.find_element(By.NAME, "cameraName").send_keys(CAMERA)
        driver.find_element(By.NAME, "host").send_keys("127.0.0.1")
        driver.find_element(By.CSS_SELECTOR, 'label[for="manual-mode"]').click()
        driver.find_element(By.CSS_SELECTOR, '[role="combobox"]').click()
        wait.until(
            EC.element_to_be_clickable(
                (By.XPATH, '//*[@role="option" and normalize-space(.)="Other"]')
            )
        ).click()
        driver.find_element(By.NAME, "customUrl").send_keys(f"rtsp://127.0.0.1:8554/{FIXTURE}")
        click("Continue")
        # The metadata/snapshot step probes the actual embedded RTSP server.
        wait.until(
            lambda d: "Camera Name" not in d.find_element(By.CSS_SELECTOR, '[role="dialog"]').text
        )
        click("Continue")
        # Choose the embedded restream, retaining its FFmpeg input preset when editing later.
        driver.find_element(
            By.XPATH,
            '//*[normalize-space(text())="Reduce connections to camera"]'
            '/following-sibling::*[@role="switch"]',
        ).click()
        inject_preview_delay(driver)
        click("Next")
        # Firefox decodes H.264 MSE via the system libavcodec. If the runner
        # lacks it, MediaSource rejects every avc1/mp4a codec and no preview
        # can ever produce a frame: fail fast with a clear cause instead of
        # burning the 120s playback deadline. The videoWidth gate below still
        # decides pass/fail when decoding is available.
        supported = driver.execute_script(
            "return MediaSource.isTypeSupported('video/mp4; codecs=\"avc1.640029\"')"
        )
        assert supported, (
            "Firefox reports no H.264 MSE support "
            "(MediaSource.isTypeSupported avc1.640029 is false); "
            "install system FFmpeg/libavcodec on this runner"
        )
        # Negative control: the actual player must reject an unanswered handshake.
        wait.until(
            EC.visibility_of_element_located(
                (By.XPATH, '//*[normalize-space(text())="Stream preview unavailable"]')
            )
        )
        wait.until(
            lambda d: d.execute_script(
                "return window.netwatchPreviewTest.attempts.some(a => a.closedAfter !== undefined)"
            )
        )
        attempts = driver.execute_script("return window.netwatchPreviewTest.attempts")
        assert len(attempts) == 1 and attempts[0]["mode"] == "withhold", attempts
        assert 14000 <= attempts[0]["closedAfter"] <= 20000, attempts
        assert driver.execute_script("return window.netwatchWrites") == []
        # Recovery control: delay the real handshake beyond the former 3s deadline.
        driver.execute_script("window.netwatchPreviewTest.mode = 'delay'")
        click("Reload")
        # This is a test budget, not a claim about the cause of historical CI failures.
        try:
            WebDriverWait(driver, 120).until(
                lambda d: d.execute_script(
                    "return [...document.querySelectorAll('video')].some(v => v.videoWidth > 0)"
                )
            )
        except TimeoutException:
            print("DIAG: preview video never decoded; dumping player state", flush=True)
            print(
                driver.execute_script(
                    "return JSON.stringify({"
                    " codecs: ['avc1.640029','avc1.64002A','avc1.640033',"
                    "  'hvc1.1.6.L153.B0','mp4a.40.2','opus'].map(c => {"
                    "   let s = false;"
                    "   try { s = MediaSource.isTypeSupported("
                    "    'video/mp4; codecs=\"' + c + '\"') } catch (e) {};"
                    "   return c + '=' + s }) ,"
                    " videos: [...document.querySelectorAll('video')].map(v => ({"
                    "  w: v.videoWidth, h: v.videoHeight,"
                    "  rs: v.readyState, ns: v.networkState,"
                    "  err: v.error ? v.error.code : 0, src: v.currentSrc }))})"
                ),
                flush=True,
            )
            dump_go2rtc_streams(args.engine)
            raise
        attempts = driver.execute_script("return window.netwatchPreviewTest.attempts")
        delayed = [a for a in attempts if a["mode"] == "delay"]
        assert len(delayed) == 1 and delayed[0].get("sentAfter", 0) >= 4000, attempts
        # Dimensions alone can be available at metadata time. Require advancing frames too.
        frames = driver.execute_script(
            "return document.querySelector('video').getVideoPlaybackQuality().totalVideoFrames"
        )
        wait.until(
            lambda d: (
                d.execute_script(
                    "return document.querySelector('video')"
                    ".getVideoPlaybackQuality().totalVideoFrames"
                )
                > frames
            )
        )
        driver.execute_script("window.netwatchPreviewTest.restore()")
        print(
            "PASS: withheld handshake times out; 4s delay recovers with advancing video",
            flush=True,
        )
        click("Save New Camera")
        wait.until(EC.invisibility_of_element_located((By.CSS_SELECTOR, '[role="dialog"]')))
        writes = driver.execute_script("return window.netwatchWrites")
        assert len(writes) == 1, "Enrollment must persist camera and sources in one request"
        assert CAMERA in writes[0]["config_data"]["cameras"]
        assert CAMERA in writes[0]["config_data"]["go2rtc"]["streams"]
        assert CAMERA in raw_config()["cameras"]
        restart_from_ui()
        print(
            "PASS: Firefox login, real stream preview, single enrollment write and UI restart",
            flush=True,
        )
        assert set(raw_config()["cameras"]) == {CAMERA, FIXTURE}
        # Management sorts camera keys; our browser fixture precedes the retained synthetic feed.
        driver.find_elements(By.XPATH, '//button[normalize-space(.)="Edit camera"]')[0].click()
        field = wait.until(EC.visibility_of_element_located((By.NAME, "cameraName")))
        assert field.get_attribute("value") == CAMERA
        before_inputs = raw_config()["cameras"][CAMERA]["ffmpeg"]["inputs"]
        assert before_inputs[0]["input_args"] == "preset-rtsp-restream"
        field.clear()
        field.send_keys("Browser verified camera")
        click("Save")
        wait.until(
            lambda d: (
                raw_config()["cameras"][CAMERA].get("friendly_name") == "Browser verified camera"
            )
        )
        assert set(raw_config()["cameras"]) == {CAMERA, FIXTURE}
        assert raw_config()["cameras"][CAMERA]["ffmpeg"]["inputs"] == before_inputs
        wait.until(
            EC.element_to_be_clickable((By.XPATH, '//button[normalize-space(.)="Edit camera"]'))
        ).click()
        click("Remove camera")
        wait.until(EC.alert_is_present()).accept()
        wait.until(lambda d: CAMERA not in raw_config()["cameras"])
        assert CAMERA not in raw_config()["go2rtc"]["streams"]
        restart_from_ui()
        driver.save_screenshot(str(ROOT / "data/firefox-cameras.png"))
        print(
            "PASS: Firefox display-name edit preserves identity; "
            "removal prunes source and persists",
            flush=True,
        )
        driver.get(BASE)
        wait.until(
            lambda d: d.execute_script(
                "return [...document.querySelectorAll('video')].some(v => v.videoWidth > 0)"
            )
        )
        driver.save_screenshot(str(ROOT / "data/firefox-live.png"))
        # Firefox clamps top-level windows to 500px. A same-origin frame gives the app
        # a real 390px CSS viewport rather than silently testing the clamped window.
        driver.set_window_size(800, 1000)
        driver.execute_script("""
            const frame = document.createElement('iframe');
            frame.src = '/';
            frame.style.cssText = 'width:390px;height:844px;border:0';
            document.body.replaceChildren(frame);
        """)
        frame = driver.find_element(By.TAG_NAME, "iframe")
        driver.switch_to.frame(frame)
        wait.until(
            lambda d: d.execute_script(
                "return innerWidth === 390 && document.documentElement"
                " && document.documentElement.scrollWidth <= innerWidth"
                " && [...document.querySelectorAll('video')].some(v => v.videoWidth > 0)"
            )
        )
        driver.switch_to.default_content()
        frame.screenshot(str(ROOT / "data/firefox-mobile.png"))
        print("PASS: Firefox live video and 390px layout", flush=True)
    finally:
        driver.save_screenshot(str(ROOT / "data/firefox-last.png"))
        driver.quit()


if __name__ == "__main__":
    main()
