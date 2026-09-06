# netwatch

A local CCTV application built on a controlled Frigate foundation. The current implementation
provides native administrator login, camera enrollment, live video, editing and removal, using
Frigate with embedded go2rtc and FFmpeg. OpenVINO and Norfair are inherited; detection and
recording are disabled in the local default. The person-in-zone incident and operator-verdict
module described in [report.typ](report.typ) remains to be implemented.

## Run locally

Install **uv**, **Podman or Docker**, and **Firefox**. Initial preparation/build needs network
access. Python tooling uses Python 3.12 through uv; the image preserves Frigate's matching Python
runtime. The container builds the frontend with pinned Node 22 and pnpm 11.3.0.

```bash
uv sync --frozen --python 3.12
uv run integrations/frigate/prepare.py
uv run scripts/local.py init
uv run scripts/local.py build
uv run scripts/local.py start
uv run scripts/local.py password
```

Open **http://127.0.0.1:8971 in Firefox**, username `admin`, with the printed bootstrap password.
Change it in the account settings, then remove `data/config/bootstrap-password` when no longer
needed. The password file is private and excluded from Git; the password is not logged.

Preparation refuses to overwrite an existing `vendor/frigate` checkout. Initialization preserves
existing configuration. The helper selects Podman when installed; add `--engine docker` to use
Docker explicitly. Stopping preserves configuration and media:

```bash
uv run scripts/local.py logs
uv run scripts/local.py restart
uv run scripts/local.py stop
```

After rebuilding, use `stop` then `start` to run the new image. `restart` keeps the existing image.
Alternatively, after prepare/init, use `docker compose up --build -d`. Use the helper or Compose
for a given instance; verification scripts target the helper's `netwatch-local` container.

## Use the camera manager

1. Open **Settings → Management → Add New Camera**. Enter an authorized camera address;
   use ONVIF when supported or provide a manual RTSP URL.
2. Probe and preview the stream, select its inputs, then **Save New Camera**. Camera and
   restream definitions are validated and saved together.
3. Select **Restart to apply saved changes**, then reload once the application is ready.
4. Use **Edit camera** to change its display name or connection. The camera identifier stays
   stable. **Remove camera** removes the configuration and unshared restream sources;
   restart applies removal. Existing recordings retain their configured retention policy.

The camera list reflects the running configuration until restart. Editing loads the latest saved
settings, including pending changes. A successful save is not evidence that a camera is running.

Only the authenticated UI port is published, on loopback. HTTP is a local development default;
LAN deployment needs TLS and reviewed access settings. `data/config/config.yml` is the single
camera configuration, protected with mode 0600 in a 0700 directory. Camera credentials are
**plaintext in that private file**, not in a separate encrypted registry. Protect backups equally.
Frigate's native environment substitutions and mounted secrets are available for managed setups.
Direct static recordings, clips, exports and logs require an administrator. This local build is
not production qualification or proof of complete isolation across all inherited endpoints.

## Develop and verify

Use **uv for Python** and **pnpm for JavaScript**. For frontend development, install Node 22+
and pnpm 11.3.0, then:

```bash
pnpm --dir vendor/frigate/web install --frozen-lockfile
pnpm --dir vendor/frigate/web run build
uv run ruff check scripts tests integrations/frigate/prepare.py
uv run pytest -q
```

The Python tests require the built image and exercise its actual Frigate parser: invalid and
concurrent writes, failed replacement, private file permissions, removal and redaction.
To check a **disposable instance with no configured cameras**, start it using the helper and run:

```bash
uv run scripts/verify_runtime.py --keep-demo
uv run scripts/verify_browser.py
```

Runtime verification checks authentication, protected endpoints, secret handling, real FFmpeg
decoding, persistence and restart/removal. It leaves one clearly labeled synthetic video feed.
The Firefox test adds, previews, edits and removes another fixture, verifies live playback and
checks a 390px embedded viewport (Firefox limits top-level window width). It requires the retained runtime fixture; both scripts refuse unrelated
camera configurations. Selenium Manager may download its Firefox driver on first use. Synthetic
video verifies the application lifecycle, not physical camera compatibility or detection accuracy.
CI runs the same image, Python, runtime and Firefox checks with Docker.

## Source and repository map

- [report.typ](report.typ): research decisions, rationale, evidence and acceptance criteria.
- [architecture/architecture.html](architecture/architecture.html): offline interactive 3D
  architecture and protocol map. Open directly in Firefox; it describes the design, not a dashboard.
- [AGENTS.md](AGENTS.md): concise working rules for agents.
- [integrations/frigate/upstream.json](integrations/frigate/upstream.json): exact Frigate source
  revision, runtime image digest and maintained patch series.
- [integrations/frigate/patches/](integrations/frigate/patches/): changes to the native application.
  Keep edits made in ignored `vendor/frigate` reproducible here, together with the integration's
  pnpm lockfile and build approvals. Verify patches against a fresh pinned checkout.
- [deploy/config.example.yml](deploy/config.example.yml), [Dockerfile](Dockerfile) and
  [compose.yaml](compose.yaml): runtime defaults and packaging.
- [scripts/](scripts/) and [tests/](tests/): lifecycle helpers and verification.

The image overlays patched Python and the pnpm-built native frontend on the matching Frigate
runtime, retaining its media libraries, models, migrations and upstream notices. Dependency
versions are pinned implementation inputs; upgrades require the release review in `report.typ`.
Code, model, dataset and binary licenses remain distinct; this repository supplies no additional
license grant. Bulk research, source checkouts, models, runtime data and rendered PDFs are ignored.

Render the research locally with Typst:

```bash
typst compile report.typ /tmp/netwatch-research.pdf
```
