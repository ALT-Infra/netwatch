import json
import os
import sqlite3
from contextlib import contextmanager
from datetime import UTC, datetime
from urllib.parse import quote, urlsplit, urlunsplit
from uuid import uuid4

from cryptography.fernet import Fernet, InvalidToken

from edge.schemas import CameraInput, CameraView, ProbeResult
from edge.settings import Settings


def now():
    return datetime.now(UTC).isoformat()


class Store:
    def __init__(self, settings: Settings):
        settings.data_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.path = settings.data_dir / "edge.sqlite3"
        self.cipher = Fernet(settings.vault_key.encode())
        fd = os.open(self.path, os.O_WRONLY | os.O_CREAT, 0o600)
        os.close(fd)
        with self.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS cameras (
                    id TEXT PRIMARY KEY, name TEXT NOT NULL, host TEXT NOT NULL,
                    connection BLOB NOT NULL, has_substream INTEGER NOT NULL,
                    has_credentials INTEGER NOT NULL, created_at TEXT NOT NULL,
                    checked_at TEXT, last_probe TEXT
                );
            """)
            marker = db.execute("SELECT value FROM metadata WHERE key='vault_check'").fetchone()
            if marker:
                try:
                    self.cipher.decrypt(marker["value"].encode())
                except InvalidToken:
                    raise ValueError(
                        "Vault key does not match this database; restore its key."
                    ) from None
            else:
                db.execute(
                    "INSERT INTO metadata VALUES ('vault_check', ?)",
                    (self.cipher.encrypt(b"netwatch-edge-v1").decode(),),
                )

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    @staticmethod
    def view(row):
        return CameraView(
            **{
                key: row[key]
                for key in (
                    "id",
                    "name",
                    "host",
                    "has_substream",
                    "has_credentials",
                    "created_at",
                    "checked_at",
                )
            },
            last_probe=json.loads(row["last_probe"]) if row["last_probe"] else None,
        )

    def list(self):
        with self.connect() as db:
            return [
                self.view(row) for row in db.execute("SELECT * FROM cameras ORDER BY created_at")
            ]

    def get(self, camera_id):
        with self.connect() as db:
            row = db.execute("SELECT * FROM cameras WHERE id=?", (camera_id,)).fetchone()
            if row is None:
                raise KeyError(camera_id)
            return self.view(row)

    def create(self, camera: CameraInput):
        camera_id = uuid4().hex
        connection = {
            "main": camera.main_url.get_secret_value(),
            "sub": camera.sub_url.get_secret_value() if camera.sub_url else None,
            "username": camera.username.get_secret_value(),
            "password": camera.password.get_secret_value(),
        }
        with self.connect() as db:
            db.execute(
                """INSERT INTO cameras
                (id,name,host,connection,has_substream,has_credentials,created_at)
                VALUES (?,?,?,?,?,?,?)""",
                (
                    camera_id,
                    camera.name,
                    urlsplit(connection["main"]).hostname,
                    self.cipher.encrypt(json.dumps(connection).encode()),
                    bool(connection["sub"]),
                    bool(connection["username"] or connection["password"]),
                    now(),
                ),
            )
        return self.get(camera_id)

    def stream_url(self, camera_id, stream="main"):
        with self.connect() as db:
            row = db.execute("SELECT connection FROM cameras WHERE id=?", (camera_id,)).fetchone()
        if row is None:
            raise KeyError(camera_id)
        data = json.loads(self.cipher.decrypt(row["connection"]))
        if not data[stream]:
            raise ValueError("This camera has no substream configured.")
        parts = urlsplit(data[stream])
        authority = parts.netloc
        if data["username"] or data["password"]:
            authority = (
                f"{quote(data['username'], safe='')}:{quote(data['password'], safe='')}@{authority}"
            )
        return urlunsplit((parts.scheme, authority, parts.path, parts.query, ""))

    def record_probe(self, camera_id, result: ProbeResult):
        with self.connect() as db:
            db.execute(
                "UPDATE cameras SET checked_at=?, last_probe=? WHERE id=?",
                (
                    now(),
                    result.model_dump_json(),
                    camera_id,
                ),
            )
        return self.get(camera_id)

    def delete(self, camera_id):
        with self.connect() as db:
            if db.execute("DELETE FROM cameras WHERE id=?", (camera_id,)).rowcount == 0:
                raise KeyError(camera_id)
