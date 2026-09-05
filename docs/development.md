# Running the first milestone

Implemented: authenticated local camera onboarding, encrypted main/substream URLs and credentials,
SQLite persistence, manual FFprobe video checks, React/TypeScript UI, and private Frigate config
export. ONVIF discovery, continuous health monitoring, live viewing, detection, event rules and
clips are upcoming milestones. There are no fabricated cameras or detection results in the app.

## Local development

Requirements: Python 3.12+, uv, Node.js 22+, npm, and FFmpeg (`ffprobe` on PATH for real checks).

From the project root:

```bash
uv sync --frozen
uv run python -m edge.setup
```

Setup creates `.env` with a random access key and Fernet encryption key, with file mode 0600.
Open `.env` locally and use `CCTV_API_TOKEN` to unlock the browser UI. Keep `.env` with backups of
the SQLite database; changing or losing the vault key prevents decryption of saved connections.
Setup refuses to overwrite existing secrets, and startup refuses a mismatched database/key pair.

Start the backend:

```bash
uv run --env-file .env uvicorn edge.app:create_app --factory --host 127.0.0.1 --port 8000 --no-access-log
```

In another terminal:

```bash
cd web
npm ci
npm run dev
```

Open `http://127.0.0.1:5173`. Vite proxies API requests to the local backend. The access key is held
in browser memory only; reload or lock to clear it. Use the password fields for camera credentials,
not URL userinfo. All addresses, including URL query tokens, are encrypted at rest. API responses
show only the camera name, hostname, capability flags and last manual check result.

Alternatively, `npm run build` in `web/` produces files served by the backend at
`http://127.0.0.1:8000` after restarting it. The app requires no external fonts or cloud resources.

## Docker Compose

Generate `.env` as above, then:

```bash
docker compose up --build -d
```

Open `http://127.0.0.1:8000`. The image contains FFmpeg and the built UI, runs as a non-root user,
and uses a named volume for SQLite. Its filesystem is read-only except the data volume and `/tmp`.
Local development and Compose use different databases by default.

This milestone is for a trusted local administrator. Bindings are loopback-only; use HTTPS and a
reviewed authentication/deployment configuration before exposing it to a LAN or Internet. The
access key is a full-administrator bearer secret, not a multi-user login system.

## Using a camera

1. Unlock the workspace with the generated local access key.
2. Add a name and RTSP main stream, optionally a substream, then separate credentials.
3. Save and click **Check main stream**. A reachable result means FFprobe discovered a video
   stream with dimensions at that moment; it does not establish sustained decode or AI health.
4. If the check fails, verify the network, stream path, and credentials at the camera/NVR.
5. Remove and re-add a connection to correct its settings in this initial version.

Checks use RTSP over TCP, an 8-second socket timeout, a 12-second process deadline, and a maximum
of two concurrent probes. Probe stderr is discarded and raw output is never returned or logged.
FFprobe receives the private URL in process arguments, which the same host user/root can inspect;
this assumes a trusted edge host. The vault encrypts connections, not display names or health data.
No background camera scan runs and no unknown network is scanned automatically.

## API

All routes except `/api/health` require `Authorization: Bearer <CCTV_API_TOKEN>`.

| Route | Purpose |
|---|---|
| `GET /api/health` | Application liveness/version |
| `GET /api/session` | Check access key |
| `GET /api/cameras` | List safe camera metadata |
| `POST /api/cameras` | Add camera; JSON fields: name, main_url, sub_url, username, password |
| `POST /api/cameras/{id}/probe` | Check stream; JSON body: `{"stream":"main"}` |
| `DELETE /api/cameras/{id}` | Remove local saved connection |

The Frigate configuration is exported locally by a CLI, never through a web endpoint. See
[Frigate integration](../integrations/frigate/README.md).

## Verification

```bash
uv run pytest -q
uv run ruff check edge tests integrations/frigate/prepare.py
cd web
npm run build
npx playwright install chromium
npm run test:e2e
```

Browser tests use the real API, SQLite and encryption with a temporary database. Only the RTSP
probe is simulated; actual camera compatibility requires physical hardware or a permitted RTSP
test source. They exercise incorrect credentials, invalid URLs, add/check/reload/remove, and a
mobile layout. Backend tests check authorization, credential non-disclosure, timeout handling,
process concurrency, persistence, wrong-key failure and the Frigate configuration handoff.
