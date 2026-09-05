import os
from dataclasses import dataclass
from pathlib import Path

from cryptography.fernet import Fernet


@dataclass(frozen=True)
class Settings:
    data_dir: Path
    api_token: str
    vault_key: str
    web_dir: Path = Path("web/dist")

    def __post_init__(self):
        if len(self.api_token) < 32:
            raise ValueError("CCTV_API_TOKEN must contain at least 32 characters. Run edge.setup.")
        try:
            Fernet(self.vault_key.encode())
        except (ValueError, TypeError):
            raise ValueError("CCTV_VAULT_KEY must be a valid Fernet key. Run edge.setup.") from None

    @classmethod
    def from_env(cls):
        return cls(
            data_dir=Path(os.getenv("CCTV_DATA_DIR", "data")),
            api_token=os.getenv("CCTV_API_TOKEN", ""),
            vault_key=os.getenv("CCTV_VAULT_KEY", ""),
            web_dir=Path(os.getenv("CCTV_WEB_DIR", "web/dist")),
        )
