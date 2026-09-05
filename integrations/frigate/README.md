# Frigate development base

The accepted MVP uses Frigate for decoding, restreaming, tracking, recording and review. The first
milestone adds a small onboarding application and an offline configuration handoff; it does not
yet run or replace Frigate's media pipeline. There is no second go2rtc instance.

`upstream.json` pins v0.17.2 to commit `3d4dd3ac4b00e7257bd3412608a783001d7d77ed`.
This is the research baseline, not a claim that it is the newest or a production-safe release.

Prepare a local development checkout from the repository root:

```bash
python3 integrations/frigate/prepare.py
```

The script requires network access, refuses to overwrite an existing checkout, verifies the commit,
and applies the tracked patch series. The resulting `vendor/frigate` is ignored; changes intended
for this project must be preserved as reviewed patches under this directory. No hosted fork or
external repository is created.

The initial patch:

- Restricts the log endpoint to administrators.
- Changes the probe and snapshot endpoints to POST bodies.
- Updates all five identified frontend probe calls to match.
- Bounds the snapshot timeout to 1–15 seconds.

These are targeted first fixes. They do **not** complete the report's security work: probe outputs,
FFmpeg/go2rtc errors, configuration routes, telemetry, proxy access logs, and credential rotation
still require an end-to-end audit and upstream runtime regression tests. The main Compose file
deliberately runs only the onboarding milestone. The Frigate container, upstream frontend build,
RTMDet adapter and OpenVINO hardware configuration are not yet integrated or validated.

After adding cameras, export a private local configuration snapshot:

```bash
uv run --env-file .env python -m edge.frigate
```

For Compose, export against its named volume instead:

```bash
docker compose exec edge /app/.venv/bin/python -m edge.frigate
```

The file lives at `data/frigate/config.yml` (or `/app/data/frigate/config.yml` in the container).
It contains decrypted, URL-encoded credentials for go2rtc. It is owner-readable only and must stay
outside source control. Keep it on the same trusted host; move an old snapshot aside before
exporting a fresh one. Removing a camera from the onboarding database does not remove it from an
already exported snapshot.

The renderer uses stable UUID-based camera keys, routes a main stream to `record` and a substream
to `detect` where configured, and binds go2rtc to loopback. Auth remains enabled. Recording and
detection remain disabled until the pipeline, model and retention settings have been validated.
No hardware acceleration is assumed.

References checked for this implementation:

- [Frigate restream configuration](https://docs.frigate.video/configuration/restream/)
- [Frigate authentication](https://docs.frigate.video/configuration/authentication/)
- [Pinned source](https://github.com/blakeblackshear/frigate/tree/3d4dd3ac4b00e7257bd3412608a783001d7d77ed)

Next integration gate: build and test the patched Frigate checkout, finish credential redaction,
then connect one authorized RTSP source and verify reconnect, live view and clip extraction before
enabling multi-camera inference.
