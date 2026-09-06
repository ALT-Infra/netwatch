"""Local lifecycle using Podman or Docker; no independent application server."""

import argparse
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "netwatch-local"
IMAGE = "localhost/netwatch:local"


def run(*args, **kwargs):
    return subprocess.run(args, check=True, cwd=ROOT, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "action", choices=["init", "build", "start", "stop", "restart", "logs", "password"]
    )
    parser.add_argument(
        "--engine",
        choices=["podman", "docker"],
        default="podman" if shutil.which("podman") else "docker",
    )
    args = parser.parse_args()
    engine = args.engine
    config = ROOT / "data/config"
    media = ROOT / "data/media"
    if args.action == "init":
        for folder in [config, media]:
            folder.mkdir(parents=True, exist_ok=True, mode=0o700)
            folder.chmod(0o700)
        target = config / "config.yml"
        if target.exists():
            print("Existing configuration preserved.")
            return
        with target.open("x") as out:
            target.chmod(0o600)
            out.write((ROOT / "deploy/config.example.yml").read_text())
        print("Created private configuration. Run build, then start.")
    elif args.action == "build":
        if not (ROOT / "vendor/frigate/web/pnpm-lock.yaml").exists():
            raise SystemExit("Run uv run integrations/frigate/prepare.py first")
        options = ["--format", "docker"] if engine == "podman" else []
        run(engine, "build", *options, "-t", IMAGE, ".")
    elif args.action == "start":
        if not (config / "config.yml").exists():
            raise SystemExit("Run init first")
        run(
            engine,
            "run",
            "-d",
            "--name",
            NAME,
            "--restart=unless-stopped",
            "--shm-size=256m",
            "--security-opt=no-new-privileges",
            "--tmpfs",
            "/tmp/cache:size=256m",
            "-p",
            "127.0.0.1:8971:8971",
            "-v",
            f"{config}:/config",
            "-v",
            f"{media}:/media/frigate",
            IMAGE,
        )
        print("Open http://127.0.0.1:8971 in Firefox. Username: admin.")
    elif args.action == "stop":
        run(engine, "stop", "-t", "30", NAME)
        run(engine, "rm", NAME)
    elif args.action == "restart":
        run(engine, "restart", NAME)
    elif args.action == "logs":
        run(engine, "logs", "--tail", "100", NAME)
    elif args.action == "password":
        run(engine, "exec", NAME, "cat", "/config/bootstrap-password")


if __name__ == "__main__":
    main()
