FROM node:22-bookworm-slim AS web
WORKDIR /build
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

FROM ghcr.io/astral-sh/uv:0.12.3 AS uv
FROM python:3.12-slim-bookworm AS runtime
COPY --from=uv /uv /usr/local/bin/uv
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 edge && useradd --uid 10001 --gid edge --no-create-home edge
WORKDIR /app
COPY pyproject.toml uv.lock ./
COPY edge/ ./edge/
RUN uv sync --frozen --no-dev --no-cache \
    && mkdir /app/data && chown edge:edge /app/data && chmod 700 /app/data
COPY --from=web /build/dist ./web/dist/
ENV CCTV_DATA_DIR=/app/data CCTV_WEB_DIR=/app/web/dist PYTHONDONTWRITEBYTECODE=1
USER edge
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s CMD ["/app/.venv/bin/python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health', timeout=3)"]
CMD ["/app/.venv/bin/uvicorn", "edge.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
