"""Create local secrets once: uv run python -m edge.setup."""

import os
import secrets
from pathlib import Path

from cryptography.fernet import Fernet


def main():
    path = Path(".env")
    content = (
        f"CCTV_API_TOKEN={secrets.token_urlsafe(32)}\n"
        f"CCTV_VAULT_KEY={Fernet.generate_key().decode()}\n"
    )
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        raise SystemExit(".env already exists; kept your existing secrets.") from None
    with os.fdopen(fd, "w") as output:
        output.write(content)
    print("Created .env (owner access only). Use its CCTV_API_TOKEN to unlock the local UI.")


if __name__ == "__main__":
    main()
