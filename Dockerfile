FROM node:20-alpine AS BUILD_IMAGE

WORKDIR /app

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

# 支持传入代理环境变量
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV NO_PROXY=${NO_PROXY}

RUN \
  case "${TARGETPLATFORM}" in \
  'linux/arm64' | 'linux/arm/v7') \
  apk update && \
  apk add --no-cache python3 make g++ gcc libc6-compat bash && \
  npm install --global node-gyp \
  ;; \
  esac

RUN npm install --global pnpm

COPY package.json pnpm-lock.yaml postinstall-win.js ./

# 使用传入的代理环境变量
RUN CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile --proxy=${HTTP_PROXY} --https-proxy=${HTTPS_PROXY}

COPY . ./

ARG COMMIT_TAG
ENV COMMIT_TAG=${COMMIT_TAG}

RUN pnpm build

# remove development dependencies
RUN pnpm prune --prod --ignore-scripts

RUN rm -rf src server .next/cache

RUN touch config/DOCKER

RUN echo "{\"commitTag\": \"${COMMIT_TAG}\"}" > committag.json


FROM node:20-alpine

# Metadata for Github Package Registry
LABEL org.opencontainers.image.source="https://github.com/Fallenbagel/jellyseerr"

WORKDIR /app

# 安装 tzdata 和 tini
RUN apk add --no-cache tzdata tini && rm -rf /tmp/*

RUN npm install -g pnpm

# copy from build image
COPY --from=BUILD_IMAGE /app ./

# 支持传入代理环境变量
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV NO_PROXY=${NO_PROXY}

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD [ "pnpm", "start" ]

EXPOSE 5055

