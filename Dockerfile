# Python/media libraries and model assets match the exact patched source revision.
FROM docker.io/library/node@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5 AS web
RUN corepack enable && corepack prepare pnpm@11.3.0 --activate
WORKDIR /work
COPY vendor/frigate/web/package.json vendor/frigate/web/pnpm-lock.yaml vendor/frigate/web/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY vendor/frigate/web/ ./
RUN pnpm run build && mv dist/BASE_PATH/monacoeditorwork/* dist/assets/ && rm -rf dist/BASE_PATH

FROM ghcr.io/blakeblackshear/frigate@sha256:d4351369984d4a9e2a49ac59736f6490856a7ea11f7790040746d21496967010
LABEL org.opencontainers.image.title="Netwatch" \
      org.opencontainers.image.description="Controlled Frigate 0.17.2 foundation" \
      org.opencontainers.image.base.name="ghcr.io/blakeblackshear/frigate:0.17.2" \
      video.netwatch.upstream-revision="3d4dd3ac4b00e7257bd3412608a783001d7d77ed"
COPY vendor/frigate/frigate/ /opt/frigate/frigate/
COPY vendor/frigate/docker/main/rootfs/usr/local/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf
COPY vendor/frigate/docker/main/rootfs/usr/local/go2rtc/create_config.py /usr/local/go2rtc/create_config.py
COPY --from=web /work/dist/ /opt/frigate/web/
# Frigate, go2rtc, FFmpeg, migrations, models, notices and s6 remain in the matching base.
