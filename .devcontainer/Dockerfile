# Copyright (c) 2021 Tailscale Inc & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

FROM mcr.microsoft.com/vscode/devcontainers/universal:linux@sha256:60b7324c90e53397f0b7aad646594309ba2dc858dad5d1c87c7e131e9ee65735 as builder
USER root
WORKDIR /app
COPY . ./
ENV TSFILE=tailscale_1.26.1_amd64.tgz
RUN mkdir -p binaries && \
  wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1 -C binaries
COPY . ./

FROM mcr.microsoft.com/vscode/devcontainers/universal:linux@sha256:60b7324c90e53397f0b7aad646594309ba2dc858dad5d1c87c7e131e9ee65735
USER root

RUN apt-get update && apt-get install -y curl gpg dnsutils
COPY tailscaled /etc/init.d/tailscaled
COPY --from=builder /app/binaries/tailscaled /usr/sbin/tailscaled
COPY --from=builder /app/binaries/tailscale /usr/bin/tailscale

RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale