# Copyright (c) 2021 Tailscale Inc & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

FROM mcr.microsoft.com/vscode/devcontainers/universal:linux@sha256:7ae0fc54e21d8a86bb22530f21ebb443f94c01aabfbc461adc27f81d63df6608 as builder
USER root
WORKDIR /app
COPY . ./
ENV TSFILE=tailscale_1.26.1_amd64.tgz
RUN mkdir -p binaries && \
  wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1 -C binaries
COPY . ./

FROM mcr.microsoft.com/vscode/devcontainers/universal:linux@sha256:7ae0fc54e21d8a86bb22530f21ebb443f94c01aabfbc461adc27f81d63df6608
USER root

RUN apt-get update && apt-get install -y curl gpg dnsutils
COPY tailscaled /etc/init.d/tailscaled
COPY --from=builder /app/binaries/tailscaled /usr/sbin/tailscaled
COPY --from=builder /app/binaries/tailscale /usr/bin/tailscale

RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale