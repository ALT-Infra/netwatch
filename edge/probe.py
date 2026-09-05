import json
import re
import subprocess
from threading import BoundedSemaphore

from edge.schemas import ProbeResult


class ProbeBusy(Exception):
    pass


class ProbeUnavailable(Exception):
    pass


class StreamProbe:
    def __init__(self):
        self.slots = BoundedSemaphore(2)

    def __call__(self, url: str) -> ProbeResult:
        if not self.slots.acquire(blocking=False):
            raise ProbeBusy
        try:
            return self.run(url)
        finally:
            self.slots.release()

    @staticmethod
    def run(url):
        # No shell, no stderr forwarding, no raw probe output in API responses or logs.
        # The private URL is necessarily present in the child process argv: trust the host.
        try:
            process = subprocess.run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-rtsp_transport",
                    "tcp",
                    "-rw_timeout",
                    "8000000",
                    "-protocol_whitelist",
                    "rtsp,tcp,udp,rtp,crypto",
                    "-analyzeduration",
                    "2000000",
                    "-probesize",
                    "1000000",
                    "-select_streams",
                    "v:0",
                    "-show_entries",
                    "stream=codec_name,width,height",
                    "-of",
                    "json",
                    url,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                timeout=12,
                check=False,
            )
        except FileNotFoundError:
            raise ProbeUnavailable from None
        except (subprocess.TimeoutExpired, OSError):
            return ProbeResult(
                status="unreachable", message="Connection timed out or could not open."
            )
        try:
            streams = json.loads(process.stdout).get("streams", [])
            stream = streams[0] if streams else {}
            width, height = int(stream.get("width", 0)), int(stream.get("height", 0))
            codec = stream.get("codec_name", "unknown")
            if (
                process.returncode == 0
                and 0 < width <= 65536
                and 0 < height <= 65536
                and isinstance(codec, str)
                and re.fullmatch(r"[a-zA-Z0-9_]{1,40}", codec)
            ):
                return ProbeResult(
                    status="reachable",
                    message="Video stream responded.",
                    codec=codec,
                    width=width,
                    height=height,
                )
        except (ValueError, TypeError, AttributeError, IndexError):
            pass
        return ProbeResult(
            status="unreachable", message="No usable video stream. Check address and credentials."
        )
