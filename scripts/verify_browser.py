"""Exercise the native camera manager in Firefox against the synthetic runtime fixture."""

import argparse
import shutil
import subprocess
import time
from pathlib import Path

import httpx
import yaml
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

ROOT = Path(__file__).resolve().parents[1]
NAME = "netwatch-local"
CAMERA = "netwatch_browser_test"
FIXTURE = "netwatch_synthetic_test"
BASE = "http://127.0.0.1:8971"


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
        click("Next")
        wait.until(
            lambda d: d.execute_script(
                "return [...document.querySelectorAll('video')].some(v => v.videoWidth > 0)"
            )
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
                "return innerWidth === 390 && document.documentElement.scrollWidth <= innerWidth"
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
