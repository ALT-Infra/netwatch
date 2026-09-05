import re
from typing import Literal
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator


class CameraInput(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    name: str = Field(min_length=1, max_length=80)
    main_url: SecretStr
    sub_url: SecretStr | None = None
    username: SecretStr = SecretStr("")
    password: SecretStr = SecretStr("")

    @field_validator("main_url", "sub_url")
    @classmethod
    def validate_stream(cls, value):
        if value is None:
            return value
        raw = value.get_secret_value()
        try:
            parts = urlsplit(raw)
            port = parts.port
            valid = (
                0 < len(raw) <= 2048
                and not re.search(r"[\s\x00-\x1f\x7f]", raw)
                and parts.scheme == "rtsp"
                and parts.hostname
                and parts.username is None
                and parts.password is None
                and not parts.fragment
                and (port is None or port > 0)
            )
        except ValueError:
            valid = False
        if not valid:
            raise ValueError("Use an rtsp://host/path URL; enter credentials in separate fields.")
        return value

    @field_validator("username", "password")
    @classmethod
    def limit_credential(cls, value):
        if len(value.get_secret_value()) > 512:
            raise ValueError("Credential is too long.")
        return value


class ProbeResult(BaseModel):
    stream: Literal["main", "sub"] = "main"
    status: Literal["reachable", "unreachable"]
    message: str
    codec: str | None = None
    width: int | None = None
    height: int | None = None


class CameraView(BaseModel):
    id: str
    name: str
    host: str
    has_substream: bool
    has_credentials: bool
    created_at: str
    checked_at: str | None
    last_probe: ProbeResult | None


class ProbeInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    stream: Literal["main", "sub"] = "main"
