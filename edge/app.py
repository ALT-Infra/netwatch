import hmac
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles

from edge.probe import ProbeBusy, ProbeUnavailable, StreamProbe
from edge.schemas import CameraInput, CameraView, ProbeInput
from edge.settings import Settings
from edge.store import Store


def create_app(settings: Settings | None = None, probe=None):
    settings = settings or Settings.from_env()
    stream_probe = probe or StreamProbe()

    @asynccontextmanager
    async def lifespan(app):
        app.state.store = Store(settings)
        yield

    app = FastAPI(
        title="Netwatch Edge",
        version="0.1.0",
        lifespan=lifespan,
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )
    bearer = HTTPBearer(auto_error=False)

    def authorized(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
        if credentials is None or not hmac.compare_digest(
            credentials.credentials.encode(), settings.api_token.encode()
        ):
            raise HTTPException(
                401, "Unlock with the local access key.", headers={"WWW-Authenticate": "Bearer"}
            )

    protected = [Depends(authorized)]

    @app.middleware("http")
    async def security_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; style-src 'self'; img-src 'self' data:; "
            "frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
        )
        return response

    @app.exception_handler(RequestValidationError)
    async def invalid_request(request, exc):
        # Pydantic's default errors can echo input, including credentials or stream URLs.
        return JSONResponse(
            status_code=422,
            content={
                "detail": "Invalid camera details. Check the name and RTSP addresses; "
                "enter username and password separately."
            },
        )

    @app.exception_handler(KeyError)
    async def missing_camera(request, exc):
        return JSONResponse(status_code=404, content={"detail": "Camera not found."})

    @app.get("/api/health")
    def health():
        return {"status": "ok", "version": "0.1.0"}

    @app.get("/api/session", dependencies=protected)
    def session():
        return {"authenticated": True}

    @app.get("/api/cameras", response_model=list[CameraView], dependencies=protected)
    def cameras(request: Request):
        return request.app.state.store.list()

    @app.post("/api/cameras", response_model=CameraView, status_code=201, dependencies=protected)
    def add_camera(camera: CameraInput, request: Request):
        return request.app.state.store.create(camera)

    @app.delete("/api/cameras/{camera_id}", status_code=204, dependencies=protected)
    def delete_camera(camera_id: str, request: Request):
        request.app.state.store.delete(camera_id)
        return Response(status_code=204)

    @app.post("/api/cameras/{camera_id}/probe", response_model=CameraView, dependencies=protected)
    def check_camera(camera_id: str, body: ProbeInput, request: Request):
        store = request.app.state.store
        try:
            url = store.stream_url(camera_id, body.stream)
        except ValueError:
            raise HTTPException(400, "This camera has no substream configured.") from None
        try:
            result = stream_probe(url)
        except ProbeBusy:
            raise HTTPException(429, "Two stream checks are already running. Try again shortly.")
        except ProbeUnavailable:
            raise HTTPException(503, "Install FFmpeg on the edge computer to enable stream checks.")
        result = result.model_copy(update={"stream": body.stream})
        return store.record_probe(camera_id, result)

    if settings.web_dir.is_dir():
        app.mount("/", StaticFiles(directory=settings.web_dir, html=True), name="web")
    return app
